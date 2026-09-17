local Harness = require("./Harness")
local Roblox = require("@lune/roblox")
local Fixture = require("./TagFixture")
local h, total = Harness.Environment(), 0
local function check(ok, message)
	assert(ok, message)
	total += 1
end
for _, key in ipairs({ "Vector3", "Vector2", "CFrame", "Color3", "UDim2", "UDim" }) do
	h.env[key] = Roblox[key]
end
h.env.Enum = Roblox.Enum
h.env.RaycastParams = {
	new = function()
		return {}
	end,
}
h.env.TweenInfo = {
	new = function(seconds)
		return { seconds = seconds }
	end,
}
local make = h.env.Instance.new
h.env.Instance.new = function(class)
	local item = make(class)
	item.ChildAdded, item.ChildRemoved, item.Triggered = Fixture.Signal(), Fixture.Signal(), Fixture.Signal()
	item.GetConnectedParts = function()
		return item.connected or {}
	end
	return item
end
local function node(class, name, parent)
	local item = h.env.Instance.new(class)
	item.Name, item.Parent = name, parent
	return item
end
local ws, storage = node("Workspace", "Workspace"), node("ReplicatedStorage", "ReplicatedStorage")
h.env.workspace = ws
ws.GetServerTimeNow = function()
	return h.time
end
local wall, obstructed = node("Part", "Wall", ws), false
wall.CanCollide = true
ws.Raycast = function()
	return obstructed and { Instance = wall, Position = Roblox.Vector3.zero } or nil
end
require("./PrototypeAssets").Build(h, "PrototypeWorld", nil, ws, storage)
local shop = ws.Prototype.DPU_Prototype
check(
	not shop:FindFirstChild("WaitingChair") and shop:FindFirstChild("RepairSeat") and shop:FindFirstChild("Bench2Seat"),
	"shop fixture has no waiting chair and retains both repair seats"
)
for _, child in ipairs(shop:GetChildren()) do
	if child.Name:match("^Secret_") or child.Name == "Tool_BrassKey" then
		child:Destroy()
	end
end
local cabinet = node("Model", "Storage", shop)
local boxes, parts, labels, originals = {}, {}, {}, {}
for index, fault in ipairs({ "Battery", "Keypad", "Speaker" }) do
	local pickup = shop:FindFirstChild("Part_" .. fault)
	pickup.Name, pickup.Parent = "Part_" .. fault .. "Box" .. index, cabinet
	pickup.CFrame = Roblox.CFrame.new(index * 2, 3, 400) * Roblox.CFrame.Angles(0, 0.4, 0)
	pickup.Position, pickup.CanQuery, pickup.Anchored = pickup.CFrame.Position, true, true
	local box = node("Part", "Box" .. index, cabinet)
	box.CFrame, box.Position, box.Size = pickup.CFrame, pickup.Position, Roblox.Vector3.new(2, 1, 2)
	box.Anchored, box.CanQuery = true, true
	local label = node("Part", "Label" .. index, cabinet)
	label.CFrame, label.Position, label.Anchored, label.CanQuery =
		pickup.CFrame + Roblox.Vector3.new(0, 0, 0.5), pickup.Position, true, true
	boxes[index], labels[index], parts[index], originals[index] = box, label, pickup, pickup.CFrame
end
local tweens = {}
local services = {
	Workspace = ws,
	ReplicatedStorage = storage,
	Players = h.players,
	CollectionService = Fixture.Collection(),
	Lighting = { ClockTime = 12 },
	HttpService = {
		GenerateGUID = function()
			h.serial += 1
			return tostring(h.serial)
		end,
	},
	TweenService = {},
}
function services.TweenService:Create(target, info, goals)
	local tween = { Completed = Fixture.Signal(), seconds = info.seconds, start = target.CFrame }
	function tween:Play()
		self.played = true
	end
	function tween:Cancel()
		self.cancelled = true
	end
	function tween:At(alpha)
		target.CFrame = self.start:Lerp(goals.CFrame, alpha)
		target.Position = target.CFrame.Position
	end
	function tween:Finish()
		self:At(1)
		self.Completed:Fire(Roblox.Enum.PlaybackState.Completed)
	end
	tweens[target] = tween
	return tween
