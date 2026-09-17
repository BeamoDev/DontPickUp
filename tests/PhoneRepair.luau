local Harness = require("./Harness")
local Fixture = require("./TagFixture")
local Roblox = require("@lune/roblox")
local h, total = Harness.Environment(), 0
local function check(value, label)
	assert(value, label)
	total += 1
end
for _, name in ipairs({ "Vector3", "Vector2", "CFrame", "Color3", "UDim2" }) do
	h.env[name] = Roblox[name]
end
h.env.Enum, h.env.RaycastParams = Roblox.Enum, {
	new = function()
		return {}
	end,
}
local world, collection = h.instance("Workspace"), Fixture.Collection()
local function node(class, name, parent, position, size)
	local item = h.instance(class)
	item.Name, item.Parent = name, parent
	item.AncestryChanged, item.Destroying = Fixture.Signal(), Fixture.Signal()
	if class == "Part" then
		item.CFrame, item.Position = Roblox.CFrame.new(position or Roblox.Vector3.zero), position or Roblox.Vector3.zero
		item.Size, item.Transparency = size or Roblox.Vector3.new(0.1, 0.1, 0.1), 0
		item.Anchored, item.CanCollide, item.CanQuery, item.CanTouch = true, true, true, true
		item.GetConnectedParts = function()
			return item.connected or {}
		end
	end
	return item
end
local phone = node("Model", "Phone", world)
local center = Roblox.Vector3.new(0, 3, 0)
phone.GetBoundingBox = function()
	return Roblox.CFrame.new(center), Roblox.Vector3.new(2, 3, 0.6)
end
phone.GetPivot = function()
	return Roblox.CFrame.new(center)
end
local body = node("Part", "Phone", phone, center, Roblox.Vector3.new(2, 3, 0.4))
local screen = node("Part", "Screen", phone, center + Roblox.Vector3.new(0, 0.5, -0.25))
local cover = node("Part", "BackCover", phone, center + Roblox.Vector3.new(0, 0, 0.3))
local battery = node("Part", "Battery", phone, center + Roblox.Vector3.new(0, -0.4, 0.2))
local screws, pipes, wires =
	node("Folder", "Screws", phone), node("Folder", "Pipes", phone), node("Folder", "Wires", phone)
for index = 1, 4 do
	node(
		"Part",
		"Screw" .. index,
		screws,
		center + Roblox.Vector3.new(index % 2 == 0 and 0.8 or -0.8, index <= 2 and 1.2 or -1.2, 0.35)
	)
	node("Part", "EntryPoint" .. index, pipes, center + Roblox.Vector3.new(-0.5, 0.7 - index * 0.25, 0.25))
	node("Part", "ExitPoint" .. index, pipes, center + Roblox.Vector3.new(0.5, 0.7 - index * 0.25, 0.25))
end
for _, name in ipairs({ "Red", "Yellow", "Blue", "Pink" }) do
	local wire = node("Part", name, wires, center)
	wire.Transparency = 1
	wire.Color = ({
		Red = Roblox.Color3.fromRGB(220, 40, 40),
		Yellow = Roblox.Color3.fromRGB(240, 210, 40),
		Blue = Roblox.Color3.fromRGB(40, 90, 220),
		Pink = Roblox.Color3.fromRGB(240, 100, 170),
	})[name]
end
local weld = node("WeldConstraint", "AuthoredWeld", body)
weld.Enabled, weld.Part0, weld.Part1 = true, body, cover
local player, other = h:player(1), h:player(2)
player.Character = node("Model", "Character", world)
local root = node("Part", "HumanoidRootPart", player.Character, center + Roblox.Vector3.new(0, 0, -4))
local head = node("Part", "Head", player.Character, root.Position + Roblox.Vector3.yAxis * 2)
local humanoid = node("Humanoid", "Humanoid", player.Character)
humanoid.Health, humanoid.Sit = 100, false
other.Character = player.Character
collection:AddTag(phone, "PhoneRepair")
local blocked, ready = false, true
local wall = node("Part", "Wall", world)
world.Raycast = function()
	return blocked and { Instance = wall, Position = wall.Position } or nil
end
local services = {
	Workspace = world,
	CollectionService = collection,
	Players = h.players,
	RunService = { Heartbeat = Fixture.Signal() },
	HttpService = {
		GenerateGUID = function()
			h.serial += 1
			return "repair-" .. h.serial
		end,
	},
}
local service = h:load("src/GServer/Repair/PhoneRepairService.luau").new(services, function()
	return ready
end)
local definition = h:load("src/GShared/Repair/RepairDefinition.luau")
local rigModule = h:load("src/GShared/Repair/RepairRig.luau")
service:Add(phone)
local function begin(who)
	return service:Request(who or player, "BeginRepair", { Id = phone:GetAttribute("DPU_RepairId") })
