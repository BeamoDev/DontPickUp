local Harness = require("./Harness")
local Roblox = require("@lune/roblox")
local fs = require("@lune/fs")
local collection = require("./TagFixture").Collection()
local h, total = Harness.Environment(), 0
local function check(value, message)
	assert(value, message)
	total += 1
end
local function signal()
	local listeners = {}
	return {
		Connect = function(_, fn)
			local connection = { Connected = true }
			function connection:Disconnect()
				self.Connected = false
			end
			table.insert(listeners, { connection, fn })
			return connection
		end,
		Fire = function(_, ...)
			for _, listener in ipairs(listeners) do
				if listener[1].Connected then
					listener[2](...)
				end
			end
		end,
	}
end
for _, name in ipairs({ "Vector3", "Vector2", "CFrame" }) do
	h.env[name] = Roblox[name]
end
-- This Lune build's reflection predates PreferredInput.
local preferred = { KeyboardAndMouse = "KeyboardAndMouse", Touch = "Touch", Gamepad = "Gamepad" }
h.env.Enum = setmetatable({ PreferredInput = preferred }, {
	__index = function(_, key)
		return Roblox.Enum[key]
	end,
})
h.env.RaycastParams = {
	new = function()
		return {}
	end,
}
h.env.TweenInfo = {
	new = function()
		return {}
	end,
}
local world, folder = h.instance("Workspace"), h.instance("Model")
world.ChildAdded, world.ChildRemoved = signal(), signal()
folder.Name, folder.Parent = "ComponentBoxes", world
collection:AddTag(folder, "Container")
folder.ChildAdded, folder.ChildRemoved = signal(), signal()
local function box(name, position)
	local part = h.instance("Part")
	part.Name, part.CFrame, part.Position = name, Roblox.CFrame.new(position), position
	part.Size = Roblox.Vector3.new(2, 1, 2)
	part.Anchored, part.CanQuery, part.Parent = true, true, folder
	return part
end
local a = box("Box1", Roblox.Vector3.new(14.317, 0.22, 34.989))
local b = box("Box2", Roblox.Vector3.new(20, 0.22, 34.989))
local cover = box("Covers", Roblox.Vector3.new(14, 2, 35))
local lastTween
local services = {
	Workspace = world,
	Players = h.players,
	HttpService = {
		GenerateGUID = function()
			h.serial += 1
			return "box-" .. h.serial
		end,
	},
	TweenService = {
		Create = function(_, target, _, goal)
			local tween = {
				Completed = signal(),
				Play = function() end,
				Cancel = function(self)
					self.cancelled = true
				end,
			}
			function tween:Finish()
				if self.cancelled then
					return
				end
				target.CFrame, target.Position = goal.CFrame, goal.CFrame.Position
				self.Completed:Fire()
			end
			lastTween = tween
			return tween
		end,
	},
}
local ready, obstruction = true, nil
world.Raycast = function()
	return obstruction and { Instance = obstruction } or nil
end
local containers = h:load("src/GServer/Containers/ContainerService.luau").new(services, function()
	return ready
end)
containers:Bind(folder)
local player = h:player(1)
player.Character, player.CharacterAdded = h.instance("Model"), signal()
local humanoid, root, head = h.instance("Humanoid"), h.instance("Part"), h.instance("Part")
humanoid.Health, humanoid.Sit, humanoid.Parent = 100, false, player.Character
root.Name, root.Position, root.Parent = "HumanoidRootPart", Roblox.Vector3.new(14, 1, 31), player.Character
head.Name, head.Position, head.Parent = "Head", Roblox.Vector3.new(14, 3, 31), player.Character
local function request(part, revision, id)
	h.time += 0.2
	return containers:Request(player, {
		Id = id or part:GetAttribute("DPU_ContainerId"),
		Revision = revision or part:GetAttribute("DPU_ContainerRevision"),
	})
end
check(
	a:GetAttribute("DPU_ContainerId") ~= nil and cover:GetAttribute("DPU_ContainerId") == nil,
	"only Box parts register"
)
ready = false
check(request(a).Code == "NotReady", "unadmitted/unready rejected")
ready = true
obstruction = cover
check(request(a).Code == "Blocked", "wall blocks interaction")
obstruction = nil
local visibilityRays = 0
world.Raycast = function()
	visibilityRays += 1
	return { Instance = visibilityRays == 1 and cover or a }