end
-- Owner replaced two old sibling scenery parts with the authored TV Model.
for _, name in ipairs({ "CRT", "CRTScreen" }) do
	local old = shop:FindFirstChild(name)
	if old then
		old:Destroy()
	end
end
local crt = node("Model", "CRT", shop)
local monitor, crtScreen = node("Part", "Monitor", crt), node("Part", "CRTScreen", crt)
local config = h:load("src/GServer/Session/GameConfig.luau")
local authoredAnchor = shop.RepairPhone
local sourceDevice = storage.Assets.Devices.Phone
local sourcePose = sourceDevice.Phone.CFrame
local world = h:load("src/GServer/World/WorldService.luau").new(services, config)
check(
	world.stations.Secret_Directive == nil and world.stations.Secret_Locker == nil,
	"startup accepts all removed secret notes"
)
local Scene = h:load("src/GShared/World/SceneReferences.luau")
check(
	shop.RepairPhone ~= authoredAnchor
		and shop.RepairPhone:GetAttribute("DPU_DeviceId") == "Phone"
		and shop.CounterPhone_Bench:FindFirstChild("BackCover")
		and shop.RepairPhone2:FindFirstChild("Screws"),
	"both benches and counter phones clone the authored Devices.Phone"
)
check(
	authoredAnchor.Parent == nil and sourceDevice.Phone.CFrame == sourcePose,
	"placement anchors are preserved and source device pose stays unchanged"
)
check(
	shop.RepairPhone:FindFirstChild("Speaker")
		and shop.RepairPhone:FindFirstChild("Keypad")
		and sourceDevice:FindFirstChild("Speaker") == nil,
	"stock component art is added only to runtime device copies"
)
local puzzles = h:load("src/GServer/Repair/RepairPuzzles.luau")
local devicePuzzle = puzzles.New("Diagnose", "Speaker", 1, 4, h.time, true, false, true)
local deviceLane = {
	order = { Id = "device_test", Step = "Diagnose", Fault = "Speaker" },
	work = { Id = "opening", Puzzle = devicePuzzle },
}
local function moveDevice()
	world.devices:Update("RepairPhone", deviceLane)
	for _, tween in pairs(world.devices.views.RepairPhone.tweens) do
		tween:Finish()
	end
end
moveDevice()
local screw = shop.RepairPhone.Screws.Screw1
check(puzzles.Input(devicePuzzle, 1, devicePuzzle.Revision, h.time), "server accepts first opening screw")
moveDevice()
check(screw.CFrame == screw:GetAttribute("DPU_DeviceLoose"), "opening screw moves in replicated world")
for index = 2, 4 do
	puzzles.Input(devicePuzzle, index, devicePuzzle.Revision, h.time)
end
puzzles.Input(devicePuzzle, 11, devicePuzzle.Revision, h.time)
moveDevice()
check(
	shop.RepairPhone.BackCover.CFrame == shop.RepairPhone.BackCover:GetAttribute("DPU_DeviceLoose"),
	"cover removal replicates"
)
puzzles.Input(devicePuzzle, 11, devicePuzzle.Revision, h.time)
moveDevice()
check(
	shop.RepairPhone.Battery.CFrame == shop.RepairPhone.Battery:GetAttribute("DPU_DeviceLoose"),
	"battery removal replicates before diagnosis"
)
check(
	shop.RepairPhone2.Battery.CFrame == shop.RepairPhone2.Battery:GetAttribute("DPU_DeviceHome"),
	"other bench remains assembled"
)
world.devices:Update("RepairPhone", { order = nil })
for _, tween in pairs(world.devices.views.RepairPhone.tweens) do
	tween:Finish()