end
local function tick(seconds)
	h.time += seconds
	service:Tick(seconds)
end
local function cancel(token)
	return service:Request(player, "CancelRepair", { Token = token })
end
local function grab(token, key, revision)
	return service:Request(player, "RepairGrab", { Token = token, Key = key, Revision = revision })
end
local function drop(token, revision, slot)
	local motion = service.sessions[player].motion
	local p = motion.plane:PointToObjectSpace(slot.Position)
	return service:Request(
		player,
		"RepairDrop",
		{ Token = token, Revision = revision, X = p.X / motion.half.X, Y = p.Z / motion.half.Y }
	)
end
check(
	definition.Pair("ExitPoint4").To == "EntryPoint1" and definition.Pair("ExitPoint4").Wire == "Red",
	"owner Red mapping"
)
check(
	definition.Pair("ExitPoint3").Wire == "Yellow"
		and definition.Pair("ExitPoint2").Wire == "Blue"
		and definition.Pair("ExitPoint1").Wire == "Pink",
	"remaining owner mappings"
)
check(not definition.Point(Roblox.CFrame.new(), Roblox.Vector2.one, 0 / 0, 0), "NaN drag rejected")
local saved = body.CFrame
blocked = true
check(not begin().Ok, "walls block repair reservation")
blocked = false
ready = false
check(not begin().Ok, "profile eligibility required")
ready = true
body.connected = { root }
check(begin().Code == "ExternallyWelded", "never detach phone from outside scenery")
body.connected = nil
battery.Name = "MissingBattery"
check(not rigModule.Read(phone), "malformed authored hierarchy rejected")
battery.Name = "Battery"
local reply = begin()
check(
	reply.Ok and phone:GetAttribute("DPU_RepairOwner") == player.UserId and not weld.Enabled,
	"reserve world model and temporarily disable internal weld"
)
check(not begin(other).Ok, "second player cannot reserve same phone")
check(not grab(reply.Token, "Battery", 0).Ok, "cannot skip disassembly")
tick(0.7)
check(body.CFrame ~= saved, "phone pickup animates the shared world model")
local session = service.sessions[player]
for _, elapsed in ipairs({ 0.7, 1.35, 3.9 }) do
	session.motion:Advance(elapsed)
	local relative = body.CFrame:ToObjectSpace(screen.CFrame)
	local original = session.motion.saved[body].frame:ToObjectSpace(session.motion.saved[screen].frame)
	check(
		(relative.Position - original.Position).Magnitude < 0.0001,
		"body and screen stay rigid throughout lift, flip and layout"
	)
end
session.motion:Advance(1.69)
local turned = screen.CFrame.Position - cover.CFrame.Position
check(turned.Z > 0, "phone turns 180 degrees to expose its back")
session.motion:Advance(2.64)
check(screws.Screw1.Transparency > 0.99, "removed screws fade fully away")
tick(4)
check(
	phone:GetAttribute("DPU_RepairStage") == "Wires" and screws.Screw1.Transparency == 0,
	"table layout exposes draggable screws again"
)
check(
	wires.Red.Transparency == 1 and cover.CFrame ~= session.motion.slots.BackCover,
	"wires stay hidden with cover set aside"
)
check(not grab(reply.Token, "Battery", 0).Ok, "battery blocked until every wire is connected")
local originalRaycast = world.Raycast
local socket = session.motion.slots.EntryPoint1.Position
world.Raycast = function(_, origin, direction)
	-- A desk edge only occludes the old direct head-to-socket diagonal.
	if (origin - head.Position).Magnitude < 0.001 and (origin + direction - socket).Magnitude < 0.001 then
		return { Instance = wall, Position = socket }
	end
	return nil
end
check(service:WorkVisible(session, head, socket), "clear overhead access is not rejected by desk-edge diagonal")
world.Raycast = function()
	return { Instance = wall, Position = socket }
end
check(not service:WorkVisible(session, head, socket), "solid obstruction still blocks inspection access")
world.Raycast = originalRaycast