end
check(
	containers:Visible(player.Character, head, a) and visibilityRays == 2,
	"visible drawer front works when lid blocks center"
)
world.Raycast = function()
	return obstruction and { Instance = obstruction } or nil
end
local nearby = root.Position
root.Position = Roblox.Vector3.zero
check(request(a).Code == "TooFar", "far clicks rejected")
root.Position = nearby
humanoid.Health = 0
check(request(a).Code == "Unavailable", "dead player rejected")
humanoid.Health, humanoid.Sit = 100, true
check(request(a).Code == "Unavailable", "seated player rejected")
humanoid.Sit = false
check(request(a, nil, "fake").Code == "Unavailable", "invented identity rejected")
local closed = a.CFrame
check(request(a).Ok, "click starts opening")
local teammate = h:player(2)
teammate.Character = player.Character
check(
	containers:Request(teammate, { Id = a:GetAttribute("DPU_ContainerId"), Revision = 0 }).Code == "Changed",
	"simultaneous old revision cannot reverse open"
)
check(request(a).Code == "PleaseWait", "transition reserves box")
lastTween:Finish()
check((a.Position - Roblox.Vector3.new(14.317, 0.22, 34.189)).Magnitude < 0.001, "exact requested open position")
check(request(a).Ok, "next click closes")
lastTween:Finish()
check((a.Position - closed.Position).Magnitude < 0.001, "close returns to original position")
check(request(b).Ok, "second box opens independently")
lastTween:Finish()
check(
	(b.Position - Roblox.Vector3.new(20, 0.22, 34.189)).Magnitude < 0.001,
	"other box keeps own X/Y and same Z difference"
)
check((a.Position - closed.Position).Magnitude < 0.001, "other box does not move first box")
check(request(a).Ok, "reopening works")
local cancelled, oldId = lastTween, a:GetAttribute("DPU_ContainerId")
folder.ChildRemoved:Fire(a)
check(cancelled.cancelled and a:GetAttribute("DPU_ContainerId") == nil, "removal cancels tween and clears attributes")
folder.ChildAdded:Fire(a)
check(
	a:GetAttribute("DPU_ContainerId") ~= oldId and request(a, 0, oldId).Code == "Unavailable",
	"readded box rejects obsolete identity"
)

-- Exercise the real client adapter and authored highlight clone with mocked input.
local input = {
	InputBegan = signal(),
	InputEnded = signal(),
	WindowFocusReleased = signal(),
	WindowFocused = signal(),
	PreferredInput = preferred.KeyboardAndMouse,
	GetFocusedTextBox = function()
		return nil
	end,
	GetMouseLocation = function()
		return Roblox.Vector2.new(125, 250)
	end,
}
local rayKind, target, calls, locked = nil, a, {}, true
local camera = {
	ViewportSize = Roblox.Vector2.new(800, 600),
	CameraType = Roblox.Enum.CameraType.Custom,
	CFrame = Roblox.CFrame.new(0, 10, 0),
	Focus = Roblox.CFrame.new(),
	FieldOfView = 70,
	CameraSubject = humanoid,
}
function camera:ScreenPointToRay()
	rayKind = "screen"
	return { Origin = Roblox.Vector3.zero, Direction = Roblox.Vector3.zAxis }
end
function camera:ViewportPointToRay()
	rayKind = "center"
	return { Origin = Roblox.Vector3.zero, Direction = Roblox.Vector3.zAxis }
end
world.CurrentCamera = camera
world.Raycast = function()
	return target and { Instance = target } or nil
end
local template = h.instance("Highlight")
template.Name, template.FillTransparency, template.Enabled = "SelectionHighlight", 0.73, false
local blocked, hover = false, false
local config = h:load("src/GShared/Containers/ContainerConfig.luau")
local origin, size = Roblox.CFrame.new(17, 1, 35), Roblox.Vector3.new(8, 2, 3)
folder.GetPivot = function()
	return origin
end
folder.GetBoundingBox = function()
	return origin, size
