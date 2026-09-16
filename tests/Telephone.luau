local Harness = require("./Harness")
local Roblox = require("@lune/roblox")
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
local config = h:load("src/GShared/Telephone/TelephoneConfig.luau")
local origin, size = Roblox.CFrame.new(8.572, 0.768, 34.802), Roblox.Vector3.new(3, 0.8, 2)
local viewport = Roblox.Vector2.new(1280, 720)
local frame, focus = config.CameraFrame(origin, origin, size, viewport)
check(
	frame.LookVector:Dot((focus.Position - frame.Position).Unit) > 0.999,
	"camera looks toward the screen rather than away"
)
local rotation = Roblox.CFrame.new(50, 5, -20) * Roblox.CFrame.Angles(0, math.pi / 2, 0)
local rotated = config.CameraFrame(rotation * origin, rotation * origin, size, viewport)
check(
	(rotated.Position - (rotation * frame).Position).Magnitude < 0.001,
	"camera offset follows translated/rotated telephone"
)
check((rotated.LookVector - (rotation * frame).LookVector).Magnitude < 0.001, "camera direction rotates with telephone")
check(
	(focus.Position - origin.Position).Magnitude < 0.001 and frame.Position.Y > origin.Position.Y,
	"camera is above and aims at phone"
)
local portrait = config.CameraFrame(origin, origin, size, Roblox.Vector2.new(390, 844))
check(
	(portrait.Position - origin.Position).Magnitude > (frame.Position - origin.Position).Magnitude,
	"portrait framing moves back to fit keypad"
)
check(
	config.Key("Key0") == "0" and config.Key("Key#") == "#" and config.Key("Key*") == "*",
	"exact authored key names map"
)
check(config.Key("Phone") == nil and config.Key("RedButton") == nil, "unassigned props have no invented behavior")

local world, model = h.instance("Workspace"), h.instance("Model")
model.Name, model.Parent = "AnyFaxName", world
collection:AddTag(model, "Fax")
model.GetPivot = function()
	return origin
end
model.GetBoundingBox = function()
	return origin, size
end
local function child(class, name, parent)
	local item = h.instance(class)
	item.Name, item.Parent = name, parent
	return item
end
for _, name in ipairs(config.ControlOrder) do
	child("Part", name, model)
end
local inputArea = child("Part", "InputArea", model)
local surface = child("SurfaceGui", "SurfaceGui", inputArea)
local screen = child("Frame", "Frame", surface)
local label = child("TextLabel", "TextLabel", screen)
surface.Enabled, screen.Visible, label.Visible, label.Text = false, false, false, "AUTHORED TEXT"
local player = h:player(1)
player.Character, player.CharacterAdded = h.instance("Model"), signal()
player.Character.DescendantAdded = signal()
local root = child("Part", "HumanoidRootPart", player.Character)
root.Position, root.LocalTransparencyModifier = origin.Position + Roblox.Vector3.new(0, 0, 3), 0.4
local humanoid = child("Humanoid", "Humanoid", player.Character)
humanoid.Health, humanoid.Sit, humanoid.MoveDirection = 100, false, Roblox.Vector3.zero
local camera = {
	CameraType = Roblox.Enum.CameraType.Custom,
	CameraSubject = humanoid,
	CFrame = Roblox.CFrame.new(0, 10, 0),
	Focus = Roblox.CFrame.new(),
	FieldOfView = 70,
	ViewportSize = viewport,
}
camera.ScreenPointToRay = function()
	return { Origin = frame.Position, Direction = frame.LookVector }
end
camera.ViewportPointToRay = camera.ScreenPointToRay
world.CurrentCamera = camera
local target = model.Key1
world.Raycast = function()
	return target and { Instance = target, Position = origin.Position } or nil
