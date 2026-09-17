local Harness = require("./Harness")
local Signal = require("./TagFixture").Signal
local total = 0
local function check(value, label)
	assert(value, label)
	total += 1
end
local h, packets, shutdown = Harness.Environment(), {}, nil
h.env.game.PlaceId = 111652489432168
h.env.workspace = {
	GetServerTimeNow = function()
		return h.time
	end,
}
h.env.Random = {
	new = function()
		return {
			NextInteger = function(_, low)
				return low
			end,
		}
	end,
}
h.env.print = function() end
local newInstance = h.env.Instance.new
h.env.Instance.new = function(class)
	local item = newInstance(class)
	if class == "RemoteEvent" then
		item.OnServerEvent = Signal()
		item.FireClient = function(_, player, state)
			table.insert(packets, { player, state })
		end
	end
	return item
end
h.players.PlayerAdded, h.players.PlayerRemoving = Signal(), Signal()
local seated, attached, renders = {}, {}, 0
local world = {
	ChooseAppearance = function()
		return "npc_test"
	end,
	Near = function()
		return true
	end,
	Outside = function()
		return false
	end,
	Reset = function() end,
	Attach = function(_, player)
		attached[player] = true
	end,
	Remove = function(_, player)
		attached[player] = nil
	end,
	Render = function()
		renders += 1
	end,
	Shutdown = function(self)
		self.closed = true
	end,
	workshop = {
		IsSeated = function(_, player)
			return seated[player] == true
		end,
		SeatStation = function()
			return "Bench"
		end,
		Sit = function(_, player)
			seated[player] = true
			return true
		end,
		Stand = function(_, player)
			seated[player] = nil
		end,
		GivePart = function()
			return true
		end,
		HasPart = function()
			return true
		end,
		ClearPart = function() end,
		GiveGear = function()
			return true
		end,
		HasGear = function()
			return true
		end,
		ClearGear = function() end,
	},
}
local overrides = {
	["src/GServer/World/WorldService.luau"] = {
		new = function()
			return world
		end,
	},
	["src/GServer/Interaction/InteractionService.luau"] = {
		new = function()
			error("Authored mode must not start")
		end,
	},
	["src/GServer/Orders/BenchOrderService.luau"] = {
		new = function()
			error("Test bench must not start")
		end,
	},
}
local storage = h.instance("ReplicatedStorage")
local remotes = h.instance("Folder")
remotes.Name, remotes.Parent = "Remotes", storage
for _, spec in ipairs({ { "RemoteFunction", "Request" }, { "RemoteEvent", "StateChanged" } }) do
	local item = h.env.Instance.new(spec[1])
	item.Name, item.Parent = spec[2], remotes
end
local services = {
	Players = h.players,
	ReplicatedStorage = storage,
	RunService = {
		IsStudio = function()
			return true
		end,
	},
	HttpService = {
		GenerateGUID = function()
			h.serial += 1
			return "startup-" .. h.serial
		end,
	},
	MemoryStoreService = {
		GetHashMap = function()
			return {
				UpdateAsync = function()
					error("Studio direct entry must not claim tickets")
				end,
			}
		end,
	},
	TeleportService = {
		TeleportInitFailed = Signal(),
		TeleportAsync = function()
			error("Studio cannot teleport")
		end,
	},
}
local Runtime = h:load("src/GServer/Session/SessionService.luau", overrides)
local runtime
overrides["src/GServer/Session/SessionService.luau"] = {
	new = function(...)
		runtime = Runtime.new(...)
		return runtime
	end,
}
local function node(path)
	return setmetatable({ Path = path }, {
		__index = function(_, key)
			return node(key == "Parent" and path:match("^(.*)/[^/]+$") or path .. "/" .. key)
		end,
	})
end
local entry = node("src/GServer/Startup/Bootstrap.server")
entry.IsDescendantOf = function()
	return true
