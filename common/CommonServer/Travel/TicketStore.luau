-- Maintained in common/CommonServer/Travel/TicketStore.luau. Deploy with tools/SyncCommon.ps1.
local Rules = require(script.Parent.AdmissionRules)
local TicketStore = {}
TicketStore.__index = TicketStore

function TicketStore.new(services, config)
	return setmetatable({
		s = services,
		config = config,
		map = services.MemoryStoreService:GetHashMap(
			config.TicketMapName .. (services.RunService:IsStudio() and "_STUDIO" or "")
		),
	}, TicketStore)
end

function TicketStore:Create(id, privateServerId, players, mode)
	mode = mode or "Story"
	if mode ~= "Story" and mode ~= "Endless" then
		return nil
	end
	if #players < 1 or #players > self.config.MaxPartySize then
		return nil
	end
	local unique = {}
	for _, player in ipairs(players) do
		if unique[player.UserId] then
			return nil
		end
		unique[player.UserId] = true
	end
	local ticket = {
		Version = 1,
		Expires = os.time() + self.config.TicketSeconds,
		LobbyPlaceId = game.PlaceId,
		GamePlaceId = self.config.GamePlaceId,
		PrivateServerId = privateServerId,
		Members = {},
		Mode = mode,
		GameData = { Version = 1, Mode = mode, StartNight = 1, PartySize = #players },
	}
	for _, player in ipairs(players) do
		ticket.Members[tostring(player.UserId)] = {}
	end
	for attempt = 1, 3 do
		local ok, result = pcall(function()
			return self.map:UpdateAsync(id, function(old)
				return old or ticket
			end, self.config.TicketSeconds)
		end)
		if ok and result and result.PrivateServerId == privateServerId then
			return result
		end
		task.wait(attempt)
	end
	return nil
end

function TicketStore:Claim(player)
	local ok, join = pcall(function()
		return player:GetJoinData()
	end)
	if not ok or type(join) ~= "table" or type(join.TeleportData) ~= "table" then
		return nil, "MissingAdmission"
	end
	local id = join.TeleportData.TicketId
	if type(id) ~= "string" or #id ~= 36 or not id:match("^[%x%-]+$") then
		return nil, "MissingAdmission"
	end
	local reason = "AdmissionUnavailable"
	for attempt = 1, 3 do
		local claimed, ticket = pcall(function()
			return self.map:UpdateAsync(id, function(old)
				local allowed, why = Rules.CanClaim(old, {
					Now = os.time(),
					UserId = player.UserId,
					SourcePlaceId = join.SourcePlaceId,
					SourceGameId = join.SourceGameId,
					GameId = game.GameId,
					PlaceId = game.PlaceId,
					PrivateServerId = game.PrivateServerId,
					PrivateServerOwnerId = game.PrivateServerOwnerId,
					JobId = game.JobId,
				})
				if not allowed then
					reason = why
					return nil
				end
				old.JobId = game.JobId
				old.Members[tostring(player.UserId)].ClaimedJob = game.JobId
				return old
			end, self.config.TicketSeconds)
		end)
		if claimed and ticket and ticket.JobId == game.JobId then
			return { Id = id, Ticket = ticket }
		end
		if claimed then
			return nil, reason
		end
		task.wait(attempt)
	end
	return nil, reason
end

function TicketStore:Revoke(id, userId, expires)
	if os.time() >= expires then
		return true
	end
	local alreadyClaimed = false
	local ok, result = pcall(function()
		return self.map:UpdateAsync(id, function(old)
			if not old or old.Expires <= os.time() then
				return nil
			end
			local member = old.Members[tostring(userId)]
			if not member then
				return old
			end
			if member.ClaimedJob then
				alreadyClaimed = true
				return nil
			end
			member.Revoked = true
			return old
		end, self.config.TicketSeconds)
	end)
	if alreadyClaimed then
		return false, "AlreadyClaimed"
	end
	if not ok then
		return false, "Unavailable"
	end
	-- nil means the ticket is absent/expired. No new arrival can claim it.
	return result == nil or result.Members[tostring(userId)] == nil or result.Members[tostring(userId)].Revoked == true
end

function TicketStore:Read(id)
	local ok, ticket = pcall(function()
		return self.map:GetAsync(id)
	end)
	return ok, ticket
end

return TicketStore
