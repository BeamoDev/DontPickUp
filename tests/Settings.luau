local Harness = require("./Harness")
local Signal = require("./TagFixture").Signal
local Roblox = require("@lune/roblox")
local fs = require("@lune/fs")
local h, total = Harness.Environment(), 0
local function check(ok, label)
	assert(ok, label)
	total += 1
end
for _, key in ipairs({ "Color3", "UDim2", "Vector2" }) do
	h.env[key] = Roblox[key]
end
h.env.Enum = Roblox.Enum
h.env.TweenInfo = {
	new = function(time, style, direction)
		return { Time = time, Style = style, Direction = direction }
	end,
}
local function node(class, name, parent)
	local item = h.instance(class)
	item.Name, item.Parent = name or class, parent
	item.DescendantAdded, item.DescendantRemoving = Signal(), Signal()
	local signals, attrs = {}, {}
	item.GetPropertyChangedSignal = function(_, key)
		signals[key] = signals[key] or Signal()
		return signals[key]
	end
	item.GetAttributeChangedSignal = function(_, key)
		attrs[key] = attrs[key] or Signal()
		return attrs[key]
	end
	local meta = getmetatable(item)
	local write = meta.__newindex
	meta.__newindex = function(self, key, value)
		local changed = self[key] ~= value
		write(self, key, value)
		if changed and signals[key] then
			signals[key]:Fire()
		end
	end
	if item:IsA("GuiObject") then
		item.Position, item.Size = Roblox.UDim2.fromScale(0.5, 0.5), Roblox.UDim2.fromScale(0.4, 0.5)
		item.BackgroundColor3, item.Visible, item.Active = Roblox.Color3.new(1, 1, 1), true, true
		item.Text, item.TextXAlignment, item.AutoButtonColor = "Authored", Roblox.Enum.TextXAlignment.Center, true
		item.ImageColor3 = Roblox.Color3.new(1, 1, 1)
	end
	return item
end
h.env.Instance.new = function(class)
	return node(class)
end
local Schema = h:load("src/LServer/PlayerData/ProfileSchema.luau")
for _, version in ipairs({ 1, 2 }) do
	local old = Schema.Default()
	old.Version, old.Settings.MusicVolume = version, 0
	old.Settings.MusicEnabled, old.Settings.SFXEnabled, old.Settings.CameraShake = nil, nil, nil
	old.Progress.Evidence.saved_clue = true
	old.RecentOutcomes = { "paid_once" }
	if version == 1 then
		old.Stats.Credits = nil
	else
		old.Stats.Credits = 42
	end
	local data = Schema.Decode({ Format = 1, Data = old })
	check(
		data
			and data.Version == Schema.Version
			and not data.Settings.MusicEnabled
			and data.Settings.SFXEnabled
			and data.Settings.CameraShake,
		"old profile migrates muted music and new boolean preferences"
	)
	check(
		data.Progress.Evidence.saved_clue
			and data.RecentOutcomes[1] == "paid_once"
			and data.Stats.Credits == (version == 1 and 0 or 42),
		"migration retains progression, wallet and outcome receipts"
	)
	check(old.Settings.SFXEnabled == nil and old.Version == version, "migration does not mutate stored input")
