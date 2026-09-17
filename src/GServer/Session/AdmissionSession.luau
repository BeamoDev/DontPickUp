local Session = {}
Session.__index = Session

function Session.new(services, config, data, tickets)
	local self = setmetatable({
		s = services,
		config = config,
		data = data,
		tickets = tickets,
		players = {},
		expected = {},
		state = "WaitingForParty",
		nextRead = 0,
		checking = false,
	}, Session)
	local folder = Instance.new("Folder")
	folder.Name = "DontPickUpGameSession"
	assert(not services.ReplicatedStorage:FindFirstChild(folder.Name), "Duplicate GameSession")
	folder.Parent = services.ReplicatedStorage
	self.folder = folder
	self:_publish()
	return self
end

function Session:_publish()
	local expected, loaded = 0, 0
	for _ in pairs(self.expected) do
		expected += 1
	end
	for player, ready in pairs(self.players) do
		if ready and player.Parent == self.s.Players then
			loaded += 1
		end
		player:SetAttribute("DPU_RunStatus", self.state)
	end
	self.folder:SetAttribute("State", self.state)
	self.folder:SetAttribute("ExpectedPlayers", expected)
	self.folder:SetAttribute("LoadedPlayers", loaded)
	self.folder:SetAttribute("Mode", self.mode or "Story")
end

function Session:Admit(player)
	if self.players[player] ~= nil then
		return true
	end
	local count = 0
	for _ in pairs(self.players) do
		count += 1
	end
	if count >= self.config.MaxPartySize then
		return false, "PartyFull"
	end
	if self.s.RunService:IsStudio() and self.config.StudioAllowDirectGame then
		self.practice = true
		self.mode = self.config.StudioGameMode == "Endless" and "Endless" or "Story"
		self.expected[tostring(player.UserId)] = true
		self.players[player] = false
		self:_publish()
		return true
	end
	if self.state == "Ready" then
		return false, "SessionAlreadyStarted"
	end
	local admission, reason = self.tickets:Claim(player)
	if not admission then
		return false, reason
	end
	if self.id and self.id ~= admission.Id then
		return false, "DifferentParty"
	end
	if self.state == "Incomplete" or self.state == "Interrupted" then
		return false, "SessionClosed"
	end
	self.id = admission.Id
	self.mode = admission.Ticket.Mode or "Story"
	self.gameData = admission.Ticket.GameData and table.clone(admission.Ticket.GameData) or nil
	for id in pairs(admission.Ticket.Members) do
		self.expected[id] = true
	end
	self.players[player] = false
	self.loadDeadline = self.loadDeadline or os.clock() + self.config.LoadTimeoutSeconds + 10
	self:_publish()
	return true
end

function Session:Loaded(player)
	if self.players[player] == nil then
		return
	end
	self.players[player] = true
	self.arrivalDeadline = self.arrivalDeadline or os.clock() + self.config.ArrivalSeconds
	self:_publish()
end

function Session:Remove(player)
	if self.players[player] == nil then
		return
	end
	self.players[player] = nil
	if self.practice then
		self.expected[tostring(player.UserId)] = nil
	elseif self.state == "Ready" then
		-- Once the whole party has arrived, a departure must not kill friends' run.
		self.expected[tostring(player.UserId)] = nil
		if not next(self.players) then
			self.state = "Interrupted"
		end
	end
	self:_publish()
end

function Session:Snapshot()
	return {
		State = self.state,
		ExpectedPlayers = self.folder:GetAttribute("ExpectedPlayers"),
		LoadedPlayers = self.folder:GetAttribute("LoadedPlayers"),
		Mode = self.mode or "Story",
		GameData = self.gameData and table.clone(self.gameData) or nil,
	}
end

function Session:IsReady()
	if self.state ~= "Ready" then
		return false
	end
	for player in pairs(self.players) do
		if not self.data:IsReady(player) then
			return false
		end
	end
	return true
end

function Session:Tick()
	if self.state ~= "WaitingForParty" then
		return
	end
	local loaded = {}
	for player, ready in pairs(self.players) do
		if ready and player.Parent == self.s.Players and self.data:IsReady(player) then
			loaded[tostring(player.UserId)] = true
		end
	end
	local complete = next(self.expected) ~= nil
	for id in pairs(self.expected) do
		if not loaded[id] then
			complete = false
		end
	end
	if complete then
		self.state = "Ready"
		self:_publish()
		return
	end
	local deadline = self.arrivalDeadline or self.loadDeadline
	if deadline and os.clock() >= deadline then
		self.state = "Incomplete"
		self:_publish()
		return
	end
	if self.id and not self.checking and os.clock() >= self.nextRead then
		self.checking = true
		self.nextRead = os.clock() + 5
		task.spawn(function()
			local ok, ticket = self.tickets:Read(self.id)
			self.checking = false
			if self.state ~= "WaitingForParty" then
				return
			end
			if ok and ticket then
				for _, member in pairs(ticket.Members) do
					if member.Revoked then
						self.state = "Incomplete"
						self:_publish()
						break
					end
				end
			end
		end)
	end
end

return Session
