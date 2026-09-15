local Party = {}
Party.__index = Party

function Party.new(deps)
	return setmetatable({ d = deps, parties = {}, membership = {}, serial = 0, closing = false }, Party)
end

function Party:Snapshot(party)
	if not party then
		return nil
	end
	local members = {}
	for _, member in ipairs(party.Members) do
		table.insert(
			members,
			{
				UserId = member.Player.UserId,
				Name = member.Player.Name,
				DisplayName = member.Player.DisplayName,
				Ready = member.Ready,
			}
		)
	end
	return {
		Id = party.Id,
		HostUserId = party.Host.UserId,
		Access = party.Access,
		Capacity = party.Capacity,
		State = party.State,
		Members = members,
		CountdownEndsAt = party.CountdownEndsAt,
		Revision = party.Revision,
		LastError = party.LastError,
	}
end

function Party:Get(player)
	return self:Snapshot(self.membership[player])
end

function Party:List()
	local result = {}
	for _, party in pairs(self.parties) do
		if party.State == "Open" and #party.Members < party.Capacity then
			table.insert(
				result,
				{
					Id = party.Id,
					HostUserId = party.Host.UserId,
					HostName = party.Host.DisplayName,
					Access = party.Access,
					Capacity = party.Capacity,
					Count = #party.Members,
				}
			)
		end
	end
	table.sort(result, function(a, b)
		return a.Id < b.Id
	end)
	while #result > 50 do
		table.remove(result)
	end
	return result
end

function Party:_publish(party)
	party.Revision += 1
	for _, member in ipairs(party.Members) do
		self.d.changed(member.Player, self:Snapshot(party))
	end
end

function Party:Create(player, capacity, access)
	if self.closing or not self.d.ready(player) then
		return false, "DataNotReady"
	end
	if self.membership[player] then
		return false, "AlreadyInParty"
	end
	if
		type(capacity) ~= "number"
		or capacity % 1 ~= 0
		or capacity < 1
		or capacity > self.d.config.MaxPartySize
		or (access ~= "Friends" and access ~= "Public")
	then
		return false, "InvalidParty"
	end
	self.serial += 1
	local party = {
		Id = tostring(self.serial),
		Host = player,
		Capacity = capacity,
		Access = access,
		State = "Open",
		Members = { { Player = player, Ready = true } },
		Banned = {},
		Revision = 0,
		Touched = self.d.clock(),
	}
	self.parties[party.Id] = party
	self.membership[player] = party
	self:_publish(party)
	return true
end

function Party:Join(player, id)
	local party = self.parties[id]
	if self.closing or not party or party.State ~= "Open" then
		return false, "PartyUnavailable"
	end
	if self.membership[player] or not self.d.ready(player) or party.Banned[player.UserId] then
		return false, "CannotJoin"
	end
	local host, revision = party.Host, party.Revision
	if party.Access == "Friends" then
		local ok, friend = pcall(self.d.friends, player, host)
		if not ok or not friend then
			return false, "FriendsOnly"
		end
	end
	-- Friendship lookup yields. The roster/host may have changed while it was in flight.
	if
		self.closing
		or self.parties[id] ~= party
		or party.State ~= "Open"
		or party.Revision ~= revision
		or self.membership[player]
		or not self.d.ready(player)
		or not self.d.present(player)
		or #party.Members >= party.Capacity
		or party.Banned[player.UserId]
	then
		return false, "PartyChanged"
	end
	table.insert(party.Members, { Player = player, Ready = false })
	self.membership[player] = party
	party.Touched = self.d.clock()
	self:_publish(party)
	return true
end

function Party:Ready(player, ready)
	local party = self.membership[player]
	if
		not party
		or (party.State ~= "Open" and party.State ~= "Countdown")
		or type(ready) ~= "boolean"
		or not self.d.ready(player)
	then
		return false, "CannotReady"
	end
	if party.State == "Countdown" and not ready then
		party.State = "Open"
		party.CountdownEndsAt = nil
	end
	for _, member in ipairs(party.Members) do
		if member.Player == player then
			member.Ready = ready
		end
	end
	party.Touched = self.d.clock()
	self:_publish(party)
	return true
