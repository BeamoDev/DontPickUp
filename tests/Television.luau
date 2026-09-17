local Harness = require("./Harness")
local Fixture = require("./TagFixture")
local Roblox = require("@lune/roblox")
local h, total = Harness.Environment(), 0
local function check(value, label)
	assert(value, label)
	total += 1
end
for _, name in ipairs({ "CFrame", "Vector2", "Vector3" }) do
	h.env[name] = Roblox[name]
end
local preferred = { KeyboardAndMouse = "Mouse", Touch = "Touch", Gamepad = "Gamepad" }
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
local signal, collection = Fixture.Signal, Fixture.Collection()
local world, model = h.instance("Workspace"), h.instance("Model")
model.Name, model.Parent = "AnyTVName", world
local origin, size = Roblox.CFrame.new(3, 3, 3), Roblox.Vector3.new(4, 3, 1)
model.GetPivot = function()
	return origin
end
model.GetBoundingBox = function()
	return origin, size
end
local screen = h.instance("Part")
screen.Name, screen.Position, screen.Parent = "Screen", origin.Position, model
local player = h:player(1)
player.Character, player.CharacterAdded = h.instance("Model"), signal()
player.Character.DescendantAdded = signal()
local root, humanoid = h.instance("Part"), h.instance("Humanoid")
root.Name, root.Position, root.Parent, root.LocalTransparencyModifier =
	"HumanoidRootPart", origin.Position + Roblox.Vector3.new(0, 0, -4), player.Character, 0.3
humanoid.Health, humanoid.Sit, humanoid.MoveDirection, humanoid.Parent =
	100, false, Roblox.Vector3.zero, player.Character
root.Anchored, humanoid.AutoRotate = false, true
local camera = {
	CameraType = Roblox.Enum.CameraType.Custom,
	CameraSubject = humanoid,
	CFrame = Roblox.CFrame.new(0, 5, 0),
	Focus = Roblox.CFrame.new(),
	FieldOfView = 70,
	ViewportSize = Roblox.Vector2.new(1280, 720),
}
camera.ScreenPointToRay = function()
	return { Origin = root.Position, Direction = Roblox.Vector3.zAxis }
end
camera.ViewportPointToRay = camera.ScreenPointToRay
world.CurrentCamera = camera
world.Raycast = function()
	return { Instance = screen, Position = screen.Position }
end
local input = {
	InputBegan = signal(),
	InputEnded = signal(),
	InputChanged = signal(),
	WindowFocusReleased = signal(),
	WindowFocused = signal(),
	PreferredInput = preferred.KeyboardAndMouse,
	GetFocusedTextBox = function()
		return nil
	end,
	GetMouseLocation = function()
		return Roblox.Vector2.new(200, 200)
	end,
}
local render, menu, active, reduced, tween = { RenderStepped = signal() }, false, false, false, nil
local tags = h:load("src/GShared/Interaction/InteractionTags.luau")
local config = h:load("src/GClient/Camera/TelevisionViewConfig.luau")
local returningCamera
local television = h:load("src/GClient/Camera/InspectionCamera.luau").new({
	returning = function(value, target)
		returningCamera = value and target or nil
	end,
	player = player,
	input = input,
	workspace = world,
	config = config,
	render = render,
	valid = function(item)
		return tags.Kind(collection, item) == "tv"
	end,
	blocked = function()
		return menu
	end,
	reduced = function()
		return reduced
	end,
	active = function(value)
		active = value
	end,
	tweens = {
		Create = function(_, target, _, goal)
			local created = { Completed = signal(), Play = function() end }
			function created:Cancel()
				self.cancelled = true
			end
			function created:Finish()
				if self.cancelled then
					return
				end
				for key, value in pairs(goal) do
					target[key] = value
				end
				self.Completed:Fire()
			end
			tween = created
			return created
		end,
	},
})
local calls = 0
local router = h:load("src/GClient/Interaction/InteractionController.luau").new({
	player = player,
	input = input,
	workspace = world,
	collection = collection,
	television = television,
	config = h:load("src/GShared/Interaction/ContainerConfig.luau"),
	blocked = function()
		return menu or camera.CameraType == Roblox.Enum.CameraType.Scriptable
	end,
	locked = function()
		return true
	end,
	template = function()
		return nil
	end,
	hover = function() end,
	remote = {
		InvokeServer = function()
			calls += 1
		end,
	},
})
local function click()
	input.InputBegan:Fire({ UserInputType = Roblox.Enum.UserInputType.MouseButton1 }, false)