end
check(
	sourceDevice.Phone.CFrame == sourcePose
		and shop.RepairPhone.Battery.CFrame == shop.RepairPhone.Battery:GetAttribute("DPU_DeviceHome"),
	"clearing order restores runtime parts without editing source"
)

for index, fault in ipairs({ "Battery", "Keypad", "Speaker" }) do
	check(
		world.stations["Part_" .. fault] == parts[index] and Scene.Station(shop, "Part_" .. fault) == parts[index],
		"both runtimes resolve relocated " .. fault
	)
	check(
		parts[index]:GetAttribute("DPU_Direct") == "Part_" .. fault and Scene.StockBox(parts[index]) == boxes[index],
		"physical pickup retains logical server action"
	)
end
local player = h:player(1)
player.Character = node("Model", "Character", ws)
local root, head = node("Part", "HumanoidRootPart", player.Character), node("Part", "Head", player.Character)
root.Position, head.Position = Roblox.Vector3.new(2, 3, 402), Roblox.Vector3.new(2, 4, 402)
local hum = node("Humanoid", "Humanoid", player.Character)
hum.Health, hum.Sit = 100, false
local run = h:load("src/GServer/Session/ShiftService.luau").new({
	ready = function()
		return true
	end,
	present = function()
		return true
	end,
	clock = function()
		return h.time
	end,
}, config)
run.phase, run.id, run.policy = "Tutorial", "storage_run", { Text = "Today's directive" }
run.players[player] = { Alive = true, ClockedIn = true, Acknowledged = true }
world:Render(run)
local fax, handset = shop.Fax, shop.Fax.Phone
check(
	Scene.Telephone(ws) == fax and Scene.Station(shop, "Phone") == fax and world.stations.Answer == fax,
	"pickup, hazard, answer and objective targets all resolve to authored Fax"
)
check(
	not shop:FindFirstChild("DeskPhoneBase")
		and not shop:FindFirstChild("Receiver")
		and not shop:FindFirstChild("Phone"),
	"world starts with all three standalone phone props removed"
)
check(
	fax:GetAttribute("DPU_Direct") == "Fax"
		and fax:GetAttribute("DPU_Enabled")
		and handset:GetAttribute("DPU_Direct") == nil,
	"normal Fax handset falls through to model pickup interaction"
)
local home, headHome = root.Position, head.Position
root.Position, head.Position =
	fax.Base.Position + Roblox.Vector3.new(0, 0, 3), fax.Base.Position + Roblox.Vector3.new(0, 2, 3)
for _, name in ipairs({ "Fax", "Phone", "Answer" }) do
	check(world:Near(player, name), "relocated telephone permits " .. name .. " nearby")
	obstructed = true
	check(not world:Near(player, name), "walls block " .. name .. " at relocated telephone")
	obstructed = false
end
root.Position = fax.Base.Position + Roblox.Vector3.new(0, 0, 30)
check(not world:Near(player, "Phone") and not world:Near(player, "Answer"), "hazard actions cannot reach distant Fax")
root.Position, head.Position = home, headHome
run.event = { Id = "fax_call", Kind = "Call", EndsAt = h.time + 20 }
run.revision += 1
world:Render(run)
check(
	fax:GetAttribute("DPU_Direct") == "Phone"
		and fax:GetAttribute("DPU_Enabled")
		and handset:GetAttribute("DPU_Direct") == "Answer"
		and handset:GetAttribute("DPU_Enabled"),
	"ringing event switches Fax body to silence and handset to confirmed answer"
)
check(world:ActionFor(run, player, "Phone") == "Silence" and not world.actions.Fax, "ringing blocks outgoing calls")
run.event = nil
run.revision += 1
world:Render(run)
check(
	fax:GetAttribute("DPU_Direct") == "Fax" and handset:GetAttribute("DPU_Direct") == nil,
	"resolved call restores normal pickup on every Fax surface"
)
check(
	crt:GetAttribute("DPU_Direct") == "CRT" and crt:GetAttribute("DPU_Enabled") and crt:GetAttribute("DPU_Range") == 8,
	"prototype binds new TV model as one enabled direct target"
)
check(
	world.storage and boxes[1]:GetAttribute("DPU_Enabled"),
	"prototype enables drawers through its existing world input"
)
check(
	not world.actions.Secret_Directive and not world:Near(player, "Secret_Directive"),
	"missing notes cannot be offered or remotely discovered"
)
check(not world:Near(player, "Part_Battery"), "closed drawer blocks remote stock collection")
local Requests = h:load("src/GClient/Session/SessionRequests.luau")
local function request(index, revision)
	h.time += 0.2
	local _, payload = Requests.Payload({ RunId = run.id }, "ToggleStorage", {
		Station = "Storage_Box" .. index,
		Id = boxes[index]:GetAttribute("DPU_ContainerId"),
		Revision = revision or boxes[index]:GetAttribute("DPU_ContainerRevision"),
	})
	return world.storage:Request(player, payload, run), payload
