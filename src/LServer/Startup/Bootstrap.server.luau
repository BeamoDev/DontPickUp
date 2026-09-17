local ServerScriptService = game:GetService("ServerScriptService")
assert(script:IsDescendantOf(ServerScriptService), "LServer must sync inside ServerScriptService")
local root = script.Parent.Parent
local Config = require(root.Configuration.ServerConfig)
local services = {}
for _, name in ipairs({
	"Players",
	"RunService",
	"ReplicatedStorage",
	"HttpService",
	"DataStoreService",
	"MemoryStoreService",
	"TeleportService",
}) do
	services[name] = game:GetService(name)
end
assert(services.RunService:IsStudio() or game.PlaceId == Config.LobbyPlaceId, "Lobby bootstrap in wrong place")
local closing = false
local data, travel, party, network, world
-- Register shutdown before player loading can yield.
game:BindToClose(function()
	closing = true
	if world then
		world:Shutdown()
	end
	if network then
		network.closing = true
	end
	if party then
		party.closing = true
	end
	if travel then
		travel:Shutdown()
	end
	if data then
		data:Shutdown()
	end
end)

data = require(root.PlayerData.DataService).new(services, Config)
local tickets = require(root.Travel.TicketStore).new(services, Config)
travel = require(root.Travel.TravelService).new(services, Config, data, tickets)
network = require(root.Networking.NetworkService).new(services, "Lobby")
party = require(root.Matchmaking.PartyService).new({
	config = Config,
	clock = function()
		return workspace:GetServerTimeNow()
	end,
	spawn = task.spawn,
	ready = function(player)
		return data:IsReady(player)
	end,
	present = function(player)
		return player.Parent == services.Players
	end,
	friends = function(player, host)
		return player:IsFriendsWithAsync(host.UserId)
	end,
	changed = function(player, state)
		player:SetAttribute("DPU_PartyId", state and state.Id or nil)
		player:SetAttribute("DPU_QueueStatus", state and state.State or "None")
		network:Push(player, state)
		if world then
			world.queues:PartyChanged(player)
		end
	end,
	canTravel = function()
		if services.RunService:IsStudio() and not Config.StudioTeleportPreview then
			return false, "TeleportUnavailableInStudio"
		end
		return Config.GamePlaceId > 0 and Config.GamePlaceId ~= game.PlaceId, "PlaceNotConfigured"
	end,
	travel = function(roster, cancelled, finished, options)
		return travel:Begin(roster, "Game", cancelled, finished, options)
	end,
})
world = require(root.World.LobbyWorldService).new(services, Config, data, party, network)
require(script.Parent.Runtime).Set({ Data = data, Party = party, Travel = travel, Queues = world.queues })

network:Bind(function(player, action, payload)
	if action == "GetQueueState" then
		return { Ok = true, Queue = world.queues:Get(player) }
	end
	if action == "QueueCreate" or action == "QueueLeave" then
		return world.queues:Request(player, action, payload)
	end
	if action == "GetState" then
		return {
			Ok = true,
			State = party:Get(player),
			Parties = party:List(),
			DataReady = data:IsReady(player),
		}
	end
	local ok, reason
	if world.queues.players[player] and table.find({ "Leave", "Ready", "Start", "Cancel", "Kick" }, action) then
		return { Ok = false, Code = "UseQueueControls" }
	end
	if action == "Create" then
		if world.queues.players[player] then
			return { Ok = false, Code = "UseQueueCreate" }
		end
		ok, reason =
			party:Create(player, payload.Capacity or Config.MaxPartySize, payload.Access or "Friends", payload.Mode)
	elseif action == "Join" then
		if world.queues.players[player] then
			return { Ok = false, Code = "AlreadyQueued" }
		end
		for _, bay in pairs(world.queues.bays) do
			if bay.PartyId == payload.PartyId then
				return { Ok = false, Code = "UseQueueEntrance" }
			end
		end
		ok, reason = party:Join(player, payload.PartyId)
	elseif action == "Leave" then
		ok, reason = world.queues:Leave(player, false)
	elseif action == "Ready" then
		ok, reason = party:Ready(player, payload.Ready)
	elseif action == "Start" then
		ok, reason = party:Start(player)
	elseif action == "Cancel" then
		ok, reason = party:Cancel(player)
	elseif action == "Kick" then
		ok, reason = party:Kick(player, payload.UserId)
	elseif action == "SetSetting" then
		ok, reason = data:SetSetting(player, payload.Key, payload.Value)
	else
		return { Ok = false, Code = "UnknownAction" }
	end
	return { Ok = ok, Code = reason, State = party:Get(player) }
end)

services.Players.PlayerRemoving:Connect(function(player)
	world:Remove(player)
	party:Remove(player, true)
	travel:Remove(player)
	network:Remove(player)
	data:Remove(player)
end)
services.Players.PlayerAdded:Connect(function(player)
	if not closing then
		data:Load(player)
	end
end)
for _, player in ipairs(services.Players:GetPlayers()) do
	task.spawn(function()
		if not closing then
			data:Load(player)
		end
	end)
end
task.spawn(function()
	local nextServices = 0
	while not closing do
		task.wait(0.25)
		world:Tick()
		if os.clock() >= nextServices then
			nextServices = os.clock() + 1
			data:Tick()
			party:Tick()
			travel:Tick()
		end
	end
end)