end
collection:AddTag(model, "TV")
check(router:Pick() == nil, "TV tag is case sensitive")
collection:AddTag(model, "tv")
check(router:Pick() == model, "screen hit resolves renamed tv model")
local saved = camera.CFrame
click()
check(
	active and television.entering and camera.CameraType == Roblox.Enum.CameraType.Scriptable,
	"click starts TV viewing tween"
)
check(root.Anchored and not humanoid.AutoRotate, "entry freezes character before camera tween completes")
tween:Finish()
local shot = camera.CFrame
check(
	math.abs(shot.Position.Y - origin.Position.Y) < 0.001 and shot.Position.Z < origin.Position.Z,
	"view is level and in front of model"
)
check(shot.LookVector:Dot((origin.Position - shot.Position).Unit) > 0.999, "camera faces television")
click()
h:drain()
check(calls == 0 and router:Blocked(), "watching sends no gameplay requests or follow-up object clicks")
input.InputBegan:Fire({ KeyCode = Roblox.Enum.KeyCode.Q }, false)
check(camera.CameraType == Roblox.Enum.CameraType.Scriptable, "exit keeps ownership until return tween finishes")
check(
	root.Anchored and returningCamera == camera and not active,
	"close hides UI and requests cursor relock while still anchored"
)
tween:Finish()
check(
	not active and camera.CFrame == saved and camera.FieldOfView == 70 and root.LocalTransparencyModifier == 0.3,
	"Q restores camera and avatar"
)
check(
	not root.Anchored and humanoid.AutoRotate and not returningCamera,
	"finished return restores movement and clears cursor override"
)
click()
local interrupted = tween
input.InputBegan:Fire({ KeyCode = Roblox.Enum.KeyCode.ButtonB }, false)
interrupted:Finish()
tween:Finish()
check(
	not active and interrupted.cancelled and camera.CFrame == saved,
	"B cancels unfinished entry without late overwrite"
)
click()
tween:Finish()
camera.ViewportSize = Roblox.Vector2.new(390, 844)
render.RenderStepped:Fire()
tween:Finish()
check(
	(camera.CFrame.Position - origin.Position).Magnitude > (shot.Position - origin.Position).Magnitude,
	"portrait view fits television"
)
menu = true
render.RenderStepped:Fire()
tween:Finish()
check(not active and camera.CameraType == Roblox.Enum.CameraType.Custom, "menu releases TV camera")
menu = false
reduced = true
click()
check(active and not television.entering, "reduced motion skips camera tween")
input.WindowFocusReleased:Fire()
tween:Finish()
check(not active, "focus loss exits watching")
input.WindowFocused:Fire()
click()
collection:RemoveTag(model, "tv")
render.RenderStepped:Fire()
check(not active, "removing tv tag restores camera")
collection:AddTag(model, "tv")
click()
humanoid.MoveDirection = Roblox.Vector3.xAxis
render.RenderStepped:Fire()
check(not active, "walking exits watching")
humanoid.MoveDirection = Roblox.Vector3.zero
click()
router:CloseView()
check(not active, "shared close-button action exits TV view")
click()
-- Normal returns retain ownership and end at the current first-person position.
television:Close(true)
reduced = false
click()
tween:Finish()
local beforeReturn = camera.CFrame
television:Close()
local returning = tween
check(
	camera.CFrame == beforeReturn and camera.CameraType == Roblox.Enum.CameraType.Scriptable,
	"ordinary close begins a return tween without snapping"
)
root.Position += Roblox.Vector3.new(2, 0, 0)
render.RenderStepped:Fire()
returning:Finish()
check(
	camera.CFrame == saved + Roblox.Vector3.new(2, 0, 0) and camera.FieldOfView == 70,
	"moving during return ends at translated first-person frame and original FOV"
)
click()
tween:Finish()
television:Close()
local obsolete = tween
humanoid.Health = 0
render.RenderStepped:Fire()
check(
	not television.saved and camera.CameraType == Roblox.Enum.CameraType.Custom and obsolete.cancelled,
	"death during return immediately releases camera and cancels tween"
)
check(not root.Anchored and humanoid.AutoRotate and not returningCamera, "death restores freeze and cursor state")
obsolete:Finish()
humanoid.Health = 100
root.Anchored, humanoid.AutoRotate = true, false
click()
television:Close(true)
check(root.Anchored and not humanoid.AutoRotate, "preexisting anchor and rotation state survives immediate close")
router:Destroy()
television:Destroy()
check(
	not active and calls == 0 and camera.CameraType == Roblox.Enum.CameraType.Custom,
	"teardown restores camera without any server mutation"
)
-- The authored prototype CRT is now a model with its own screen mesh.
local prototype, shop = h.instance("Folder"), h.instance("Folder")
prototype.Name, prototype.Parent, shop.Name, shop.Parent = "Prototype", world, "DPU_Prototype", prototype
model.Name, model.Parent, screen.Name = "CRT", shop, "CRTScreen"
screen.CFrame, screen.Size, screen.CanQuery = origin, Roblox.Vector3.new(4, 3, 0.2), true
local monitor = h.instance("Part")
monitor.Name, monitor.Parent = "Monitor", model
local scene = h:load("src/GShared/World/SceneReferences.luau")
local resolved, resolvedScreen = scene.Television(world)
check(resolved == model and resolvedScreen == screen, "prototype resolves CRT model and its nested CRTScreen")
root.Anchored, humanoid.AutoRotate, reduced = false, true, false
local cursorReturning
local deps = table.clone(television.d)
deps.cursor = function(returning)
	cursorReturning = returning