end
local bad = Schema.Default()
bad.Settings.CameraShake = "false"
check(not Schema.Validate(bad), "nonboolean setting fails schema validation")
local config = h:load("src/LServer/Configuration/ServerConfig.luau")
local data = h:load("src/LServer/PlayerData/DataService.luau").new({
	Players = h.players,
	RunService = {
		IsStudio = function()
			return true
		end,
	},
	HttpService = {
		GenerateGUID = function()
			return "settings-test"
		end,
	},
}, config)
local player = node("Player", "SettingsPlayer", h.players)
player.UserId = 101
check(not data:SetSetting(player, "MusicEnabled", false), "setting requires ready profile")
check(data:Load(player), "load real data service in practice mode")
check(
	not data:SetSetting(player, "SFXEnabled", 0) and not data:SetSetting(player, "Credits", true),
	"server rejects type confusion and unknown setting"
)
check(data:SetSetting(player, "MusicEnabled", false), "server accepts explicit boolean preference")
check(data:Save(player, false), "changed setting saves through existing profile store")
check(data.memory["101"].Data.Settings.MusicEnabled == false, "saved profile contains preference")
local gui = node("PlayerGui", "PlayerGui", player)
local screen = node("ScreenGui", "HUD", gui)
screen.Enabled = true
local frame = node("ImageLabel", "Settings", screen)
frame.Visible = false
local content = node("Frame", "Frame", frame)
local close = node("ImageButton", "Close", frame)
local rows = {}
for _, name in ipairs({ "Music", "SFX", "CameraShake" }) do
	local row = node("Frame", name, content)
	local toggle = node(name == "Music" and "ImageButton" or "TextButton", "Toggle", row)
	local ball, title, stroke =
		node("Frame", "Ball", toggle), node("TextLabel", "Title", toggle), node("UIStroke", "UIStroke", toggle)
	stroke.Color = Roblox.Color3.new(1, 1, 1)
	rows[name] = { toggle = toggle, ball = ball, title = title, stroke = stroke }
end
local world, sounds = node("Workspace"), node("SoundService")
local music, effect = node("Sound", "ShopMusic", sounds), node("Sound", "TelephoneRing", world)
music.Volume, effect.Volume = 0.7, 0.4
local jobs, tweens, calls = {}, {}, {}
local function defer(fn)
	table.insert(jobs, fn)
end
local function drain()
	local count = 0
	while #jobs > 0 do
		count += 1
		assert(count < 100)
		table.remove(jobs, 1)()
	end
end
local tweenService = {
	Create = function(_, target, info, goal)
		local t = { Completed = Signal(), Target = target, Goal = goal, Info = info }
		function t:Play()
			self.playing = true
		end
		function t:Cancel()
			self.cancelled = true
			self.playing = false
			self.Completed:Fire(Roblox.Enum.PlaybackState.Cancelled)
		end
		table.insert(tweens, t)
		return t
	end,
}
local function finishTweens()
	for _, t in ipairs(table.clone(tweens)) do
		if t.playing and not t.cancelled then
			t.playing = false
			for key, value in pairs(t.Goal) do
				t.Target[key] = value
			end
			t.Completed:Fire(Roblox.Enum.PlaybackState.Completed)
		end
	end