end
local game = {
	PlaceId = 111652489432168,
	GetService = function(_, name)
		return services[name] or {}
	end,
	BindToClose = function(_, callback)
		shutdown = callback
	end,
}
h:load("src/GServer/Startup/Bootstrap.server.luau", overrides, { script = entry, game = game })
check(
	runtime and runtime.net.root:GetAttribute("PrototypeEnabled") == true,
	"actual Game bootstrap selects prototype by default"
)
check(
	runtime.net.root.StateChanged
		and not runtime.net.root:FindFirstChild("ThrowAim")
		and not runtime.net.root:FindFirstChild("OrderChanged"),
	"prototype event exists without authored interaction/order remotes"
)
check(
	runtime.net.root == remotes
		and runtime.net.request == remotes.Request
		and runtime.net.changed == remotes.StateChanged
		and #remotes:GetChildren() == 2,
	"startup reuses exact saved remotes without duplicates"
)
check(
	storage:GetAttribute("DPU_GameNetwork") == "Remotes" and not storage:FindFirstChild("DontPickUpGameNet"),
	"client mode handshake names the authored remote root"
)
local players = {}
for i = 1, 4 do
	players[i] = h:player(i)
	h.players.PlayerAdded:Fire(players[i])
	check(
		runtime.data:IsReady(players[i]) and attached[players[i]],
		"Studio employee loads data and is attached to prototype spawn"
	)
end
local extra = h:player(5)
h.players.PlayerAdded:Fire(extra)
check(extra.Kicked and not attached[extra], "fifth employee is rejected before world attachment")
local p = players[1]
local function request(action, payload)
	return runtime.net.request.OnServerInvoke(p, action, payload)
end
check(request("GetPrototype").State.Phase == "Waiting", "initial request reaches real prototype snapshot")
check(request("Drink", { Id = "authored" }).Code == "UnknownAction", "authored remotes cannot mutate inactive mode")
-- Drive the real quarter-second maintenance task with a cooperative clock.
local job = table.remove(h.jobs, 1)
h.env.task.wait = function(seconds)
	h.time += seconds or 0
	coroutine.yield()
end
local loop = coroutine.create(function()
	job[1](table.unpack(job[2], 1, job[2].n))
end)
check(coroutine.resume(loop), "prototype maintenance loop starts")
check(coroutine.resume(loop), "prototype maintenance services its first tick")
h.time += 4
check(coroutine.resume(loop), "prototype maintenance advances preparation")
check(
	runtime.session:IsReady() and runtime.game.run.phase == "Tutorial",
	"direct Studio play reaches preparation without Lobby admission"
)
check(
	renders > 0 and #packets > 0 and packets[#packets][2].Kind == "Prototype",
	"world and replicated HUD snapshots update"
)
local run = runtime.game.run
check(
	request("PrototypeAction", { RunId = run.id, Action = "OpenClock" }).Ok,
	"clock-in interaction routes through real network and prototype"
)
local workPayload =
	{ RunId = run.id, Action = "PuzzleInput", OrderId = "old", WorkId = "old", PuzzleRevision = 0, Move = 1 }
check(
	request("PrototypeAction", workPayload).Code ~= "InvalidRequest",
	"six-field puzzle input reaches gameplay validation"
)
workPayload.Extra = true
check(request("PrototypeAction", workPayload).Code == "InvalidRequest", "seventh prototype field is rejected")
workPayload.Extra, workPayload.Move = nil, {}
check(request("PrototypeAction", workPayload).Code == "InvalidRequest", "nested prototype payload remains rejected")
h.time += 11
check(request("ReturnLobby").Code == "ShiftClosed", "cannot return before the shift settles")
run:Finish("Dawn")
h.time += 11
local result = request("ReturnLobby")
check(
	result.Code == "StudioPreviewComplete" and runtime.data:IsReady(p),
	"results Lobby return validates saving, previews in Studio and thaws data"
)
h.players.PlayerRemoving:Fire(players[2])
check(
	not attached[players[2]] and not runtime.game.run.players[players[2]],
	"departure releases prototype membership and world binding"
)
h.env.task.wait = function(seconds)
	h.time += seconds or 0
