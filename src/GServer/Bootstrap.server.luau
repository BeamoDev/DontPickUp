local ServerScriptService = game:GetService("ServerScriptService")
assert(script:IsDescendantOf(ServerScriptService), "GServer must sync inside ServerScriptService")
local root = script.Parent
local Config = require(root.Core.Config)
local services = {}
for _, name in ipairs({
	"Players",
	"RunService",
	"ReplicatedStorage",
	"HttpService",
	"DataStoreService",
	"MemoryStoreService",
	"TeleportService",
	"Lighting",
	"TweenService",
}) do
	services[name] = game:GetService(name)
end
assert(services.RunService:IsStudio() or game.PlaceId == Config.GamePlaceId, "Game bootstrap in wrong place")
local closing = false
local data, travel, session, network, prototype
game:BindToClose(function()
	closing = true
	if prototype then
		prototype:Shutdown()
	end
	if network then
		network.closing = true
	end
	if travel then
		travel:Shutdown()
	end
	if data then
		data:Shutdown()
	end
end)
data = require(root.Core.DataService).new(services, Config)
local tickets = require(root.Core.TicketStore).new(services, Config)
travel = require(root.Core.TravelService).new(services, Config, data, tickets)
session = require(root.GameSession).new(services, Config, data, tickets)
network = require(root.Core.Network).new(services, "Game")
network.root:SetAttribute("PrototypeEnabled", require(root.PrototypeConfig).Enabled)
if require(root.PrototypeConfig).Enabled then
	prototype = require(root.GamePrototype).new(services, data, session, network)
end
require(root.Runtime).Set({ Data = data, Session = session, Travel = travel, Prototype = prototype })
network:Bind(function(player, action, payload)
	if prototype and (action == "GetPrototype" or action == "PrototypeAction") then
		return prototype:Request(player, action, payload)
	end
	if action == "GetState" then
		return { Ok = true, State = session:Snapshot(), DataReady = data:IsReady(player) }
	end
	if action == "SetSetting" then
		local ok, reason = data:SetSetting(player, payload.Key, payload.Value)
		return { Ok = ok, Code = reason }
	end
	if action == "ReturnLobby" then
		if prototype and not prototype.run:CanReturn(player) then
			return { Ok = false, Code = "ShiftClosed" }
		end
		local ok, reason = travel:Begin({ player }, "Lobby", function()
			return closing or player.Parent ~= services.Players
		end)
		return { Ok = ok, Code = reason }
	end
	return { Ok = false, Code = "UnknownAction" }
end)
local joining = {}
local function added(player)
	if closing or joining[player] then
		return
	end
	joining[player] = true
	player:SetAttribute("DPU_DataStatus", "CheckingAdmission")
	local ok, reason = session:Admit(player)
	if not ok then
		player:Kick("Join a private session from the lobby. (" .. reason .. ")")
		return
	end
	if closing or player.Parent ~= services.Players then
		session:Remove(player)
		return
	end
	if data:Load(player) then
		session:Loaded(player)
		if prototype then
			prototype:Add(player)
		end
	else
		session:Remove(player)
	end
end
services.Players.PlayerRemoving:Connect(function(player)
	joining[player] = nil
	if prototype then
		prototype:Remove(player)
	end
	session:Remove(player)
	travel:Remove(player)
	network:Remove(player)
	data:Remove(player)
end)
services.Players.PlayerAdded:Connect(added)
for _, player in ipairs(services.Players:GetPlayers()) do
	task.spawn(added, player)
end
task.spawn(function()
	local nextServices = 0
	while not closing do
		task.wait(0.25)
		if os.clock() >= nextServices then
			nextServices = os.clock() + 1
			data:Tick()
			session:Tick()
			travel:Tick()
		end
		if prototype then
			prototype:Tick()
		end
	end
end)