end

function Party:Start(player)
	local party = self.membership[player]
	if self.closing or not party or party.Host ~= player or party.State ~= "Open" then
		return false, "HostOnly"
	end
	for _, member in ipairs(party.Members) do
		if not member.Ready or not self.d.ready(member.Player) then
			return false, "MembersNotReady"
		end
	end
	local allowed, reason = self.d.canTravel()
	if not allowed then
		return false, reason
	end
	party.State = "Countdown"
	party.LastError = nil
	party.CountdownEndsAt = self.d.clock() + self.d.config.CountdownSeconds
	self:_publish(party)
	return true
end

function Party:Cancel(player)
	local party = self.membership[player]
	if not party or party.Host ~= player or party.State ~= "Countdown" then
		return false, "CannotCancel"
	end
	party.State = "Open"
	party.CountdownEndsAt = nil
	self:_publish(party)
	return true
end

function Party:Remove(player, forced)
	local party = self.membership[player]
	if not party then
		return true
	end
	if not forced and (party.State == "Preparing" or party.State == "Teleporting") then
		return false, "TransferInProgress"
	end
	if party.State == "Preparing" then
		party.Cancelled = true
	end
	if party.State == "Countdown" then
		party.State = "Open"
		party.CountdownEndsAt = nil
	end
	self.membership[player] = nil
	for index, member in ipairs(party.Members) do
		if member.Player == player then
			table.remove(party.Members, index)
			break
		end
	end
	self.d.changed(player, nil)
	if #party.Members == 0 then
		self.parties[party.Id] = nil
		return true
	end
	if party.Host == player then
		party.Host = party.Members[1].Player
	end
	self:_publish(party)
	return true
end

function Party:Kick(player, userId)
	local party = self.membership[player]
	if not party or party.Host ~= player or party.State ~= "Open" or userId == player.UserId then
		return false, "CannotKick"
	end
	for _, member in ipairs(party.Members) do
		if member.Player.UserId == userId then
			party.Banned[userId] = true
			return self:Remove(member.Player, false)
		end
	end
	return false, "NotInParty"
end

function Party:_recover(party, reason)
	if self.parties[party.Id] ~= party then
		return
	end
	party.State = "Open"
	party.CountdownEndsAt = nil
	party.Cancelled = false
	party.LastError = reason
	party.Touched = self.d.clock()
	for _, member in ipairs(party.Members) do
		member.Ready = false
	end
	self:_publish(party)
end

function Party:Tick()
	if self.closing then
		return
	end
	for _, party in pairs(self.parties) do
		if party.State == "Countdown" then
			local valid = true
			for _, member in ipairs(party.Members) do
				if not member.Ready or not self.d.ready(member.Player) then
					valid = false
				end
			end
			if not valid then
				self:_recover(party, "MembersNotReady")
			elseif self.d.clock() >= party.CountdownEndsAt then
				party.State = "Preparing"
				party.Cancelled = false
				party.CountdownEndsAt = nil
				local roster = {}
				for _, member in ipairs(party.Members) do
					table.insert(roster, member.Player)
				end
				self:_publish(party)
				self.d.spawn(function()
					local ok, reason = self.d.travel(roster, function()
						return self.closing or party.Cancelled or self.parties[party.Id] ~= party
					end, function()
						self:_recover(party, "TransferFinished")
					end)
					if not ok then
						self:_recover(party, reason)
					elseif self.parties[party.Id] == party then
						party.State = "Teleporting"
						self:_publish(party)
					end
				end)
			end
		elseif party.State == "Open" and self.d.clock() - party.Touched > self.d.config.PartyIdleSeconds then
			local roster = table.clone(party.Members)
			for _, member in ipairs(roster) do
				self:Remove(member.Player, true)
			end
		end
	end
end

return Party
