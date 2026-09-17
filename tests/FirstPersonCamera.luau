local Harness = require("./Harness")
local Roblox = require("@lune/roblox")
local signal = require("./TagFixture").Signal
local h, total = Harness.Environment(), 0
local function check(value, label)
	assert(value, label)
	total += 1
end
local preferred = { KeyboardAndMouse = "Mouse", Touch = "Touch", Gamepad = "Pad" }
Roblox = setmetatable(
	{
		Enum = setmetatable({ PreferredInput = preferred }, {
			__index = function(_, k)
				return require("@lune/roblox").Enum[k]
			end,
		}),
	},
	{ __index = Roblox }
)
for _, name in ipairs({ "Vector2", "UDim2", "UDim", "Color3", "Enum" }) do
	h.env[name] = Roblox[name]
end
local player, gui = h:player(1), h.instance("ScreenGui")
local input = {
	InputBegan = signal(),
	WindowFocusReleased = signal(),
	GetMouseLocation = function()
		return Roblox.Vector2.new(400, 200)
	end,
}
-- Cursor policy must release real UI interactions without fighting station cameras.
h.env.UDim = Roblox.UDim
local needsPointer, menuOpen, textFocus = false, false, nil
input.WindowFocused = signal()
input.PreferredInput = Roblox.Enum.PreferredInput.KeyboardAndMouse
input.MouseBehavior = Roblox.Enum.MouseBehavior.Default
input.MouseIconEnabled = true
function input:GetFocusedTextBox()
	return textFocus
end
player.CameraMode = Roblox.Enum.CameraMode.Classic
player.CharacterAdded = signal()
gui.Parent = h.instance("PlayerGui")
local render = { callback = nil }
function render:BindToRenderStep(name, priority, callback)
	self.name, self.priority, self.callback = name, priority, callback
end
function render:UnbindFromRenderStep(name)
	check(name == self.name, "cursor removes its own frame binding")
	self.callback = nil
end
local cursor = h:load("src/GClient/Camera/CameraController.luau").new(gui, player, input, {
	render = render,
	needsPointer = function()
		return needsPointer
	end,
	menuOpen = function()
		return menuOpen
	end,
})
check(
	cursor:IsLocked() and not input.MouseIconEnabled and cursor.dot.Visible,
	"normal play locks to center with only the dot visible"
)
check(
	cursor.overlay.IgnoreGuiInset and cursor.dot.Position == h.env.UDim2.fromScale(0.5, 0.5),
	"dot uses the full viewport center"
)
check(render.priority > Roblox.Enum.RenderPriority.Camera.Value, "cursor policy runs after native camera")
check(cursor.dot.Size == Roblox.UDim2.fromOffset(6, 6), "cursor is 1.5 times its original size")
cursor:SetHover(true, false)
cursor:Step()
local idleAlpha = cursor.dot.BackgroundTransparency
h.time += 0.6
cursor:Step()
check(cursor.dot.BackgroundTransparency < idleAlpha, "valid hover smoothly brightens the dot")
cursor:SetHover(true, true)
cursor:Step()
check(cursor.dot.BackgroundTransparency == 0.2, "reduced motion uses steady hover brightness")
cursor:SetHover(false, false)
cursor:Step()
check(cursor.dot.BackgroundTransparency == 0.45, "leaving an item restores faint cursor")
input.InputBegan:Fire({ KeyCode = Roblox.Enum.KeyCode.V }, false)
check(
	not cursor:IsLocked() and cursor.toggle.Modal and input.MouseBehavior == Roblox.Enum.MouseBehavior.Default,
	"V frees the cursor"
)
check(cursor.dot.Position == h.env.UDim2.fromOffset(400, 200), "free dot follows screen mouse coordinates")
cursor.toggle.Activated:Fire()
check(cursor:IsLocked(), "small button relocks the cursor")
needsPointer = true
render.callback()
input.InputBegan:Fire({ KeyCode = Roblox.Enum.KeyCode.V }, false)
check(
	not cursor:IsLocked() and not cursor.toggle.Active,
	"task automatically frees cursor and cannot be manually trapped"
)
needsPointer = false
render.callback()
check(cursor:IsLocked(), "leaving task restores normal look controls")
cursor:Toggle()
cursor:Relock()
check(cursor:IsLocked() and not cursor.manualFree, "close relocks immediately even after manual cursor release")
menuOpen = true
cursor:Relock()
check(not cursor:IsLocked(), "close relock respects an open system menu")
render.callback()
check(
	not cursor:IsLocked() and input.MouseIconEnabled and not cursor.dot.Visible,
	"Roblox menu gets native free cursor"
)
menuOpen, textFocus = false, {}
render.callback()
input.InputBegan:Fire({ KeyCode = Roblox.Enum.KeyCode.V }, false)
check(not cursor.manualFree and not cursor:IsLocked(), "typing V in chat cannot toggle mouse mode")
textFocus = nil
input.WindowFocusReleased:Fire()
check(not cursor:IsLocked() and not cursor.dot.Visible, "alt-tab releases mouse and hides dot")
input.WindowFocused:Fire()
check(cursor:IsLocked(), "returning focus restores center lock")
input.PreferredInput = Roblox.Enum.PreferredInput.Touch
render.callback()
check(
	not cursor.dot.Visible and not cursor.toggle.Modal and not cursor:IsLocked(),
	"touch camera is not forced into mouse policy"
)
input.PreferredInput = Roblox.Enum.PreferredInput.KeyboardAndMouse
render.callback()
cursor:Toggle()
player.CharacterAdded:Fire()
check(cursor:IsLocked() and not cursor.manualFree, "respawn starts with centered camera controls")
cursor:Destroy()
cursor:Destroy()
check(
	render.callback == nil and player.CameraMode == Roblox.Enum.CameraMode.Classic and input.MouseIconEnabled,
	"teardown restores native camera and cursor"
)
print(string.format("PASS: %d first-person cursor checks (mocked Roblox).", total))
