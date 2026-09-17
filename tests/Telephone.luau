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
local config = h:load("src/GClient/Effects/TelephoneConfig.luau")
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
	InputChanged = signal(),
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
local telephone = h:load("src/GClient/Effects/PhysicalTelephoneController.luau").new({
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
-- Isolated keypad tests drive the same entry methods owned by InteractionController.
input.InputBegan:Connect(function(...)
	telephone:InputBegan(...)
end)
input.InputChanged:Connect(function(...)
	telephone:InputChanged(...)
end)
input.InputEnded:Connect(function(...)
	telephone:InputEnded(...)
end)
input.WindowFocusReleased:Connect(function()
	telephone.focused = false
	telephone:Close()
end)
input.WindowFocused:Connect(function()
	telephone.focused = true
end)
player.CharacterAdded:Connect(function()
	telephone:Close(true)
end)
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
	telephone.highlight.Adornee == model.Key1 and telephone.highlight.FillTransparency == 0.7,
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
-- Recognised numbers expose call state for a future subtitle renderer.
local notifications = {}
telephone.d.callChanged = function(state)
	table.insert(notifications, state)
end
telephone:Enter("Clear")
telephone:Enter("6")
telephone:Enter("7")
telephone:Enter("Dial")
check(
	label.Text == "DIALING 67" and #notifications == 1 and notifications[1].Phase == "Dialing",
	"67 starts an easter-egg call"
)
telephone:Enter("Dial")
check(#notifications == 1, "repeat Dial cannot start a duplicate call")
h.time += 1
telephone:Update()
telephone:Update()
check(
	label.Text == "CONNECTED 67" and #notifications == 2 and notifications[2].SubtitleKey == "Fax.SixSeven",
	"connection emits exactly one future-subtitle hook"
)
telephone:Enter("9")
check(label.Text == "CONNECTED 67", "digits cannot replace an active call")
input.PreferredInput = preferred.KeyboardAndMouse
target = model.End
tap(Roblox.Enum.UserInputType.MouseButton1, false)
check(
	telephone.call == nil and notifications[3].Phase == "Ended" and active,
	"physical End hangs up without closing inspection"
)
telephone:Enter("6")
telephone:Enter("7")
telephone:Enter("Dial")
local nextCall = notifications[#notifications].SessionId
check(nextCall ~= notifications[1].SessionId, "repeated number uses a fresh subtitle/call identity")
target = model.KeyClose
tap(Roblox.Enum.UserInputType.MouseButton1, false)
check(
	telephone.call == nil and notifications[#notifications].Phase == "Ended",
	"physical KeyClose ends dialing and exits through the camera close path"
)
local notificationCount = #notifications
h.time += 1
telephone:Update()
check(#notifications == notificationCount, "closed calls cannot emit a late Connected event")
telephone:Enter("Close")
check(
	camera.CameraType == Roblox.Enum.CameraType.Scriptable and not telephone:Ready(),
	"phone return tween blocks input"
)
tween:Finish()
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
tween:Finish()
interrupted:Finish()
tween:Finish()
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
local router = h:load("src/GClient/Interaction/InteractionController.luau")
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
bridge.Update = function() end
bridge:Send(model)
check(calls == 1 and bridge.pending == nil, "telephone selection stays local and does not send a container request")
-- The prototype reuses the physical keypad/camera with server-confirmed ticket calls.
local scene = child("Folder", "Prototype", world)
local shop = child("Folder", "DPU_Prototype", scene)
model.Name, model.Parent = "Fax", shop
local sent, cursor = {}, {}
reduced = false
local pickup = h:load("src/GClient/Effects/TelephoneController.luau").new({
	player = player,
	input = input,
	workspace = world,
	collection = collection,
	tweens = tweens,
	render = render,
	reduced = function()
		return reduced
	end,
	menuOpen = function()
		return menu
	end,
	template = function()
		return template
	end,
	clock = function()
		return h.time
	end,
	send = function(action, payload)
		table.insert(sent, { action, payload })
	end,
	cursor = function(returning)
		table.insert(cursor, returning)
	end,
})
local raised, lowered = 0, 0
local legacy = child("Model", "Telephone", scene)
check(not pickup.phone:IsTelephone(legacy), "obsolete sibling Telephone is not an active pickup target")
check(pickup.phone:IsTelephone(model), "nested authored Fax is the physical telephone")
pickup.phone.receiver = {
	Raise = function(_, object)
		check(object == model, "pickup raises the authored receiver")
		raised += 1
	end,
	Lower = function()
		lowered += 1
	end,
	Update = function() end,
	Clear = function() end,
}
local state = {
	Alive = true,
	Phase = "Night",
	Fax = { Id = "visit1", EndsAt = h.time + 90, Tickets = { { Ticket = "123456", Step = "ReadyForPickup" } } },
}
pickup:Update(state, false, false)
check(
	pickup:OwnsInput() and pickup:NeedsPointer() and root.Anchored,
	"physical pickup anchors and tweens into inspection"
)
check(label.Text:find("123456") and surface.Enabled, "ready ticket number appears on the authored phone screen")
check(#sent == 0, "opening the physical screen adds no keypad request")
tween:Finish()
pickup.phone:Activate(model.Dial)
check(label.Text == "ENTER SIX DIGITS" and #sent == 0, "incomplete ticket is rejected locally")
for digit in ("1234567"):gmatch(".") do
	pickup.phone:Activate(model["Key" .. digit])
end
check(pickup.phone.digits == "123456" and label.Text == "123456", "physical keypad caps pickup tickets at six digits")
pickup.phone:Activate(model.Dial)
pickup.phone:Activate(model.Dial)
check(
	#sent == 1 and sent[1][1] == "DialTicket" and sent[1][2].Ticket == "123456" and sent[1][2].FaxId == "visit1",
	"one physical dial sends one visit-scoped request"
)
check(raised == 0, "receiver waits for authoritative call acceptance")
state.Fax.CallSerial, state.Fax.CalledTicket, state.Fax.Message = 1, "123456", "Called Mara. They are on the way!"
pickup:Update(state, false, false)
pickup:Update(state, false, false)
check(raised == 1 and pickup.phone.call and label.Text == "DIALING 123456", "matching server call raises receiver once")
h.time += 1
pickup:Step()
check(label.Text == state.Fax.Message, "confirmed pickup message uses physical display")
pickup.phone:Activate(model.End)
check(
	not pickup.phone.call and lowered > 0 and pickup:OwnsInput(),
	"physical End lowers receiver and keeps keypad open"
)
for digit in ("123456"):gmatch(".") do
	pickup.phone:Activate(model["Key" .. digit])
end
pickup.phone:Activate(model.Dial)
pickup.phone:Activate(model.KeyClose)
check(
	#sent == 3 and sent[3][1] == "CloseFax" and sent[3][2].FaxId == "visit1",
	"KeyClose sends one close even while dial is pending"
)
check(
	pickup:OwnsInput() and not pickup:NeedsPointer() and cursor[#cursor],
	"close relocks cursor while return tween owns input"
)
state.Fax.CallSerial = 2
pickup:Update(state, false, false)
check(raised == 1 and not pickup.phone.call, "late accepted call cannot raise receiver after closing")
tween:Finish()
check(
	not pickup:OwnsInput() and not root.Anchored and camera.CFrame == savedFrame,
	"pickup restores anchored state and original camera after exit"
)
pickup:Update(state, false, false)
check(not pickup:OwnsInput() and #sent == 3, "old server visit cannot reopen or send duplicate close")
state.Fax = { Id = "visit2", EndsAt = h.time + 90 }
pickup:Update(state, false, false)
tween:Finish()
pickup:Error("TicketNotFound")
check(label.Text == "TICKET NOT FOUND", "server errors appear on physical screen")
state.Fax = nil
pickup:Update(state, false, false)
tween:Finish()
check(not pickup:OwnsInput() and label.Text == "AUTHORED TEXT", "expired visits close and restore authored screen")
pickup:Destroy()
print(string.format("PASS: %d telephone camera/keypad checks (mocked Roblox).", total))