end
player.Character.DescendantAdded = signal()
humanoid.MoveDirection = Roblox.Vector3.zero
root.LocalTransparencyModifier, head.LocalTransparencyModifier = 0.4, 0
local render = { RenderStepped = signal() }
local cameraTween, active, reduced = nil, false, false
local inspection = h:load("src/GClient/Interactions/ModelInspection.luau").new({
	player = player,
	input = input,
	workspace = world,
	config = config,
	render = render,
	blocked = function()
		return blocked
	end,
	reduced = function()
		return reduced
	end,
	active = function(value)
		active = value
	end,
	tweens = {
		Create = function(_, object, _, goal)
			local tween = { Completed = signal(), Play = function() end }
			function tween:Cancel()
				self.cancelled = true
			end
			function tween:Finish()
				if self.cancelled then
					return
				end
				for key, value in pairs(goal) do
					object[key] = value
				end
				self.Completed:Fire()
			end
			cameraTween = tween
			return tween
		end,
	},
})
local savedFrame = camera.CFrame
local client = h:load("src/GClient/Interactions/TaggedInteraction.luau").new({
	collection = collection,
	player = player,
	input = input,
	workspace = world,
	config = config,
	inspection = inspection,
	template = function()
		return template
	end,
	remote = {
		InvokeServer = function(_, action, payload)
			table.insert(calls, { action, payload })
			return { Ok = true }
		end,
	},
	locked = function()
		return locked
	end,
	blocked = function()
		return blocked
	end,
	hover = function(value)
		hover = value
	end,
})
client:Update()
check(rayKind == "center" and hover, "locked aim uses center ray")
check(
	client.highlight ~= template and client.highlight.Parent == folder and client.highlight.Adornee == folder,
	"idle hover highlights the whole model before any drawer"
)
check(
	client.highlight.FillTransparency == 0.73 and not template.Enabled and template.Parent == nil,
	"template styling preserved without editing original"
)
target = nil
client:Update()
check(client.highlight.Parent == nil and not client.highlight.Enabled and not hover, "leaving box removes highlight")
target, locked = a, false
client:Update()
check(rayKind == "screen", "unlocked mouse follows pointer")
local function press(kind)
	local event = { UserInputType = kind, Position = Roblox.Vector3.new(100, 100, 0) }
	input.InputBegan:Fire(event, false)
	return event
