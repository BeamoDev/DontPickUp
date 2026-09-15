local Schema = require(script.Parent.ProfileSchema)
local SessionStore = require(script.Parent.SessionStore)
local View = require(script.Parent.PlayerView)
local DataService = {}
DataService.__index = DataService

function DataService.new(services, config)
	local practice = services.RunService:IsStudio() and not config.StudioSaving
	local store = if practice
		then nil
		else services.DataStoreService:GetDataStore(
			config.DataStoreName .. (services.RunService:IsStudio() and "_STUDIO" or "")
		)
	local self = setmetatable(
		{
			s = services,
			config = config,
			entries = {},
			loading = {},
			closing = false,
			practice = practice,
			memory = {},
			activeLoads = 0,
		},
		DataService
	)
	self.store = SessionStore.new({
		config = config,
		schema = Schema,
		clock = os.clock,
		now = os.time,
		wait = task.wait,
		update = function(userId, transform)
			if practice then
				local key = tostring(userId)
				local result = transform(Schema.Copy(self.memory[key]))
				if result then
					self.memory[key] = Schema.Copy(result)
				end
				return result
			end
			return store:UpdateAsync("player_" .. userId, function(old, info)
				local result = transform(old)
				if result == nil then
					return nil
				end
				return result, userId > 0 and { userId } or {}, info and info:GetMetadata() or {}
			end)
		end,
	})
	return self
end

function DataService:Load(player)
	if self.closing or self.loading[player] or self.entries[player] then
		return false
	end
	local token = self.s.HttpService:GenerateGUID(false)
	self.loading[player] = token
	self.activeLoads += 1
	View.Status(player, "Loading", not self.practice)
	local session, reason = self.store:Acquire(player.UserId, token, function()
		return self.closing or player.Parent ~= self.s.Players or self.loading[player] ~= token
	end)
	self.loading[player] = nil
	self.activeLoads -= 1
	if not session then
		View.Status(player, "LoadFailed", not self.practice)
		if player.Parent == self.s.Players then
			player:Kick("Your data could not be loaded safely. Please rejoin. (" .. reason .. ")")
		end
		return false
	end
	if self.closing or player.Parent ~= self.s.Players then
		self.store:Abandon(player.UserId, token)
		return false
	end
	self.entries[player] = {
		session = session,
		data = session.Data,
		busy = false,
		frozen = false,
		closing = false,
		playClock = os.clock(),
		nextSave = os.clock() + self.config.SaveIntervalSeconds + math.random() * 10,
	}
	View.Publish(player, session.Data)
	View.Status(player, "Ready", not self.practice)
	return true
end

function DataService:IsReady(player)
	local entry = self.entries[player]
	return entry ~= nil
		and not self.closing
		and not entry.closing
		and not entry.frozen
		and not entry.lost
		and entry.session.Expires - os.time() > self.config.MutationLeaseMargin
end

function DataService:Get(player)
	local entry = self.entries[player]
	return entry and Schema.Copy(entry.data) or nil
end

function DataService:_playtime(entry)
	local elapsed = math.floor(os.clock() - entry.playClock)
	entry.playClock += elapsed
	entry.data.Stats.PlaytimeSeconds = math.min(2000000000, entry.data.Stats.PlaytimeSeconds + elapsed)
end

function DataService:Save(player, release, deadline)
	local entry = self.entries[player]
	if not entry then
		return false, "NotLoaded"
	end
	deadline = deadline or os.clock() + 20
	while entry.busy and os.clock() < deadline do
		task.wait(0.1)
	end
	if entry.busy or self.entries[player] ~= entry or (entry.closing and not release) then
		return false, "Busy"
	end
	entry.busy = true
	self:_playtime(entry)
	local ok, reason = self.store:Write(
		player.UserId,
		entry.session,
		entry.data,
		release,
		self.s.HttpService:GenerateGUID(false),
		deadline
	)
	entry.busy = false
	entry.nextSave = os.clock() + (ok and (self.config.SaveIntervalSeconds + math.random() * 10) or 8)
	if reason == "OwnershipLost" then
		entry.lost = true
		entry.frozen = true
		View.Status(player, "SessionLost", not self.practice)
		if player.Parent == self.s.Players then
			player:Kick("Your data session changed. Please rejoin to keep your progress safe.")
		end
	elseif not release and not entry.closing then
		View.Publish(player, entry.data)
		View.Status(
			player,
			entry.frozen and "Transferring" or (self:IsReady(player) and "Ready" or "SaveDelayed"),
			not self.practice
		)
	end
	return ok, reason
end

