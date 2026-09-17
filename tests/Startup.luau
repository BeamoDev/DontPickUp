local Harness = require("./Harness")
local Signal = require("./TagFixture").Signal
local fs = require("@lune/fs")
local total = 0
local function check(value, label)
	assert(value, label)
	total += 1
end
for _, prefix in ipairs({ "G", "L" }) do
	local h, overrides, shutdown = Harness.Environment(), {}, nil
	h.env.Instance.new = function(class)
		local item = h.instance(class)
		if class == "RemoteEvent" then
			item.OnServerEvent = Signal()
			item.FireClient = function() end
		end
		return item
	end
	local root, scope = {}, "src/" .. prefix .. "Server/"
	for _, folder in ipairs(fs.readDir(scope)) do
		root[folder] = {}
		for _, file in ipairs(fs.readDir(scope .. folder)) do
			local name = file:gsub("%.server%.luau$", ""):gsub("%.luau$", "")
			root[folder][name] = { Path = scope .. folder .. "/" .. file:gsub("%.luau$", "") }
		end
	end
	root.Startup.Parent = root
	local loaded, removed, actions, stopped = 0, 0, 0, 0
	local data = {
		IsReady = function()
			return true
		end,
		Load = function()
			loaded += 1
			return true
		end,
		Remove = function()
			removed += 1
		end,
		Shutdown = function()
			stopped += 1
		end,
	}
	local travel = { Remove = function() end, Shutdown = function() end }
	local network = { root = h.instance("Folder") }
	function network:Bind(callback)
		self.handler = callback
	end
	function network:Remove() end
	local interactions = {
		Request = function(_, _, action)
			actions += 1
			return { Ok = true, Action = action }
		end,
		Remove = function() end,
		Shutdown = function()
			stopped += 1
		end,
	}
	local queues = {
		Get = function()
			return { Active = false }
		end,
	}
	local world = {
		queues = queues,
		Remove = function() end,
		Shutdown = function()
			stopped += 1
		end,
	}
	local party = { Remove = function() end }
	local function module(path, object)
		overrides[scope .. path .. ".luau"] = {
			new = function()
				return object
			end,
		}
	end
	module("PlayerData/DataService", data)
	module("Travel/TicketStore", {})
	module("Travel/TravelService", travel)
	module("Networking/NetworkService", network)
	overrides["src/GServer/Session/GameConfig.luau"] = { Enabled = false }
	module("Interaction/InteractionService", interactions)
	module("Orders/BenchOrderService", {
		Request = function(_, _, action)
			return { Ok = true, Action = action }
		end,
		Snapshot = function()
			return { Stage = "Idle" }
		end,
		Shutdown = function()
			stopped += 1
		end,
	})
	module("Matchmaking/PartyService", party)
	module("World/LobbyWorldService", world)
	local runtime
	overrides[scope .. "Startup/Runtime.luau"] = {
		Set = function(value)
			runtime = value
		end,
	}
	h.players.PlayerAdded, h.players.PlayerRemoving = Signal(), Signal()
	local services = {
		ReplicatedStorage = h.instance("ReplicatedStorage"),
		Players = h.players,
		RunService = {
			IsStudio = function()
				return true
			end,
		},
	}
	local mockGame = { PlaceId = prefix == "G" and 111652489432168 or 110554757455252 }
	function mockGame:GetService(name)
		return services[name] or {}
	end
	function mockGame:BindToClose(callback)
		shutdown = callback
	end
	local scriptObject = {
		Parent = root.Startup,
		IsDescendantOf = function()
			return true
		end,
	}
	h:load(scope .. "Startup/Bootstrap.server.luau", overrides, {
		game = mockGame,
		script = scriptObject,
		workspace = {
			GetServerTimeNow = function()
				return 0
			end,
		},
	})
	if prefix == "L" then
		check(
			runtime and runtime.Data == data and runtime.Travel == travel,
			"Lobby runtime retains queue/teleport services"
		)
	else
		check(runtime == nil, "Game no longer creates an unused runtime registry")
	end
	check(network.handler ~= nil and shutdown ~= nil, prefix .. " bootstrap binds requests and shutdown")
	local player = h:player(8)
	h.players.PlayerAdded:Fire(player)
	check(loaded == 1, prefix .. " player admission reaches data load")
	if prefix == "G" then
		check(
			network.handler(player, "GetState", {}).DataReady == true,
			"Game enables interactions from loaded profile without party admission"
		)
		check(
			network.handler(player, "Drink", { Id = "drink" }).Ok and actions == 1,
			"active gameplay endpoint routes once"
		)
		check(
			network.handler(player, "BeginRepair", { Id = "phone" }).Ok
				and actions == 2
				and network.root:FindFirstChild("RepairDrag") ~= nil,
			"repair request and bounded drag event are wired at startup"
		)
		check(network.handler(player, "Unknown", {}).Code == "UnknownAction", "unrecognised endpoint stays rejected")
		check(
			network.handler(player, "ServeCustomer", {}).Action == "ServeCustomer"
				and network.handler(player, "GetOrderState", {}).Ok
				and network.root:FindFirstChild("OrderChanged") ~= nil,
			"orders requests and state event are wired"
		)
	else
		check(runtime.Queues == queues and runtime.Party == party, "Lobby starts queues and parties")
		check(
			network.handler(player, "GetQueueState", {}).Queue.Active == false,
			"Lobby endpoint reads authoritative queue state"
		)
	end
	h.players.PlayerRemoving:Fire(player)
	check(removed == 1, prefix .. " departure releases data")
	shutdown()
	check(
		stopped == (prefix == "G" and 3 or 2) and network.closing,
		prefix .. " shutdown reaches gameplay and data services"
	)
end
print(string.format("PASS: %d Game and Lobby bootstrap wiring checks (mocked Roblox).", total))