end
local Interaction = h:load("src/GClient/Interaction/WorldInteractionController.luau")
local state = { Order = { Step = "Collect", Fault = "Battery" }, Stock = { Battery = 4 } }
check(not Interaction.CanHover({}, parts[1], state), "client refuses stock hover inside a closed drawer")
local sent
local input = setmetatable({
	state = state,
	d = {
		send = function(action, choice)
			sent = { action, choice }
		end,
	},
	Pick = function()
		return labels[1]
	end,
}, Interaction)
input:Activate()
check(
	sent[1] == "ToggleStorage"
		and sent[2].Station == "Storage_Box1"
		and sent[2].Id == boxes[1]:GetAttribute("DPU_ContainerId"),
	"label tap routes exactly one drawer identity through central input"
)
local opened, payload = request(1)
check(opened.Ok and payload.Id and payload.Revision == 0, "drawer request preserves server identity and revision")
check(
	tweens[boxes[1]].played and tweens[parts[1]].played and tweens[labels[1]].played,
	"box, pickup and label start together"
)
check(tweens[parts[1]].seconds == 0.35, "pickup uses matching drawer tween duration")
check(not world:Near(player, "Part_Battery"), "stock cannot be collected during drawer travel")
tweens[boxes[1]]:At(0.5)
tweens[parts[1]]:At(0.5)
check(
	(parts[1].CFrame.Position - originals[1].Position - Roblox.Vector3.new(0, 0, -0.4)).Magnitude < 0.001,
	"pickup follows midpoint of drawer slide"
)
tweens[boxes[1]]:Finish()
check(
	(parts[1].CFrame.Position - originals[1].Position - Roblox.Vector3.new(0, 0, -0.8)).Magnitude < 0.001,
	"pickup reaches drawer's open offset"
)
check(
	parts[1].CFrame.Rotation == originals[1].Rotation and parts[2].CFrame == originals[2],
	"authored rotation and other drawers stay unchanged"
)
check(world:Near(player, "Part_Battery"), "open relocated stock is reachable regardless of old room coordinates")
check(Interaction.CanHover({}, parts[1], state), "client accepts open stock surface for the correct order")
obstructed = true
check(not world:Near(player, "Part_Battery"), "actual walls still block stock requests")
check(not request(2).Ok, "actual walls also block drawer opening")
obstructed = false
check(request(1, 0).Code == "Changed", "stale drawer revision cannot toggle twice")
check(request(1).Ok, "drawer closes through same controller")
tweens[boxes[1]]:Finish()
check((parts[1].CFrame.Position - originals[1].Position).Magnitude < 0.001, "closing restores pickup position")
run.players[player].Alive = false
check(not request(1).Ok, "dead player cannot open drawer")
run.players[player].Alive = true
run.players[player].Acknowledged = false
check(not request(1).Ok, "rules gate preserved")
run.players[player].Acknowledged = true
-- Replicated drawer IDs are not sufficient to bypass shift admission.
local proto = setmetatable({ world = world, run = run }, h:load("src/GServer/Session/GameService.luau"))
local bad = table.clone(payload)
bad.RunId = "previous_shift"
check(proto:Request(player, "PrototypeAction", bad).Code == "ShiftChanged", "old run cannot mutate drawers")
run.Snapshot = function()
	return { RunId = run.id }