function DataService:Freeze(player)
	if not self:IsReady(player) then
		return false
	end
	local entry = self.entries[player]
	entry.frozen = true
	View.Status(player, "Transferring", not self.practice)
	local ok = self:Save(player, false)
	if not ok or entry.closing or player.Parent ~= self.s.Players then
		self:Thaw(player)
		return false
	end
	return true
end

function DataService:Thaw(player)
	local entry = self.entries[player]
	if not entry or entry.closing or entry.lost then
		return
	end
	entry.frozen = false
	View.Status(player, self:IsReady(player) and "Ready" or "SaveDelayed", not self.practice)
end

function DataService:SetSetting(player, key, value)
	if not self:IsReady(player) then
		return false, "DataNotReady"
	end
	local entry = self.entries[player]
	local original = entry.data.Settings[key]
	if original == nil or type(value) ~= type(original) then
		return false, "InvalidSetting"
	end
	if type(value) == "number" and (value ~= value or value < 0 or value > 1) then
		return false, "InvalidSetting"
	end
	entry.data.Settings[key] = value
	View.Publish(player, entry.data)
	return true
end

-- Called only by future authoritative Game systems. No reward/progression remote exists.
function DataService:RecordOutcome(player, outcome)
	if not self:IsReady(player) then
		return false, "DataNotReady"
	end
	if
		type(outcome) ~= "table"
		or not Schema.Identifier(outcome.Id)
		or type(outcome.Survived) ~= "boolean"
		or type(outcome.Shift) ~= "number"
		or outcome.Shift % 1 ~= 0
		or outcome.Shift < 1
		or outcome.Shift >= 10000
		or type(outcome.CasesSolved) ~= "number"
		or outcome.CasesSolved % 1 ~= 0
		or outcome.CasesSolved < 0
		or outcome.CasesSolved > 1000
	then
		return false, "InvalidOutcome"
	end
	local data = Schema.Copy(self.entries[player].data)
	if table.find(data.RecentOutcomes, outcome.Id) then
		return true, "AlreadyApplied"
	end
	data.Stats.CasesSolved += outcome.CasesSolved
	if outcome.Survived then
		data.Stats.ShiftsSurvived += 1
		data.Progress.HighestShift = math.max(data.Progress.HighestShift, outcome.Shift + 1)
	else
		data.Stats.Deaths += 1
	end
	if outcome.Ending ~= nil then
		if not Schema.Identifier(outcome.Ending) then
			return false, "InvalidEnding"
		end
		data.Progress.Endings[outcome.Ending] = true
	end
	table.insert(data.RecentOutcomes, outcome.Id)
	if #data.RecentOutcomes > 100 then
		table.remove(data.RecentOutcomes, 1)
	end
	if not Schema.Validate(data) then
		return false, "InvalidOutcome"
	end
	self.entries[player].data = data
	View.Publish(player, data)
	return true
end

function DataService:UnlockEvidence(player, id)
	if not self:IsReady(player) or not Schema.Identifier(id) then
		return false
	end
	local data = Schema.Copy(self.entries[player].data)
	data.Progress.Evidence[id] = true
	if not Schema.Validate(data) then
		return false
	end
	self.entries[player].data = data
	View.Publish(player, data)
	return true
end

function DataService:CompleteTutorial(player)
	if not self:IsReady(player) then
		return false
	end
	self.entries[player].data.Progress.TutorialComplete = true
	View.Publish(player, self.entries[player].data)
	return true
end

function DataService:Remove(player, deadline)
	self.loading[player] = nil
	local entry = self.entries[player]
	if not entry or entry.closing then
		return
	end
	entry.closing = true
	entry.frozen = true
	View.Status(player, "Saving", not self.practice)
	local ok, reason = self:Save(player, true, deadline or os.clock() + 25)
	if not ok then
		warn("[DPU] Final save unconfirmed for", player.UserId, reason)
	end
	if self.entries[player] == entry then
		self.entries[player] = nil
	end
end

function DataService:Tick()
	for player, entry in pairs(self.entries) do
		if not entry.closing then
			if entry.session.Expires <= os.time() then
				entry.lost = true
				entry.frozen = true
				View.Status(player, "SessionLost", not self.practice)
				player:Kick("Saving is unavailable. Please rejoin to reload your last saved progress.")
			elseif not entry.busy and os.clock() >= entry.nextSave then
				entry.nextSave = os.clock() + 10
				task.spawn(function()
					self:Save(player, false)
				end)
			end
		end
	end
end

function DataService:Shutdown()
	self.closing = true
	local deadline = os.clock() + 25
	for player in pairs(self.entries) do
		task.spawn(function()
			self:Remove(player, deadline)
		end)
	end
	while (next(self.entries) or self.activeLoads > 0) and os.clock() < deadline do
		task.wait(0.1)
	end
end

return DataService