end
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
		return Roblox.Vector2.new(300, 300)
	end,
}
local render = { RenderStepped = signal() }
local tween
local tweens = {
	Create = function(_, object, _, goal)
		tween = {
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
			for property, value in pairs(goal) do
				object[property] = value
			end
			self.Completed:Fire()
		end
		return tween
	end,
}
local active, menu, reduced = false, false, false
local template = h.instance("Highlight")
template.FillTransparency = 0.7
local telephone = h:load("src/GClient/Telephone/TelephoneInteraction.luau").new({
	collection = collection,
	player = player,
	input = input,
	workspace = world,
	config = config,
	tweens = tweens,
	render = render,
	reduced = function()
		return reduced
	end,
	menuOpen = function()
		return menu
	end,
	modalOpen = function()
		return false
	end,
	template = function()
		return template
	end,
	active = function(value)
		active = value
	end,
})
check(
	telephone:Target({ Instance = model.Key1, Position = origin.Position }, root) == model,
	"key/body hit selects containing Telephone model"
)
check(
	telephone:Target({ Instance = model.Key1, Position = origin.Position + Roblox.Vector3.new(50, 0, 0) }, root) == nil,
	"distant telephone rejected"
)
local savedFrame = camera.CFrame
telephone:Open(model)
check(
	active and camera.CameraType == Roblox.Enum.CameraType.Scriptable and telephone.entering,
	"selection starts close-up tween"
)
check(
	surface.Enabled and screen.Visible and label.Visible and label.Text == "",
	"authored display ancestors visible during phone use"
)
check(root.LocalTransparencyModifier == 1, "own character hidden locally during close-up")
telephone:Enter("1")
check(label.Text == "", "keypad waits until camera finishes")
tween:Finish()
telephone:Update()
check(
	telephone.highlight.Parent == model.Key1 and telephone.highlight.FillTransparency == 0.7,
	"hover clones authored highlight on physical key"
)
local function tap(kind, drag)
	local event =
		{ UserInputType = kind, KeyCode = Roblox.Enum.KeyCode.Unknown, Position = Roblox.Vector3.new(300, 300, 0) }
	input.InputBegan:Fire(event, false)
	if drag then
		event.Position = Roblox.Vector3.new(340, 300, 0)
	end
	input.InputEnded:Fire(event, false)
end
tap(Roblox.Enum.UserInputType.Touch, true)
check(label.Text == "", "touch drag does not enter digits")
tap(Roblox.Enum.UserInputType.Touch, false)
check(label.Text == "1", "touch key enters a digit")
target = model.Key0
tap(Roblox.Enum.UserInputType.MouseButton1, false)
check(label.Text == "10", "mouse selects physical zero key")
input.InputBegan:Fire(
	{ KeyCode = Roblox.Enum.KeyCode.Three, UserInputType = Roblox.Enum.UserInputType.Keyboard },
	false
)
check(label.Text == "103", "keyboard digits enter same authored label")
telephone:Enter("Clear")
input.PreferredInput = preferred.Gamepad
input.InputBegan:Fire({ KeyCode = Roblox.Enum.KeyCode.DPadRight }, false)
input.InputBegan:Fire({ KeyCode = Roblox.Enum.KeyCode.ButtonA }, false)
check(label.Text == "2", "controller navigation selects and presses physical key")
telephone:Enter("*")
telephone:Enter("#")
check(label.Text == "2*#", "special keys enter symbols")
telephone:Enter("Backspace")
check(label.Text == "2*", "backspace removes one digit")
telephone:Enter("Clear")
for _ = 1, 20 do
	telephone:Enter("9")
end
check(#label.Text == config.MaxDigits, "phone input has bounded length")
telephone:Enter("Dial")
check(label.Text == "NOT CONNECTED", "dial is explicitly unconnected rather than a fake call")
telephone:Enter("Close")
check(
	not active
		and camera.CameraType == Roblox.Enum.CameraType.Custom
		and camera.CFrame == savedFrame
		and camera.FieldOfView == 70,
	"close restores original camera"
)
check(
	not surface.Enabled and not screen.Visible and not label.Visible and label.Text == "AUTHORED TEXT",
	"close restores authored display state"
)
check(root.LocalTransparencyModifier == 0.4, "close restores exact local character transparency")

telephone:Open(model)
local interrupted = tween
input.WindowFocusReleased:Fire()
interrupted:Finish()
check(
	not active and interrupted.cancelled and camera.CFrame == savedFrame,
	"focus loss cancels tween without late camera overwrite"
)
input.WindowFocused:Fire()
reduced = true
telephone:Open(model)
check(active and not telephone.entering, "reduced motion switches shot without tween")
humanoid.MoveDirection = Roblox.Vector3.xAxis
render.RenderStepped:Fire()
check(not active and camera.CameraType == Roblox.Enum.CameraType.Custom, "movement leaves telephone")
humanoid.MoveDirection = Roblox.Vector3.zero
telephone:Open(model)
menu = true
render.RenderStepped:Fire()
check(not active, "Roblox menu restores camera")
menu = false
telephone:Open(model)
local replacement = {}
world.CurrentCamera = replacement
render.RenderStepped:Fire()
check(not active and world.CurrentCamera == replacement, "camera replacement is not overwritten")
world.CurrentCamera = camera
telephone:Open(model)
player.CharacterAdded:Fire()
check(not active, "respawn closes phone")
telephone:Open(model)
telephone:Destroy()
input.InputBegan:Fire({ KeyCode = Roblox.Enum.KeyCode.One }, false)
check(not active and label.Text == "AUTHORED TEXT", "teardown releases camera, screen and input")

-- The existing idle picker routes Telephone selection without a second raycast/remote.
local router = h:load("src/GClient/Interactions/TaggedInteraction.luau")
local calls = 0
local fakePhone = {
	IsTelephone = function(_, item)
		return item == model
	end,
	Open = function()
		calls += 1
	end,
}
local bridge = setmetatable({
	d = {
		collection = collection,
		player = player,
		workspace = world,
		input = input,
		telephone = fakePhone,
		blocked = function()
			return false
		end,
	},
	focused = true,
}, router)
bridge:Send(model)
check(calls == 1 and bridge.pending == nil, "telephone selection stays local and does not send a container request")
print(string.format("PASS: %d telephone camera/keypad checks (mocked Roblox).", total))