end
h.time += 0.2
payload.Revision = boxes[1]:GetAttribute("DPU_ContainerRevision")
check(
	proto:Request(player, "PrototypeAction", payload).Ok,
	"actual prototype request routes to validated drawer service"
)
parts[3].Anchored, parts[3].connected = false, { boxes[3] }
check(
	request(3).Ok and tweens[parts[3]] == nil and not parts[3].Anchored,
	"welded stock follows its drawer without competing tween or anchoring"
)
local interrupted = tweens[parts[1]]
tweens[parts[1]]:At(0.5)
world:Shutdown()
check(
	shop.RepairPhone == authoredAnchor and sourceDevice.Parent == storage.Assets.Devices,
	"shutdown removes runtime devices and restores authored placement anchors"
)
check(
	fax.Parent == shop
		and handset.Parent == fax
		and fax:GetAttribute("DPU_Direct") == nil
		and handset:GetAttribute("DPU_Direct") == nil,
	"shutdown preserves Fax and restores model and handset attributes"
)
check(
	crt.Parent == shop and crtScreen.Parent == crt and crt:GetAttribute("DPU_Direct") == nil,
	"shutdown preserves new CRT hierarchy and restores input attributes"
)
check(
	interrupted.cancelled and parts[1].CFrame == originals[1] and cabinet.Parent == shop,
	"shutdown restores moving pickup without deleting authored storage"
)
check(boxes[1]:GetAttribute("DPU_Direct") == nil, "shutdown restores temporary drawer input attributes")
-- Latest authored hierarchy has furniture, but no copied runtime device anchors.
for _, name in ipairs({ "RepairPhone", "RepairPhone2", "CounterPhone_Bench", "CounterPhone_Bench2" }) do
	shop:FindFirstChild(name):Destroy()
end
local building = node("Folder", "Building", shop)
local nestedLighting = node("Folder", "Lighting", building)
local lampCount = 0
for _, item in ipairs(shop:GetChildren()) do
	if item.Name == "CeilingLight" then
		item.Parent = nestedLighting
		lampCount += 1
	end