end
shutdown()
check(
	runtime.closed and world.closed and runtime.net.closing and not runtime.session.folder.Parent,
	"shutdown closes mode, session, world and network"
)
check(coroutine.resume(loop) and coroutine.status(loop) == "dead", "shutdown terminates the maintenance task")
local late = h:player(10)
h.players.PlayerAdded:Fire(late)
check(not attached[late], "shutdown disconnects player listeners")

-- Failed world setup must not strand admission folders or teleport listeners.
local connected
local oldConnect = services.TeleportService.TeleportInitFailed.Connect
services.TeleportService.TeleportInitFailed.Connect = function(signal, callback)
	connected = oldConnect(signal, callback)
	return connected
end
local FailingRuntime = h:load("src/GServer/Session/SessionService.luau", {
	["src/GServer/World/WorldService.luau"] = {
		new = function()
			error("broken authored scene")
		end,
	},
})
local coreConfig = h:load("src/GServer/Configuration/ServerConfig.luau")
local constructed = pcall(FailingRuntime.new, services, coreConfig, runtime.data, runtime.net)
check(
	not constructed and not storage:FindFirstChild("DontPickUpGameSession") and connected and not connected.Connected,
	"failed world constructor releases session and teleport listener"
)
local retryRuntime = Runtime.new(services, coreConfig, runtime.data, runtime.net)
retryRuntime:Shutdown()
check(not storage:FindFirstChild("DontPickUpGameSession"), "repaired startup can retry without duplicate session")
services.TeleportService.TeleportInitFailed.Connect = oldConnect

-- An incomplete authored network must fail clearly without fabricating missing remotes.
local Network = h:load("src/GServer/Networking/NetworkService.luau")
local missing = h.instance("ReplicatedStorage")
local ok, message = pcall(Network.new, { ReplicatedStorage = missing }, "Game", "Remotes")
check(
	not ok and tostring(message):find("Remotes") and #missing:GetChildren() == 0,
	"missing saved remotes fail without fallback construction"
)
local wrong = h.instance("Folder")
wrong.Name, wrong.Parent = "Remotes", missing
local request = h.instance("RemoteEvent")
request.Name, request.Parent = "Request", wrong
ok, message = pcall(Network.new, { ReplicatedStorage = missing }, "Game", "Remotes")
check(
	not ok and tostring(message):find("RemoteFunction") and #wrong:GetChildren() == 1,
	"incorrect saved remote class is rejected without duplicate replacement"
)

-- Client startup must choose a mode before constructing any other camera/HUD.
local client = Harness.Environment()
local starts, settingsStarts = 0, 0
local mode = client.instance("Folder")
mode:SetAttribute("PrototypeEnabled", true)
local clientServices = {
	Players = { LocalPlayer = {} },
	ReplicatedStorage = {
		GetAttribute = function()
			return "Remotes"
		end,
		WaitForChild = function()
			return mode
		end,
	},
}
local clientOverrides = {
	["src/GClient/Interface/SettingsController.luau"] = {
		Start = function()
			settingsStarts += 1
		end,
	},
	["src/GClient/Session/SessionController.luau"] = {
		Start = function()
			starts += 1
		end,
	},
	["src/GClient/Interface/DialogueDemoController.luau"] = {
		new = function()
			error("Authored dialogue must not start")
		end,
	},
}
local clientGlobals = { game = {
	GetService = function(_, name)
		return clientServices[name] or {}
	end,
} }
clientOverrides["src/GClient/Startup/GameController.luau"] =
	client:load("src/GClient/Startup/GameController.luau", clientOverrides, clientGlobals)
client:load("src/GClient/Startup/Bootstrap.local.luau", clientOverrides, clientGlobals)
check(starts == 1, "actual client entry starts prototype exactly once before authored controllers")
check(settingsStarts == 1, "Game settings starts once in prototype mode too")
print(
	string.format(
		"PASS: %d enabled prototype startup, networking, admission, return and cleanup checks (mocked Roblox).",
		total
	)
)
