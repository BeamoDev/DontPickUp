-- Lifecycle adapter for the restored game. Core profiles/network remain shared
-- with the authored mode; only one mode starts in a Game server.
local Config = require(script.Parent.GameConfig)
local Tickets = require(script.Parent.Parent.Travel.TicketStore)
local Travel = require(script.Parent.Parent.Travel.TravelService)
local Session = require(script.Parent.AdmissionSession)
local GameService = require(script.Parent.GameService)
local SessionService = {}
SessionService.__index = SessionService
function SessionService.new(services, coreConfig, data, network)
	assert(network.changed and network.changed:IsA("RemoteEvent"), "[DPU] Missing Remotes.StateChanged")
	local config = table.clone(coreConfig)
	config.StudioAllowDirectGame = true
	config.StudioGameMode = Config.StartMode or "Story"
	config.ArrivalSeconds = 45
	local self =
		setmetatable({ s = services, data = data, net = network, connections = {}, joining = {} }, SessionService)
	self.tickets = Tickets.new(services, config)
	self.travel = Travel.new(services, config, data, self.tickets)
	local ok, result = pcall(function()
		self.session = Session.new(services, config, data, self.tickets)
		return GameService.new(services, data, self.session, network)
	end)
	if not ok then
		self.travel:Shutdown()
		if self.session then
			self.session.folder:Destroy()
		end
		error(result, 0)
	end
	self.game = result
	return self
end
function SessionService:Add(player)
	if self.closed or self.joining[player] then
		return
	end
	self.joining[player] = true
	player:SetAttribute("DPU_DataStatus", "CheckingAdmission")
	local ok, reason = self.session:Admit(player)
	if not ok then
		player:Kick("Join from the Lobby to start a shift. (" .. tostring(reason) .. ")")
		return
	end
	if self.closed or player.Parent ~= self.s.Players then
		self.session:Remove(player)
		return
	end
	if self.data:Load(player) then
		if self.closed or player.Parent ~= self.s.Players then
			self.session:Remove(player)
			return
		end
		self.session:Loaded(player)
		self.game:Add(player)
	else
		self.session:Remove(player)
	end
end
function SessionService:Remove(player)
	self.joining[player] = nil
	self.game:Remove(player)
	self.session:Remove(player)
	self.travel:Remove(player)
	self.net:Remove(player)
	self.data:Remove(player)
end
function SessionService:Request(player, action, payload)
	if self.closed then
		return { Ok = false, Code = "ShiftClosed" }
	end
	if action == "GetPrototype" or action == "PrototypeAction" then
		return self.game:Request(player, action, payload)
	elseif action == "GetState" then
		return { Ok = true, State = self.session:Snapshot(), DataReady = self.data:IsReady(player) }
	elseif action == "SetSetting" then
		local ok, reason = self.data:SetSetting(player, payload.Key, payload.Value)
		return { Ok = ok, Code = reason }
	elseif action == "ReturnLobby" then
		if not self.game.run:CanReturn(player) then
			return { Ok = false, Code = "ShiftClosed" }
		end
		local ok, reason = self.travel:Begin({ player }, "Lobby", function()
			return self.closed or player.Parent ~= self.s.Players
		end)
		return { Ok = ok, Code = reason }
	end
	return { Ok = false, Code = "UnknownAction" }
end
function SessionService:Start()
	self.net:Bind(function(player, action, payload)
		return self:Request(player, action, payload)
	end)
	table.insert(
		self.connections,
		self.s.Players.PlayerAdded:Connect(function(player)
			self:Add(player)
		end)
	)
	table.insert(
		self.connections,
		self.s.Players.PlayerRemoving:Connect(function(player)
			self:Remove(player)
		end)
	)
	for _, player in ipairs(self.s.Players:GetPlayers()) do
		task.spawn(function()
			self:Add(player)
		end)
	end
	task.spawn(function()
		local nextServices = 0
		while not self.closed do
			task.wait(0.25)
			if self.closed then
				break
			end
			if os.clock() >= nextServices then
				nextServices = os.clock() + 1
				self.data:Tick()
				self.session:Tick()
				self.travel:Tick()
			end
			self.game:Tick()
		end
	end)
end
function SessionService:Shutdown()
	if self.closed then
		return
	end
	self.closed = true
	for _, connection in ipairs(self.connections) do
		connection:Disconnect()
	end
	self.game:Shutdown()
	self.travel:Shutdown()
	self.session.folder:Destroy()
end
return SessionService