local wrong = grab(reply.Token, "ExitPoint4", 0)
tick(0.12)
check(
	not drop(wrong.Token, 0, session.motion.slots.EntryPoint2).Ok and wires.Red.Transparency == 1,
	"wrong wire endpoint never reveals a wire"
)
for index, pair in ipairs(definition.Pairs) do
	local drag = grab(reply.Token, pair.From, index - 1)
	check(drag.Ok, "correct unfinished wire can drag")
	tick(0.12)
	local accepted = drop(drag.Token, index - 1, session.motion.slots[pair.To])
	check(accepted.Ok and wires[pair.Wire].Transparency == 0, "correct pair reveals exactly its real authored wire")
	check(not drop(drag.Token, index - 1, session.motion.slots[pair.To]).Ok, "duplicate drop cannot advance progress")
end
check(phone:GetAttribute("DPU_RepairStage") == "Battery", "all four wires unlock battery")
check(not grab(reply.Token, "BackCover", 4).Ok, "cover cannot precede battery")
local drag = grab(reply.Token, "Battery", 4)
local beforeDrag = battery.CFrame
service:Drag(other, drag.Token, 0.5, 0.5)
check(not session.drag.pending, "another player cannot move held repair part")
service:Drag(player, "stale", 0.5, 0.5)
check(not session.drag.pending, "stale drag token rejected")
service:Drag(player, drag.Token, 5, 0)
check(not session.drag.pending, "drag cannot leave server-chosen plane bounds")
service:Drag(player, drag.Token, 0.4, 0.5)
tick(0.12)
check(battery.CFrame ~= beforeDrag, "battery drag updates replicated world part")
check(drop(drag.Token, 4, session.motion.slots.Battery).Ok, "battery slots into correct position")
check(not grab(reply.Token, "BackCover", 5).Ok, "installation tween owns the part until completion")
tick(0.5)
local revision = 5
for _, key in ipairs({ "BackCover", "Screw3", "Screw1", "Screw4", "Screw2" }) do
	local item = grab(reply.Token, key, revision)
	check(item.Ok, "reassembly accepts next part in required stage")
	tick(0.12)
	check(drop(item.Token, revision, session.motion.slots[key]).Ok, "reassembly accepts correct slot")
	revision += 1
	tick(0.5)
end
tick(0.7)
check(
	phone:GetAttribute("DPU_RepairStage") == "Complete" and body.CFrame == saved and weld.Enabled,
	"finished phone restored to table with authored weld"
)
check(
	wires.Red.Transparency == 0 and not service.sessions[player] and not service.heartbeat,
	"completed wires remain visible and idle loop disconnects"
)
check(not begin().Ok, "finished model cannot award or replay another completion")
service:Drop(phone)
service:Add(phone)
local restart = begin()
tick(0.6)
humanoid.Health = 0
tick(0.1)
check(not service.sessions[player] and body.CFrame == saved and weld.Enabled, "death cancels and restores assembly")
humanoid.Health = 100
restart = begin()
tick(0.6)
service:Drop(phone)
check(
	not service.sessions[player] and body.CFrame == saved and not phone:GetAttribute("DPU_RepairId"),
	"tag/unbind cleanup restores model and clears identity"
)
service:Add(phone)
restart = begin()
tick(181)
check(not service.sessions[player] and weld.Enabled, "lost client bounded by session timeout")
service:Shutdown()
-- Exercise the real client controller and drag adapter against the real service.
service = h:load("src/GServer/Repair/PhoneRepairService.luau").new(services, function()
	return ready
end)
service:Add(phone)
player.Character.DescendantAdded = Fixture.Signal()
humanoid.AutoRotate, root.Anchored = true, false
for _, part in ipairs(player.Character:GetDescendants()) do
	if part:IsA("BasePart") then
		part.LocalTransparencyModifier = 0
	end
end
local preferred = { KeyboardAndMouse = "Mouse", Touch = "Touch", Gamepad = "Gamepad" }
h.env.Enum = setmetatable({ PreferredInput = preferred }, {
	__index = function(_, key)
		return Roblox.Enum[key]
	end,
})
local input = {
	PreferredInput = preferred.Touch,
	GetFocusedTextBox = function()
		return nil
	end,
}
local pointer = Roblox.Vector2.new(400, 300)
input.GetMouseLocation = function()
	return pointer
end
local camera = {
	CFrame = Roblox.CFrame.new(0, 6, -5),
	Focus = Roblox.CFrame.new(center),
	FieldOfView = 70,
	ViewportSize = Roblox.Vector2.new(800, 600),
	CameraType = Roblox.Enum.CameraType.Custom,
	CameraSubject = humanoid,
}
world.CurrentCamera = camera
local function plane()
	local s = service.sessions[player]
	return s and s.motion.plane or Roblox.CFrame.new()
end
function camera:WorldToViewportPoint(point)
	local v = plane():PointToObjectSpace(point)
	return Roblox.Vector3.new(400 + v.X * 80, 300 + v.Z * 80, 10), true