end
local event = press(Roblox.Enum.UserInputType.Touch)
event.Position = Roblox.Vector3.new(150, 100, 0)
input.InputEnded:Fire(event, false)
h:drain()
check(#calls == 0, "touch camera drag is not click")
target = cover
press(Roblox.Enum.UserInputType.MouseButton1)
h:drain()
check(#calls == 0 and active and inspection.entering, "first click on cover opens model inspection without a toggle")
check(
	camera.CameraType == Roblox.Enum.CameraType.Scriptable and root.LocalTransparencyModifier == 1,
	"inspection owns camera and hides local avatar"
)
target = a
press(Roblox.Enum.UserInputType.MouseButton1)
h:drain()
check(#calls == 0, "entry animation blocks accidental drawer clicks")
cameraTween:Finish()
client:Update()
check(client.highlight.Parent == a, "inside inspection hover now targets individual drawer")
local framed = camera.CFrame
check(
	framed.LookVector:Dot((camera.Focus.Position - framed.Position).Unit) > 0.999,
	"container camera aims at entire set"
)
check(
	framed.Position.Y > origin.Position.Y and framed.Position.Z < origin.Position.Z,
	"camera sits above the opening side"
)
locked = true
client:Update()
check(rayKind == "screen", "inspection frees pointer despite previous first-person lock state")
locked = false
event = press(Roblox.Enum.UserInputType.Touch)
input.InputEnded:Fire(event, false)
h:drain()
check(#calls == 1 and calls[1][1] == "ToggleContainer", "tap sends one toggle")
event = press(Roblox.Enum.UserInputType.MouseButton1)
h:drain()
check(#calls == 2, "mouse down activates immediately without waiting for release")
a:SetAttribute("DPU_ContainerRevision", 99)
input.InputEnded:Fire({ UserInputType = Roblox.Enum.UserInputType.MouseButton1, Position = event.Position }, false)
h:drain()
check(#calls == 2 and calls[2][2].Revision == 0, "distinct mouse release cannot duplicate or lose the click")
event = press(Roblox.Enum.UserInputType.Touch)
input.WindowFocusReleased:Fire()
input.WindowFocused:Fire()
input.InputEnded:Fire(event, false)
h:drain()
check(#calls == 2, "focus loss cancels held input")
check(
	not active and camera.CFrame == savedFrame and root.LocalTransparencyModifier == 0.4,
	"focus loss restores camera and avatar"
)
blocked = true
input.InputBegan:Fire({ KeyCode = Roblox.Enum.KeyCode.ButtonR2 }, false)
h:drain()
check(#calls == 2, "menus suppress controller")
blocked = false
input.InputBegan:Fire({ KeyCode = Roblox.Enum.KeyCode.ButtonR2 }, false)
h:drain()
check(#calls == 2 and active, "controller first click reopens view only")
cameraTween:Finish()
input.PreferredInput = preferred.Gamepad
input.InputBegan:Fire({ KeyCode = Roblox.Enum.KeyCode.DPadRight }, false)
check(client:Pick() == b, "controller navigates between drawers in close-up")
input.InputBegan:Fire({ KeyCode = Roblox.Enum.KeyCode.DPadLeft }, false)
input.InputBegan:Fire({ KeyCode = Roblox.Enum.KeyCode.ButtonA }, false)
h:drain()
check(#calls == 3, "controller activates")
input.PreferredInput = preferred.KeyboardAndMouse
-- Exercise mouse -> real request validation -> actual tween goal, not just the payload.
a:SetAttribute("DPU_ContainerRevision", containers.boxes[a].revision)
local outcome
client.d.remote.InvokeServer = function(_, action, payload)
	check(action == "ToggleContainer", "mouse uses the active container endpoint")
	outcome = containers:Request(player, payload)
	return outcome
end
h.time += 0.2
press(Roblox.Enum.UserInputType.MouseButton1)
h:drain()
check(outcome.Ok and a:GetAttribute("DPU_ContainerBusy"), "mouse click reaches server and starts slide")
lastTween:Finish()
render.RenderStepped:Fire()
check(camera.CFrame == framed, "sliding drawers do not move inspection camera")
check(
	(a.Position - (closed.Position + Roblox.Vector3.new(0, 0, -0.8))).Magnitude < 0.001,
	"mouse-to-server path actually reaches open position"
)
h.time += 0.2
press(Roblox.Enum.UserInputType.MouseButton1)
h:drain()
lastTween:Finish()
check(outcome.Ok and (a.Position - closed.Position).Magnitude < 0.001, "next mouse click actually returns box closed")
camera.ViewportSize = Roblox.Vector2.new(390, 844)
render.RenderStepped:Fire()
check(
	(camera.CFrame.Position - camera.Focus.Position).Magnitude > (framed.Position - camera.Focus.Position).Magnitude,
	"portrait view backs up to show all drawers"
)
input.InputBegan:Fire({ KeyCode = Roblox.Enum.KeyCode.Q }, false)
check(
	not active and camera.CameraType == Roblox.Enum.CameraType.Custom and camera.CFrame == savedFrame,
	"Q closes view and restores camera"
)
press(Roblox.Enum.UserInputType.MouseButton1)
local interrupted = cameraTween
input.InputBegan:Fire({ KeyCode = Roblox.Enum.KeyCode.ButtonB }, false)
interrupted:Finish()
check(
	not active and interrupted.cancelled and camera.CFrame == savedFrame,
	"B cancels entry without a late tween overwrite"
)
reduced = true
press(Roblox.Enum.UserInputType.MouseButton1)
check(active and not inspection.entering, "reduced motion opens without a camera tween")
humanoid.MoveDirection = Roblox.Vector3.xAxis
render.RenderStepped:Fire()
check(not active, "walking exits the container view")
humanoid.MoveDirection = Roblox.Vector3.zero
press(Roblox.Enum.UserInputType.MouseButton1)
blocked = true
render.RenderStepped:Fire()
check(not active, "menu interruption releases camera")
blocked = false
press(Roblox.Enum.UserInputType.MouseButton1)
humanoid.Health = 0
render.RenderStepped:Fire()
check(not active, "death releases camera")
humanoid.Health = 100
press(Roblox.Enum.UserInputType.MouseButton1)
client:Destroy()
inspection:Destroy()
input.InputBegan:Fire({ KeyCode = Roblox.Enum.KeyCode.E }, false)
h:drain()
check(
	#calls == 3 and not hover and client.highlight.Parent == nil and not active,
	"teardown releases listeners, camera and clone"
)
containers:Shutdown()
check(a:GetAttribute("DPU_ContainerId") == nil and request(a).Code == "NotReady", "shutdown cleans owned state")
check(h:load("src/GServer/GameConfig.luau").PrototypeEnabled == false, "prototype disabled by active config")
local source = fs.readFile("src/GClient/Prototype/PrototypeController.local.luau")
check(
	source:find('GetAttribute("PrototypeEnabled")', 1, true) < source:find("local Shared =", 1, true),
	"prototype client gates imports"
)
print(string.format("PASS: %d container checks (mocked Roblox).", total))
