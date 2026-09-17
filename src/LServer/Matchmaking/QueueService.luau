local Shared = game:GetService("ReplicatedStorage"):WaitForChild("LShared", 30)
local Definitions = require(Shared:WaitForChild("Matchmaking", 30):WaitForChild("QueueDefinitions", 30))
-- Physical queue lifecycle; world geometry and networking are injected by QueueWorld.
local Queues = {}
Queues.__index = Queues

function Queues.new(deps)
	return setmetatable({
		d = deps,
		bays = {},
		players = {},
		entries = {},
		busy = {},
		revision = 0,
		serial = 0,
		closing = false,
	}, Queues)
end

function Queues:Register(id)
	assert(not self.bays[id], "Duplicate queue ID")
	local bay = { Id = id, Slots = {} }
	self.bays[id] = bay
	return bay
end

function Queues:Get(player)
	local bay = self.players[player]
	if not bay then
		return { Active = false, Revision = self.revision }
	end
	local party = self.d.party:Get(player)
	if bay.PartyId and (not party or party.Id ~= bay.PartyId) then
		return { Active = false, Revision = self.revision }
	end
	local state = party and party.State or "Configuring"
	return {
		Active = true,
		QueueId = bay.Id,
		EntryId = self.entries[player],
		Revision = self.revision,
		State = state,
		Configuring = not bay.PartyId and bay.Host == player,
		CanLeave = state ~= "Preparing" and state ~= "Teleporting",
		Mode = party and party.Mode or "Story",
		Capacity = party and party.Capacity or self.d.config.MaxPartySize,
		MaxCapacity = self.d.config.MaxPartySize,
		Count = party and #party.Members or 1,
		HostUserId = party and party.HostUserId or bay.Host.UserId,
		ExpiresAt = party and bay.DepartureAt or bay.SetupUntil,
	}
end

function Queues:_emit(player, message)
	self.revision += 1
	local snapshot = self:Get(player)
	snapshot.Message = message
	self.d.push(player, snapshot)
end

function Queues:Publish(bay, message)
	for player, current in pairs(self.players) do
		if current == bay then
			self:_emit(player, message)
		end
	end
end

function Queues:PartyChanged(player)
	local bay = self.players[player]
	if bay and not bay.Mutating then
		self:_emit(player)
	end
end

-- An old request must never create or leave a newer visit, even on the same pad.
function Queues:MatchesEntry(player, entryId)
	return type(entryId) == "string" and self.entries[player] == entryId
end

function Queues:Request(player, action, payload)
	if not self:MatchesEntry(player, payload.EntryId) then
		return { Ok = false, Code = "QueueChanged", Queue = self:Get(player) }
	end
	local ok, reason
	if action == "QueueCreate" then
		ok, reason = self:Create(player, payload.Capacity, payload.Mode)
	elseif action == "QueueLeave" then
		ok, reason = self:Leave(player, false)
	else
		return { Ok = false, Code = "UnknownAction" }
	end
	return { Ok = ok, Code = reason, Queue = self:Get(player) }
end

function Queues:_occupy(player, bay, slot)
	self.serial += 1
	self.entries[player] = tostring(self.serial)
	self.players[player] = bay
	bay.Slots[player] = slot
end

function Queues:Feedback(player, message)
	self:_emit(player, message)
end

function Queues:Enter(player, id)
	local bay = self.bays[id]
	if self.closing or not bay or self.players[player] or self.busy[player] then
		return false, "AlreadyQueued"
	end
	if not self.d.ready(player) or not self.d.present(player) then
		return false, "DataNotReady"
	end
	if not self.d.alive(player) or not self.d.inside(player, id) then
		return false, "CharacterNotReady"
	end
	if self.d.party:Get(player) then
		return false, "AlreadyInParty"
	end
	if not bay.Host and not bay.PartyId then
		if not self.d.move(player, id, true, 1) then
			return false, "CharacterNotReady"
		end
		bay.Host = player
		bay.SetupUntil = self.d.clock() + self.d.config.QueueSetupSeconds
		self:_occupy(player, bay, 1)
		self:_emit(player)
		self.d.log("SETUP OPEN", player, id)
		return true
	end
	if not bay.PartyId then
		return false, "HostChoosing"
	end
	local existing = self.d.party.parties[bay.PartyId]
	if not existing or existing.State ~= "Open" then
		return false, "PartyDeparting"
	end
	if #existing.Members >= existing.Capacity then
		return false, "QueueFull"
	end
	self.busy[player] = true
	local ok, reason = self.d.party:Join(player, bay.PartyId)
	self.busy[player] = nil
	if not ok then
		return false, reason
	end
	-- Friendship lookup may yield: do not pull someone back who walked away or entered another pad.
	if
		self.closing
		or self.bays[id] ~= bay
		or self.players[player]
		or not self.d.present(player)
		or not self.d.inside(player, id)
	then
		self.d.party:Remove(player, true)
		return false, "QueueChanged"
	end
	local occupied = {}
	for _, slot in pairs(bay.Slots) do
		occupied[slot] = true
	end
	local slot = 1
	while occupied[slot] do
		slot += 1
	end
	local party = self.d.party:Get(player)
	if not party or not self.d.move(player, id, true, slot) then
		self.d.party:Remove(player, true)
		return false, "CharacterNotReady"
	end
	self:_occupy(player, bay, slot)
	self.d.party:Ready(player, true) -- Entering a physical queue is the player's ready action.
	self:Publish(bay)
	self.d.log("JOINED", player, id)
	return true