end
function camera:ViewportPointToRay(x, y)
	return {
		Origin = plane():PointToWorldSpace(Roblox.Vector3.new((x - 400) / 80, 10, (y - 300) / 80)),
		Direction = -Roblox.Vector3.yAxis,
	}
end
local gui = node("ScreenGui", "RepairGui", world)
local selection = { Set = function() end }
local ui, active, relocked = false, false, false
local requests = {}
local function syncPositions()
	for _, part in ipairs(phone:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Position = part.CFrame.Position
		end
	end
end
local remote = {
	InvokeServer = function(_, action, payload)
		table.insert(requests, action)
		local result = service:Request(player, action, payload)
		syncPositions()
		return result
	end,
}
local controller = h:load("src/GClient/Repair/PhoneRepairController.luau").new({
	player = player,
	input = input,
	workspace = world,
	collection = collection,
	selection = selection,
	gui = gui,
	render = { RenderStepped = Fixture.Signal() },
	reduced = function()
		return true
	end,
	blocked = function()
		return false
	end,
	uiBlocked = function()
		return ui
	end,
	remote = remote,
	move = {
		FireServer = function(_, token, x, y)
			service:Drag(player, token, x, y)
		end,
	},
	returning = function(value)
		relocked = value or relocked
	end,
	active = function(value)
		active = value
	end,
})
local cameraHome = camera.CFrame
controller:Open(phone)
h:drain()
check(active and root.Anchored and controller:Busy(), "repair enters shared inspection camera with character frozen")
tick(5)
syncPositions()
controller:Update(1 / 60)
check(
	controller:Ready() and controller.workView and controller.viewMode == "Wires",
	"wire stage selects the close-up camera"
)
local views = h:load("src/GClient/Repair/RepairViewConfig.luau")
local inspectionFrame = h:load("src/GClient/Camera/InspectionFrame.luau")
for _, viewport in ipairs({ Roblox.Vector2.new(1920, 1080), Roblox.Vector2.new(390, 844), Roblox.Vector2.new(844, 390) }) do
	local frame, focus, fov = views.Frame(controller.wiringView, viewport)
	local tangent = math.tan(math.rad(fov / 2))
	for key, slot in pairs(controller.session.reply.Slots) do
		if key:match("Point") then
			local p = frame:PointToObjectSpace(slot.Position)
			check(
				p.Z < 0
					and math.abs(p.X / -p.Z) < tangent * viewport.X / viewport.Y * 0.8
					and math.abs(p.Y / -p.Z) < tangent * 0.7,
				"all wire endpoints fit within the close-up safe area"
			)
		end
	end
	local work = controller.session.reply.Work
	local wideFrame, wideFocus =
		inspectionFrame(work.Pivot, work.Bounds, work.Size, viewport, Roblox.Vector3.new(0, 5, 2.5), 45)
	check(
		(frame.Position - focus.Position).Magnitude < (wideFrame.Position - wideFocus.Position).Magnitude * 0.5,
		"wiring camera stays close on desktop and phone aspect ratios"
	)
end
local wireFrame = camera.CFrame
controller:Update(1 / 60)
check(camera.CFrame == wireFrame, "unchanged repair stage does not restart camera transition")
input.PreferredInput = preferred.Gamepad
controller:InputChanged({ KeyCode = Roblox.Enum.KeyCode.Thumbstick1, Position = Roblox.Vector3.xAxis })
controller:Update(0.1)
humanoid.MoveDirection = Roblox.Vector3.xAxis
controller.camera:Check()
check(
	controller:Busy() and controller.drag.cursor.Visible and controller.drag.pad.X > 400,
	"gamepad stick moves visible repair cursor without exiting anchored inspection"
)
humanoid.MoveDirection = Roblox.Vector3.zero
input.PreferredInput = preferred.Touch
local function at(part)
	local point = camera:WorldToViewportPoint(part.Position)
	return Roblox.Vector3.new(point.X, point.Y, 0)
end
local touch = { UserInputType = Roblox.Enum.UserInputType.Touch, Position = at(pipes.ExitPoint4) }
ui = true
controller:InputBegan(touch, false)
check(not controller.drag.gesture, "repair dragging cannot start through UI")
ui = false
controller:InputBegan(touch, false)
h:drain()
check(controller.drag.gesture and controller.drag.gesture.token, "touch begins a token-scoped wire drag")
check(controller.drag.line.BackgroundColor3 == wires.Red.Color, "preview uses actual authored wire colour")
local wrongSocket = at(pipes.EntryPoint2)
check(
	controller.drag:WireDrop(Roblox.Vector2.new(wrongSocket.X, wrongSocket.Y)) == nil,
	"nearby wrong socket cannot magnetise into the correct wire"
)
local startPointer = touch.Position
for _, offset in ipairs({
	Roblox.Vector3.new(40, 30, 0),
	Roblox.Vector3.new(-40, 30, 0),
	Roblox.Vector3.new(-40, -30, 0),
	Roblox.Vector3.new(40, -30, 0),
}) do
	touch.Position = startPointer + offset
	controller:Update(1 / 60)
	local line = controller.drag.line
	local radians = math.rad(line.Rotation)
	local direction = Roblox.Vector2.new(math.cos(radians), math.sin(radians)) * line.Size.X.Offset / 2
	local middle = Roblox.Vector2.new(line.Position.X.Offset, line.Position.Y.Offset)
	check(
		(middle - direction - Roblox.Vector2.new(startPointer.X, startPointer.Y)).Magnitude < 0.001,
		"rotated wire stays attached to actual drag start in every direction"
	)
	check(
		(middle + direction - Roblox.Vector2.new(touch.Position.X, touch.Position.Y)).Magnitude < 0.001
			and line.Size.Y.Offset == 8,
		"thick preview ends exactly at pointer without rotation offset"
	)
	local _, _, point = controller.drag:Coordinates(Roblox.Vector2.new(touch.Position.X, touch.Position.Y))
	check(math.abs(point.Y - controller.drag.gesture.startWorld.Y) < 0.001, "wire drag remains on its starting world Y")
end
controller:Update(1 / 60)
check(
	controller.drag.line.Visible and controller.drag.target.Text == "EntryPoint1",
	"drag previews wire and its owner-specified endpoint"
)
-- A release just inside the socket hit area snaps to its exact installed
-- centre, even when grab/drop requests arrive together after network delay.
touch.Position = at(pipes.EntryPoint1) + Roblox.Vector3.new(5, 0, 0)
controller:InputEnded(touch, false)
h:drain()
check(
	wires.Red.Transparency == 0 and controller.session.revision == 1 and not controller.drag.gesture,
	"one touch drop connects correct wire once"
)
local count = #requests
controller:InputEnded(touch, false)
h:drain()
check(#requests == count, "duplicate release never duplicates a repair request")
touch = { UserInputType = Roblox.Enum.UserInputType.Touch, Position = at(pipes.ExitPoint3) }
controller:InputBegan(touch, false)
controller:InputBegan({ UserInputType = Roblox.Enum.UserInputType.Touch, Position = at(pipes.ExitPoint2) }, false)
h:drain()
check(not controller.drag.gesture and not service.sessions[player].drag, "second finger cancels even before grab reply")
for _, pair in ipairs(definition.Pairs) do
	if pair.Wire ~= "Red" then
		local activeSession = controller.session
		local g = grab(activeSession.token, pair.From, activeSession.revision)
		tick(0.12)
		local result = drop(g.Token, activeSession.revision, service.sessions[player].motion.slots[pair.To])
		activeSession.revision = result.Revision
	end
end
controller:Update(1 / 60)
check(
	controller.viewMode == "Assembly" and camera.CFrame ~= wireFrame and camera.FieldOfView == 45,
	"completing wires tweens back out to the loose assembly parts"
)
controller:Close()
h:drain()
check(
	not service.sessions[player]
		and not root.Anchored
		and humanoid.AutoRotate
		and camera.CFrame == cameraHome
		and relocked,
	"closing repair restores model, camera, movement and immediate relock"
)
controller:Open(phone)
controller:Close()
h:drain()
check(not service.sessions[player] and not controller:Busy(), "late Begin reply is cancelled after close")
controller:Destroy()
service:Shutdown()
-- Real central registration must reserve repair independently of throw/fax tags.
local central = h:load("src/GServer/Interaction/InteractionService.luau").new(services, function()
	return true
end)
local registered = phone:GetAttribute("DPU_RepairId")
check(type(registered) == "string", "central tag bindings register authored repair model")
local owned = central:Request(player, "BeginRepair", { Id = registered })
check(
	owned.Ok and central:Request(player, "GrabThrow", {}).Code == "RepairInProgress",
	"repair reservation prevents concurrent grabbing or drinking"
)
collection:RemoveTag(phone, "PhoneRepair")
check(
	not central.repairs.sessions[player] and phone:GetAttribute("DPU_RepairId") == nil,
	"actual tag-removal signal cancels repair and invalidates runtime identity"
)
central:Shutdown()
print(string.format("PASS: %d phone repair animation, assembly, input and authority checks (mocked Roblox).", total))
