local fs = require("@lune/fs")
local serde = require("@lune/serde")
local Harness = require("./Harness")
local Signal = require("./TagFixture").Signal
local count = 0
local function check(ok, reason)
	assert(ok, reason)
	count += 1
end
local deployment = serde.decode("json", fs.readFile("project.sources.json"))
local roots = { GClient = true, GServer = true, GShared = true, LClient = true, LServer = true, LShared = true }
for _, root in ipairs(fs.readDir("src")) do
	check(roots[root], "only the six existing runtime roots: " .. root)
	local executable = {}
	for _, system in ipairs(fs.readDir("src/" .. root)) do
		local folder = "src/" .. root .. "/" .. system
		check(fs.isDir(folder) and system ~= "Prototype" and system ~= "Core", "named system folder: " .. folder)
		for _, file in ipairs(fs.readDir(folder)) do
			check(fs.isFile(folder .. "/" .. file) and file:match("%.luau$"), "only scripts/modules inside systems")
			if file:match("%.local%.luau$") or file:match("%.server%.luau$") then
				table.insert(executable, system .. "/" .. file)
			end
		end
	end
	local suffix = root:find("Client") and "local" or root:find("Server") and "server"
	check(#executable == (suffix and 1 or 0), "exactly one executable per side/place, none in Shared")
	if suffix then
		check(executable[1] == "Startup/Bootstrap." .. suffix .. ".luau", "executable is the bootstrap")
	end
	check(deployment.RuntimeRoots[root].Source == "src/" .. root, "deployment retains root identity")
end
for old, new in pairs(serde.decode("json", fs.readFile("tests/SourceMoves.json"))) do
	check(not fs.isFile("src/" .. old .. ".luau"), "obsolete source removed: " .. old)
	check(fs.isFile("src/" .. new .. ".luau"), "move destination exists: " .. new)
end
local destinations = {}
for _, module in ipairs(deployment.CommonModules) do
	check(fs.isFile(module.Source), "common module has a maintained implementation")
	check(#module.Targets == 2, "common module deploys to both places")
	for _, target in ipairs(module.Targets) do
		check(not destinations[target], "generated destination has exactly one owner")
		destinations[target] = true
		check(fs.readFile(module.Source) == fs.readFile(target), "generated module matches maintained source")
	end
end
local h = Harness.Environment()
for _, path in ipairs({
	"src/GClient/Startup/GameController.luau",
	"src/GClient/Session/SessionController.luau",
	"src/LClient/Matchmaking/QueueController.luau",
}) do
	check(type(h:load(path).Start) == "function" and #h.jobs == 0, "requiring controller does not start work: " .. path)
end

-- Destroying Lobby bootstrap during asynchronous setup must not leave a loop or subscription.
local player = h:player(90)
player.WaitForChild = function(self, name)
	return self:FindFirstChild(name)
end
local function node(class, name, parent)
	local object = h.instance(class)
	object.Name, object.Parent = name, parent
	object.WaitForChild = function(self, child)
		return self:FindFirstChild(child)
	end
	return object
end
local scripts = node("Folder", "PlayerScripts", player)
node("PlayerGui", "PlayerGui", player)
local entrypoint = node("LocalScript", "Bootstrap", scripts)
entrypoint.Destroying = Signal()
local destroyed, mounted = 0, 0
local requests = {
	Destroy = function()
		destroyed += 1
	end,
}
local services =
	{ Players = { LocalPlayer = player }, RunService = {}, ReplicatedStorage = node("Folder", "ReplicatedStorage") }
local fakeScript = {
	IsDescendantOf = function()
		return true
	end,
	Parent = {
		QueueRequests = { Path = "src/LClient/Matchmaking/QueueRequests" },
		Parent = { Interface = { QueueView = { Path = "src/LClient/Interface/QueueView" } } },
	},
}
local controller = h:load("src/LClient/Matchmaking/QueueController.luau", {
	["src/LClient/Matchmaking/QueueRequests.luau"] = {
		new = function()
			return requests
		end,
	},
	["src/LClient/Interface/QueueView.luau"] = {
		new = function()
			mounted += 1
		end,
	},
}, { script = fakeScript, game = {
	GetService = function(_, name)
		return services[name]
	end,
} })
local cleanup = controller.Start(entrypoint)
check(#h.jobs == 2, "Lobby work begins only after explicit Start")
entrypoint.Destroying:Fire()
cleanup()
h:drain()
check(destroyed == 1 and mounted == 0, "cancelled startup cleans once and late tasks never mount UI")
print(string.format("PASS: %d system layout, common package and explicit startup checks.", count))
