local Shift = require(script.Parent.ShiftService)
local World = require(script.Parent.PrototypeWorld)
local Config = require(script.Parent.PrototypeConfig)
local Prototype = {}
Prototype.__index = Prototype

function Prototype.new(services, data, session, network)
	local self = setmetatable({
		s = services,
		data = data,
		session = session,
		net = network,
		saving = {},
		nextPush = 0,
		closing = false,
	}, Prototype)
	self.world = World.new(services, Config)
	local random = Random.new()
	self.run = Shift.new({
		random = function(low, high)
			return random:NextInteger(low, high)
		end,
		debug = function(message)
			if Config.DebugScares and (services.RunService:IsStudio() or Config.DebugScaresInLive) then
				print("[DPU][Scare] " .. message)
			end
		end,
		clock = function()
			return workspace:GetServerTimeNow()
		end,
		id = function()
			return services.HttpService:GenerateGUID(false)
		end,
		present = function(player)
			return player.Parent == services.Players
		end,
		ready = function(player)
			return data:IsReady(player)
		end,
		near = function(player, station)
			return self.world:Near(player, station)
		end,
		seated = function(player)
			return self.world.workshop:IsSeated(player)
		end,
		sit = function(player)
			return self.world.workshop:Sit(player)
		end,
		stand = function(player)
			self.world.workshop:Stand(player)
		end,
		givePart = function(player, record)
			return self.world.workshop:GivePart(player, record)
		end,
		hasPart = function(player, record)
			return self.world.workshop:HasPart(player, record)
		end,
		clearPart = function(player)
			self.world.workshop:ClearPart(player)
		end,
		giveGear = function(player, id)
			return self.world.workshop:GiveGear(player, id)
		end,
		hasGear = function(player, id)
			return self.world.workshop:HasGear(player, id)
		end,
		clearGear = function(player)
			self.world.workshop:ClearGear(player)
		end,
		sessionReady = function()
			return session:IsReady()
		end,
		sessionState = function()
			return session.state
		end,
		mode = function()
			return session.mode or "Story"
		end,
		reset = function(player)
			self.world:Reset(player, true)
		end,
		health = function(player, hp)
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.Health = hp
			end
		end,
		outcome = function(player, result)
			return data:RecordOutcome(player, result)
		end,
		tutorial = function(player)
			return data:CompleteTutorial(player)
		end,
		evidence = function(player, id)
			return data:UnlockEvidence(player, id)
		end,
		persist = function(player)
			self:Persist(player)
		end,
		saveStatus = function(player)
			return self.saving[player] and self.saving[player].Status or "Progress recorded"
		end,
	}, Config)
	self.world.interact = function(player, station)
		local action = station == "Answer" and "Answer" or self.world.actions and self.world.actions[station]
		local member = self.run.players[player]
		if station == "Bench" and member then
			action = member.CarriedPart and "DepositPart"
				or not self.world.workshop:IsSeated(player) and "Sit"
				or action
		end
		if action then
			local order, event = self.run.order, self.run.event
			local ok, code = self.run:Action(player, action, {
				OrderId = order and order.Id,
				EventId = event and event.Id,
				Part = string.match(station, "^Part_(.+)$"),
				Contact = order and (order.Contacts or 0) + 1,
				Tool = string.match(station, "^Tool_(.+)$"),
				Secret = string.match(station, "^Secret_(.+)$"),
			})
			self:Push(player, not ok and code or nil)
		end
	end
	return self
end

function Prototype:Persist(player)
	local item = self.saving[player]
	if item and item.Busy then
		return
	end
	item = { Busy = true, Status = "Saving progress..." }
	self.saving[player] = item
	task.spawn(function()
		local ok, saved = pcall(function()
			return self.data:Save(player, false)
		end)
		if self.saving[player] ~= item then
			return
		end
		item.Busy = false
		item.Status = ok
				and saved
				and (self.data.practice and "Practice progress saved for this session" or "Progress saved")
			or "Save delayed; retrying"
		item.Retry = not (ok and saved) and os.clock() + 8 or nil
		self.run:_publish()
	end)
end

function Prototype:Add(player)
	self.run:Add(player)
	self.world:Attach(player, function(p)
		return self.run.players[p] and self.run.players[p].Alive
	end, function(p)
		self.run:Damage(p, 100, "Died during the shift")
	end)
	self:Push(player)
end

function Prototype:Push(player, code)
	local snapshot = self.run:Snapshot(player)
	snapshot.Kind, snapshot.Error = "Prototype", code
	self.net:Push(player, snapshot)
end

function Prototype:Request(player, action, payload)
	if action == "GetPrototype" then
		if not self.run.players[player] then
			return {
				Ok = true,
				State = {
					Revision = -1,
					Phase = "Waiting",
					Objective = "Checking admission and loading your saved data...",
				},
			}
		end
		return { Ok = true, State = self.run:Snapshot(player) }
	end
	if not self.run.players[player] or payload.RunId ~= self.run.id then
		return { Ok = false, Code = "ShiftChanged" }
	end
	local ok, code = self.run:Action(player, payload.Action, payload)
	return { Ok = ok, Code = code, State = self.run:Snapshot(player) }
end

function Prototype:Remove(player)
	self.run:Remove(player)
	self.world:Remove(player)
	self.saving[player] = nil
end

function Prototype:Tick()
	if self.closing then
		return
	end
	self.run:Tick()
	self.world:Render(self.run)
	for player, item in pairs(self.saving) do
		if item.Retry and os.clock() >= item.Retry and self.data:IsReady(player) then
			self:Persist(player)
		end
	end
	if self.lastRevision ~= self.run.revision or os.clock() >= self.nextPush then
		self.nextPush = os.clock() + 5
		self.lastRevision = self.run.revision
		for player in pairs(self.run.players) do
			self:Push(player)
		end
	end
end

function Prototype:Shutdown()
	self.closing, self.run.closing = true, true
	self.world:Shutdown()
end

return Prototype