end

function Queues:Create(player, capacity, mode)
	if not Definitions.IsMode(mode) then
		return false, "InvalidMode"
	end
	local bay = self.players[player]
	if self.closing or not bay or bay.Host ~= player or bay.PartyId then
		return false, "NoQueueReservation"
	end
	if self.d.clock() >= bay.SetupUntil then
		self:Leave(player, true)
		return false, "SetupExpired"
	end
	bay.Mutating = true -- These operations do not yield; publish only their completed physical state.
	local ok, reason = self.d.party:Create(player, capacity, self.d.config.WorldQueueAccess, mode)
	bay.Mutating = nil
	if not ok then
		return false, reason
	end
	bay.PartyId = self.d.party:Get(player).Id
	bay.SetupUntil = nil
	bay.DepartureAt = self.d.clock() + self.d.config.QueueGatherSeconds
	self:Publish(bay)
	self.d.log("CREATED " .. mode, player, bay.Id)
	return true
end

function Queues:Leave(player, forced, moveOut, message)
	local bay = self.players[player]
	if not bay then
		return self.d.party:Remove(player, forced)
	end
	local state = self:Get(player)
	if not forced and not state.CanLeave then
		return false, "TransferInProgress"
	end
	bay.Mutating = true
	local ok, reason = self.d.party:Remove(player, forced)
	bay.Mutating = nil
	if not ok then
		return false, reason
	end
	local slot = bay.Slots[player] or 1
	bay.Slots[player] = nil
	self.players[player], self.entries[player] = nil, nil
	self.d.exited(player, bay.Id) -- Require stepping clear of entry boxes before they can fire again.
	if moveOut ~= false and self.d.present(player) then
		self.d.move(player, bay.Id, false, slot)
	end
	self:_emit(player, message)
	if not bay.PartyId or not self.d.party.parties[bay.PartyId] then
		bay.Host, bay.PartyId, bay.SetupUntil, bay.DepartureAt = nil, nil, nil, nil
	else
		self:Publish(bay)
	end
	self.d.log("LEFT", player, bay.Id)
	return true
end

function Queues:Clear(bay, message)
	local roster = {}
	for player, current in pairs(self.players) do
		if current == bay then
			table.insert(roster, player)
		end
	end
	for _, player in ipairs(roster) do
		self:Leave(player, true, true, message)
	end
	bay.Host, bay.PartyId, bay.SetupUntil, bay.DepartureAt = nil, nil, nil, nil
end

function Queues:Unregister(id)
	local bay = self.bays[id]
	if not bay then
		return
	end
	self:Clear(bay, "QueueRemoved")
	self.bays[id] = nil
end

function Queues:Board(id)
	local bay = self.bays[id]
	local party = bay and bay.PartyId and self.d.party.parties[bay.PartyId]
	if party then
		return {
			State = party.State,
			Mode = party.Mode,
			Host = party.Host.DisplayName,
			Count = #party.Members,
			Capacity = party.Capacity,
			ExpiresAt = bay.DepartureAt,
		}
	end
	return {
		State = bay and bay.Host and "Configuring" or "Empty",
		Host = bay and bay.Host and bay.Host.DisplayName or "-",
		Mode = "Choose a mode",
		Count = bay and bay.Host and 1 or 0,
		Capacity = self.d.config.MaxPartySize,
		ExpiresAt = bay and bay.SetupUntil,
	}
end

function Queues:Tick()
	if self.closing then
		return
	end
	local departures = {}
	for player, bay in pairs(self.players) do
		local state = self:Get(player)
		local walkedAway = state.CanLeave and self.d.far(player, bay.Id)
		if not self.d.present(player) or not self.d.alive(player) or not state.Active or walkedAway then
			table.insert(departures, { Player = player, MoveOut = not walkedAway })
		end
	end
	for _, departure in ipairs(departures) do
		self:Leave(departure.Player, true, departure.MoveOut, "QueueLeft")
	end
	for _, bay in pairs(self.bays) do
		if bay.Host and not bay.PartyId and self.d.clock() >= bay.SetupUntil then
			self:Clear(bay, "SetupExpired")
		elseif bay.PartyId then
			local party = self.d.party.parties[bay.PartyId]
			if not party then
				self:Clear(bay)
			elseif party.State == "Open" and party.LastError then
				self:Clear(bay, party.LastError)
			elseif party.State == "Open" then
				local now = self.d.clock()
				if #party.Members >= party.Capacity then
					bay.DepartureAt = math.min(bay.DepartureAt, now + self.d.config.CountdownSeconds)
				end
				if now < bay.DepartureAt - self.d.config.CountdownSeconds then
					continue
				end
				local ok, reason = self.d.party:Start(party.Host, math.max(0, bay.DepartureAt - now))
				if not ok then
					self:Clear(bay, reason)
				else
					self:Publish(bay)
				end
			end
		end
	end
end

return Queues