end
local failure, rapid = false, false
local controller
local Controller = h:load("src/LClient/Interface/SettingsController.luau")
controller = Controller.new({
	player = player,
	playerGui = gui,
	soundRoots = { sounds, world, gui },
	defer = defer,
	spawn = defer,
	tweens = tweenService,
	reduced = function()
		return false
	end,
	invoke = function(action, payload)
		table.insert(calls, { action, payload.Key, payload.Value })
		if rapid then
			rapid = false
			controller:Toggle(payload.Key)
			controller:Toggle(payload.Key)
			controller:Toggle(payload.Key)
		end
		if failure then
			return { Ok = false, Code = "DataNotReady" }
		end
		local ok, code = data:SetSetting(player, payload.Key, payload.Value)
		return { Ok = ok, Code = code }
	end,
})
check(
	not frame.Visible and music.Volume == 0 and effect.Volume == 0.4,
	"mount applies saved music without opening UI or muting SFX"
)
check(
	rows.Music.ball.Position == Roblox.UDim2.fromScale(0.2, 0.5) and rows.Music.title.Text == "OFF",
	"saved OFF renders requested ball and title"
)
check(
	rows.Music.title.TextXAlignment == Roblox.Enum.TextXAlignment.Right
		and rows.Music.toggle.ImageColor3 == Roblox.Color3.fromRGB(85, 85, 85),
	"OFF uses right alignment and grey image"
)
frame.Visible = true
check(
	gui:GetAttribute("DPU_SettingsOpen") == true,
	"owner-controlled visibility releases pointer through modal attribute"
)
rows.Music.toggle.Activated:Fire()
drain()
finishTweens()
check(
	music.Volume == 0.7 and calls[#calls][1] == "SetSetting",
	"Music toggle restores original volume and calls existing endpoint"
)
check(
	rows.Music.ball.Position == Roblox.UDim2.fromScale(0.8, 0.5)
		and rows.Music.title.TextXAlignment == Roblox.Enum.TextXAlignment.Left,
	"ON restores exact ball position and alignment"
)
check(
	rows.Music.toggle.ImageColor3 == Roblox.Color3.fromRGB(85, 171, 84)
		and rows.Music.stroke.Color == Roblox.Color3.fromRGB(121, 255, 114),
	"ON uses requested green colors"
)
rows.SFX.toggle.Activated:Fire()
drain()
finishTweens()
check(effect.Volume == 0 and music.Volume == 0.7, "SFX toggle leaves music playing")
effect.Volume = 0.9
check(effect.Volume == 0, "runtime sound volume writes stay muted")
effect:GetPropertyChangedSignal("Volume"):Fire()
local late = node("Sound", "LateEffect", world)
late.Volume = 0.3
world.DescendantAdded:Fire(late)
check(late.Volume == 0, "new sounds inherit muted preference")
rows.SFX.toggle.Activated:Fire()
drain()
finishTweens()
check(effect.Volume == 0.9 and late.Volume == 0.3, "unmuting preserves updated volumes despite own change signals")
rows.CameraShake.toggle.Activated:Fire()
drain()
check(
	player:GetAttribute("DPU_CameraShake") == false and player.PlayerData.Settings.CameraShake.Value == false,
	"CameraShake applies locally and saves as independent boolean"
)
failure = true
rows.CameraShake.toggle.Activated:Fire()
drain()
finishTweens()
check(
	controller.values.CameraShake == false and rows.CameraShake.title.Text == "OFF",
	"failed write rolls toggle back to confirmed value"
)
failure, rapid = false, true
local before = #calls
rows.Music.toggle.Activated:Fire()
drain()
finishTweens()
check(
	#calls == before + 2
		and controller.values.MusicEnabled == true
		and player.PlayerData.Settings.MusicEnabled.Value == true,
	"rapid changes serialize and coalesce to final desired value"
)
local position, size = frame.Position, frame.Size
close.Activated:Fire()
local t = controller.view.closeTween
check(
	t.Info.Time == 0.44
		and t.Info.Style == Roblox.Enum.EasingStyle.Back
		and t.Goal.Position == position + Roblox.UDim2.fromOffset(0, 18),
	"close matches Kingdom Wars downward timing and easing"
)
close.Activated:Fire()
check(controller.view.closeTween == t and frame.Visible, "duplicate close does not restart animation")
finishTweens()
check(
	not frame.Visible
		and frame.Position == position
		and frame.Size == size
		and gui:GetAttribute("DPU_SettingsOpen") == false,
	"close hides after tween and preserves authored geometry for reopening"
)
frame.Visible = true
close.Activated:Fire()
local stale = controller.view.closeTween
frame.Visible = false
frame.Visible = true
stale.Completed:Fire(Roblox.Enum.PlaybackState.Completed)
check(frame.Visible and frame.Position == position, "cancelled close cannot hide a reopened panel")
local oldView = controller.view
screen.Parent = nil
gui.DescendantRemoving:Fire(screen)
drain()
check(oldView.dead and not controller.view, "removed GUI releases all bindings")
screen.Parent = gui
gui.DescendantAdded:Fire(screen)
drain()
check(controller.view and controller.view ~= oldView, "respawn replacement rebinds authored UI")
controller:Destroy()
before = #calls
rows.SFX.toggle.Activated:Fire()
drain()
check(
	#calls == before and effect.Volume == 0.9 and music.Volume == 0.7,
	"teardown restores sounds and disconnects input"
)
for _, file in ipairs({ "SettingsController", "SettingsAudio", "SettingsView" }) do
	check(
		fs.readFile("src/LClient/Interface/" .. file .. ".luau")
			== fs.readFile("src/GClient/Interface/" .. file .. ".luau"),
		"Game/Lobby module parity: " .. file
	)
end
print(string.format("PASS: %d settings UI, audio, request ordering and profile migration checks.", total))