end
deps.uiBlocked = function()
	return false
end
local watching = h:load("src/GClient/Effects/TelevisionController.luau").new(deps)
local original = camera.CFrame
check(
	watching:Open(model) and watching:OwnsInput() and root.Anchored,
	"new CRT reuses camera anchoring and entry ownership"
)
tween:Finish()
check(camera.Focus.Position == screen.Position and camera.FieldOfView == 45, "prototype view fits nested TV screen")
local finger = { UserInputType = Roblox.Enum.UserInputType.Touch, Position = Roblox.Vector3.zero }
watching:InputBegan(finger, false)
finger.Position = Roblox.Vector3.new(40, 0, 0)
watching:InputChanged(finger)
finger.Position = Roblox.Vector3.zero
watching:InputEnded(finger, false)
check(watching:OwnsInput() and not watching.camera.exiting, "camera drag away and back does not count as close tap")
watching:InputBegan(finger, false)
watching:InputEnded(finger, false)
check(
	watching.camera.exiting and cursorReturning and not watching:NeedsPointer(),
	"tap begins return and immediately requests mouse relock"
)
tween:Finish()
check(
	not watching:OwnsInput() and not root.Anchored and camera.CFrame == original,
	"TV returns to original camera and releases anchoring"
)
watching:Open(model)
tween:Finish()
watching:InputBegan({ KeyCode = Roblox.Enum.KeyCode.Q }, false)
check(watching.camera.exiting, "Q closes prototype television")
tween:Finish()
watching:Open(model)
tween:Finish()
screen.Parent = nil
render.RenderStepped:Fire()
check(watching.camera.exiting, "removing nested screen cancels viewing safely")
tween:Finish()
screen.Parent = model
local routed, remoteCalls = 0, 0
model:SetAttribute("DPU_Direct", "CRT")
local worldController = h:load("src/GClient/Interaction/WorldInteractionController.luau")
local central = setmetatable({
	state = { Alive = true },
	d = {
		television = function()
			return {
				Open = function(_, item)
					check(item == model, "screen/monitor resolves whole TV model")
					routed += 1
				end,
			}
		end,
		send = function()
			remoteCalls += 1
		end,
	},
	Pick = function()
		return model
	end,
}, worldController)
central:Activate()
check(routed == 1 and remoteCalls == 0, "prototype central activation opens TV once without gameplay remote")
watching:Destroy()
check(model.Parent == shop and screen.Parent == model, "TV teardown preserves authored model and screen")
print(string.format("PASS: %d TV viewing checks (mocked Roblox).", total))
