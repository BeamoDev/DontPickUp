local root = script.Parent.Parent
assert(script:IsDescendantOf(game:GetService("ServerScriptService")), "GServer must sync inside ServerScriptService")
local Config = require(root.Configuration.ServerConfig)
local services = {}
for _, name in ipairs({
	"Players",
	"RunService",
	"ReplicatedStorage",
	"HttpService",
	"DataStoreService",
	"TweenService",
	"Workspace",
	"CollectionService",
	"ServerStorage",
	"MemoryStoreService",
	"TeleportService",
	"Lighting",
}) do
	services[name] = game:GetService(name)
end
assert(services.RunService:IsStudio() or game.PlaceId == Config.GamePlaceId, "Game bootstrap in wrong place")
local closing, data, network, interactions, orders, session = false, nil, nil, nil, nil, nil
local aimConnection, repairConnection
game:BindToClose(function()
	closing = true
	if aimConnection then
		aimConnection:Disconnect()
	end
	if repairConnection then
		repairConnection:Disconnect()
	end
	if network then
		network.closing = true
	end
	if session then
		session:Shutdown()
	end
	if interactions then
		if orders then
			orders:Shutdown()
		end
		interactions:Shutdown()
	end
	if data then
		data:Shutdown()
	end
end)
data = require(root.PlayerData.DataService).new(services, Config)
local shiftModeEnabled = require(root.Session.GameConfig).Enabled == true
network = require(root.Networking.NetworkService).new(services, "Game", shiftModeEnabled and "Remotes" or nil)
network.root:SetAttribute("PrototypeEnabled", shiftModeEnabled)
if shiftModeEnabled then
	session = require(root.Session.SessionService).new(services, Config, data, network)
	session:Start()
	services.ReplicatedStorage:SetAttribute("DPU_GameNetwork", network.root.Name)
	return
end
services.ReplicatedStorage:SetAttribute("DPU_GameNetwork", network.root.Name)
interactions = require(root.Interaction.InteractionService).new(services, function(player)
	return not closing and data:IsReady(player)
end)
local orderChanged = Instance.new("RemoteEvent")
orderChanged.Name, orderChanged.Parent = "OrderChanged", network.root
orders = require(root.Orders.BenchOrderService).new(services, {
	data = data,
	repairs = interactions.repairs,
	busy = function(player)
		return interactions.repairs.sessions[player] ~= nil or interactions.throws.holds[player] ~= nil
	end,
	changed = function(state, lines)
		for _, player in ipairs(services.Players:GetPlayers()) do
			if data:IsReady(player) then
				orderChanged:FireClient(player, state, lines)
			end
		end
	end,
})
local aim = Instance.new("RemoteEvent")
aim.Name, aim.Parent = "ThrowAim", network.root
aimConnection = aim.OnServerEvent:Connect(function(player, token, x, y, z)
	if not closing then
		interactions.throws:Aim(player, token, x, y, z)
	end
end)
local repairMove = Instance.new("RemoteEvent")
repairMove.Name, repairMove.Parent = "RepairDrag", network.root
repairConnection = repairMove.OnServerEvent:Connect(function(player, token, x, y)
	if not closing then
		interactions.repairs:Drag(player, token, x, y)
	end
end)
network:Bind(function(player, action, payload)
	if action == "GetOrderState" or action == "ServeCustomer" then
		return orders:Request(player, action, payload)
	end
	if
		action == "ToggleContainer"
		or action == "Drink"
		or action == "GrabThrow"
		or action == "ReleaseThrow"
		or action == "CancelThrow"
		or action == "BeginRepair"
		or action == "CancelRepair"
		or action == "RepairGrab"
		or action == "RepairDrop"
		or action == "RepairRelease"
	then
		return interactions:Request(player, action, payload)
	end
	if action == "GetState" then
		return { Ok = true, DataReady = data:IsReady(player) }
	end
	if action == "SetSetting" then
		local ok, reason = data:SetSetting(player, payload.Key, payload.Value)
		return { Ok = ok, Code = reason }
	end
	return { Ok = false, Code = "UnknownAction" }
end)
local function added(player)
	if not closing then
		data:Load(player)
		if not closing and data:IsReady(player) then
			orderChanged:FireClient(player, orders:Snapshot())
		end
	end
end
services.Players.PlayerRemoving:Connect(function(player)
	interactions:Remove(player)
	network:Remove(player)
	data:Remove(player)
end)
services.Players.PlayerAdded:Connect(added)
for _, player in ipairs(services.Players:GetPlayers()) do
	task.spawn(added, player)
end
task.spawn(function()
	while not closing do
		task.wait(1)
		if not closing then
			data:Tick()
			orders:Tick()
		end
	end
end)