end
local World = h:load("src/GServer/World/WorldService.luau")
local fallback = World.new(services, config)
check(#fallback.lamps == lampCount and lampCount > 0, "nested Building.Lighting lamps remain controlled by blackout")
check(
	shop.RepairPhone and shop.RepairPhone2 and shop.CounterPhone_Bench and shop.CounterPhone_Bench2,
	"startup needs only furniture, not four obsolete phone anchors"
)
check(
	shop.RepairPhone.Phone.CFrame.Position.Y > shop.Bench.CFrame.Position.Y + shop.Bench.Size.Y / 2,
	"fallback phone sits above bench surface"
)
check(
	shop.CounterPhone_Bench.Phone.CFrame.Position ~= shop.CounterPhone_Bench2.Phone.CFrame.Position,
	"counter phones use separate positions"
)
root.Position = shop.Bench.CFrame.Position + Roblox.Vector3.new(0, 3, 0)
head.Position = root.Position + Roblox.Vector3.new(0, 1.5, 0)
check(fallback:Near(player, "Bench"), "visible bench surface is server reachable")
obstructed = true
check(not fallback:Near(player, "Bench"), "actual internal wall blocks repair requests even inside same room")
obstructed = false
local respawnPlayer = h:player(98)
local respawns = 0
respawnPlayer.LoadCharacterAsync = function()
	respawns += 1
end
fallback:Reset(respawnPlayer, true)
fallback:Reset(respawnPlayer, true)
h:drain()
check(respawns == 1, "concurrent reset requests schedule one respawn")
fallback:Reset(respawnPlayer, true)
fallback:Remove(respawnPlayer)
h:drain()
check(respawns == 1, "departure cancels queued respawn before character creation")
fallback:Shutdown()
check(
	not shop:FindFirstChild("RepairPhone") and shop.Bench.Parent == shop,
	"fallback teardown deletes only runtime phones, preserving furniture"
)
local mount = node("Attachment", "RepairPhoneMount", shop.Bench)
mount.WorldCFrame = Roblox.CFrame.new(9, 8, 7) * Roblox.CFrame.Angles(0, 0.7, 0)
local mounted = World.new(services, config)
check(
	(shop.RepairPhone.Phone.CFrame.Position - mount.WorldCFrame.Position).Magnitude < 0.001,
	"optional mount controls exact body placement"
)
mounted:Shutdown()
local camera = shop.Bench2.RepairCamera
camera.Parent = nil
local started = pcall(World.new, services, config)
check(
	not started and not shop:FindFirstChild("RepairPhone") and not shop:FindFirstChild("CounterPhone_Bench2"),
	"failed startup rolls back already-created phones"
)
check(
	shop.Fax:GetAttribute("DPU_Direct") == nil and boxes[1]:GetAttribute("DPU_Direct") == nil,
	"failed startup restores authored interaction attributes"
)
camera.Parent = shop.Bench2
local retried = World.new(services, config)
retried:Shutdown()
check(shop.Bench.Parent == shop, "corrected scene can start after a failed bind")
-- Failed cloning/validation never detaches authored anchors or changes the source's Archivable flag.
local anchor = node("Part", "RepairPhone", shop)
anchor.CFrame = Roblox.CFrame.new()
local Devices = h:load("src/GServer/Repair/DevicePresentation.luau")
local failedDevices = Devices.new(services, shop, sourceDevice)
local screw4 = sourceDevice.Screws.Screw4
screw4.Parent = nil
check(
	not pcall(failedDevices.Create, failedDevices, "RepairPhone", true)
		and anchor.Parent == shop
		and #failedDevices.copies == 0,
	"malformed phone preserves placement anchor"
)
screw4.Parent = sourceDevice.Screws
anchor:Destroy()
-- Direct input must retain station identity and bind the counter's actual customer.
local firstOrder, otherOrder = { Id = "first", Step = "Diagnose" }, { Id = "second", Step = "Waiting" }
local captured
local routingRun = {
	id = "routing",
	players = { [player] = { StationId = "Bench" } },
	stations = { Bench = { Id = "Bench", order = firstOrder }, Bench2 = { Id = "Bench2", order = otherOrder } },
	Snapshot = function()
		return {}
	end,
	Action = function(_, _, action, input)
		captured = { action, input }
		return true
	end,
}
local routingWorld = setmetatable({ direct = { Counter = true, Bench2 = true } }, World)
local routing = setmetatable({ world = routingWorld, run = routingRun }, h:load("src/GServer/Session/GameService.luau"))
local Requests = h:load("src/GClient/Session/SessionRequests.luau")
local _, input = Requests.Payload(
	{ RunId = "routing", Order = firstOrder, CounterOrderId = "second" },
	"Interact",
	{ Station = "Counter" }
)
check(
	input.OrderId == "second"
		and routing:Request(player, "PrototypeAction", input).Ok
		and captured[1] == "TakeOrder"
		and captured[2].OrderId == "second",
	"counter routes to other bench customer"
)
otherOrder.Id = "new-customer"
check(
	routing:Request(player, "PrototypeAction", input).Code == "InteractionChanged",
	"old counter gesture cannot accept a replacement customer"
)
local _, benchInput = Requests.Payload({ RunId = "routing", Order = firstOrder }, "Interact", { Station = "Bench2" })
check(
	routing:Request(player, "PrototypeAction", benchInput).Ok
		and captured[1] == "SelectStation"
		and captured[2].Station == "Bench2",
	"direct bench interaction retains station identifier"
)

print(string.format("PASS: %d authored storage, deleted-note, drawer and stock checks (mocked Roblox).", total))
