local Harness = require("./Harness")
local Fixture = require("./ShiftFixture")
local Signal = require("./TagFixture").Signal
local Roblox = require("@lune/roblox")
local count = 0
local function check(ok, message)
	assert(ok, message)
	count += 1
end

-- Real shift actions: clock in, finish a phone, die, settle and restart.
do
	local f = Fixture(1, check)
	f:start()
	local member = f.run.players[f.p[1]]
	local started = member.WorkStartedAt
	check(
		started ~= nil and #f.run:Snapshot(f.p[1]).RuleSections == 3,
		"clock-in starts server work time and supplies three rules"
	)
	f:repair()
	check(member.RunRepairs == 1, "completed phone contributes to the employee's run total")
	f.run:Damage(f.p[1], 100, "test")
	local snapshot = f.run:Snapshot(f.p[1])
	check(
		snapshot.LossStats.PhonesFixed == 1 and snapshot.LossStats.TimeWorked == math.floor(f.h.time - started),
		"death freezes real run stats"
	)
	check(snapshot.CanReplay and snapshot.CanReturn, "settled solo death enables both actions")
	f.h.time += 30
	check(
		f.run:Snapshot(f.p[1]).LossStats.TimeWorked == snapshot.LossStats.TimeWorked,
		"loss time does not continue on the death screen"
	)
	check(f:act("Replay"), "solo retry uses the existing server restart")
	f.run:Tick()
	check(
		member.Alive and member.LossStats == nil and member.RunRepairs == 0,
		"retry revives player and clears run totals"
	)
end
do
	local f = Fixture(2, check)
	f:start()
	local member = f.run.players[f.p[1]]
	f.run.d.outcome = function()
		return false
	end
	f.run:Damage(f.p[1], 100, "test")
	check(not f.run:CanReturn(f.p[1]), "pending outcome cannot bypass settlement through new Lobby button")
	member.Settled = true
	check(f.run:CanReturn(f.p[1]), "settled dead employee can leave while teammate works")
	check(
		not f.run:CanReturn(f.p[2]) and not f:act("Replay"),
		"living employee and live shift cannot be reset by death UI"
	)
	f.run:Damage(f.p[2], 100, "test")
	f.run.players[f.p[2]].Settled = true
	check(f:act("Replay"), "first employee votes to retry")
	f.run:Tick()
	check(f.run.phase == "Results", "one vote never restarts the team")
	check(f:act("Replay", f.p[2]), "second employee votes to retry")
	f.run:Tick()
	check(f.run.phase == "Tutorial", "all employees ready starts a fresh run")
end

-- Continued nights retain totals; waiting on results is not work time.
do
	local f = Fixture(1, check)
	f:start()
	f:repair()
	f.run:Finish("Dawn")
	local member = f.run.players[f.p[1]]
	local worked = member.WorkSeconds
	f.h.time += 120
	check(f:act("Replay"), "survivor continues after results")
	f.run:Tick()
	check(
		member.WorkSeconds == worked and member.RunRepairs == 1,
		"continuation preserves totals and excludes result waiting"
	)
	check(f:act("ClockIn"), "next night starts a fresh work interval")
	f.h.time += 10
	f.run:Damage(f.p[1], 100, "test")
	local stats = f.run:Snapshot(f.p[1]).LossStats
	check(
		stats.Nights == 1 and stats.PhonesFixed == 1 and stats.TimeWorked == math.floor(worked + 10),
		"later death shows completed nights and cumulative work"
	)
end

local h = Harness.Environment()
for _, key in ipairs({ "UDim2", "Vector2", "Color3", "Enum" }) do
	h.env[key] = Roblox[key]
end
h.env.TweenInfo = {
	new = function()
		return {}
	end,
}
h.env.Content = {
	fromUri = function(uri)
		return uri
	end,
	fromObject = function(object)
		return object
	end,
}
local tweens = { all = {} }
function tweens:Create(object, _, goals)
	local tween = { Completed = Signal() }
	function tween:Play() end
	function tween:Cancel()
		self.cancelled = true
		self.Completed:Fire()
	end
	function tween:Finish()
		if not self.cancelled then
			for key, value in pairs(goals) do
				object[key] = value
			end
			self.Completed:Fire()
		end
	end
	table.insert(self.all, tween)
	return tween
end
local function finish()
	for _, tween in ipairs(tweens.all) do
		tween:Finish()
	end
end
local function node(class, name, parent)
	local object = h.instance(class)
	object.Name, object.Parent = name, parent
	object.Visible, object.Enabled, object.ResetOnSpawn = false, false, true
	object.Size, object.Position = Roblox.UDim2.fromScale(0.5, 0.6), Roblox.UDim2.fromScale(0.5, 0.5)
	object.Active, object.Selectable, object.BackgroundTransparency = true, true, 1
	object.Text, object.TextScaled = "authored", true
	object.ImageContent = "original"
	object.Activated = Signal()
	return object
end
local gui = node("PlayerGui", "PlayerGui")
local hud = node("ScreenGui", "HUD", gui)
local frames = node("Frame", "Frames", hud)
local settings = node("ImageLabel", "Settings", frames)
settings.Visible = true
local rules = node("ImageLabel", "TonightsRules", frames)
local ack = node("ImageButton", "Understood", rules)
for i = 1, 3 do
	node("TextLabel", "Section" .. i, rules)
end
local loss = node("ImageLabel", "GameLost", frames)
local retry = node("ImageButton", "Retry", loss)
local lobby = node("ImageButton", "Lobby", loss)
local photo = node("ImageLabel", "Mugshot", loss)
for _, name in ipairs({ "Nights", "PhonesFixed", "TimeWorked" }) do
	node("TextLabel", name, loss)
end
local pixels = buffer.fromstring(string.char(255, 0, 0, 127))
local image = {
	Size = Roblox.Vector2.new(1, 1),
	ReadPixelsBuffer = function()
		return pixels
	end,
	WritePixelsBuffer = function(_, _, _, data)
		pixels = data
	end,
	Destroy = function(self)
		self.destroyed = true
	end,
}
local assets = {
	CreateEditableImageAsync = function()
		return image
	end,
}
local actions, panels, state = {}, nil, {}
local Module = h:load("src/GClient/Interface/ShiftPanelController.luau")
panels = Module.new(gui, {
	userId = 123,
	assets = assets,
	tweens = tweens,
	reduced = function()
		return false
	end,
	understood = function()
		table.insert(actions, "ReadRules")
		panels:Update(state, true, true)
	end,
	act = function(action)
		table.insert(actions, action)
		panels:Update(state, true, false)
	end,
})
local originalSize, originalPosition = rules.Size, rules.Position
state = { NeedsRules = true, RuleSections = { "Repair", "Directive", "Do not answer" } }
panels:Update(state, false, true)
check(
	hud.Enabled and frames.Visible and rules.Visible and not hud.ResetOnSpawn,
	"rules reveal authored ancestors and survive death"
)
finish()
check(
	rules.Size == originalSize and rules.Position == originalPosition and rules.Section2.Text == "2. Directive",
	"entrance finishes at authored geometry with current directive"
)
ack.Activated:Fire()
ack.Activated:Fire()
check(#actions == 1, "busy state prevents duplicate acknowledgements")
panels:Update({}, false, false)
check(panels:IsOpen(), "closing tween retains modal input ownership")
panels:Update(state, false, true)
finish()
check(rules.Visible, "cancelled close cannot hide reopened rules")
state = {
	Outcome = "Died",
	LossStats = { Nights = 2, PhonesFixed = 7, TimeWorked = 125 },
	CanReplay = false,
	CanReturn = true,
}
panels:Update(state, false, false)
finish()
h:drain()
check(
	loss.Visible and not rules.Visible and frames.BackgroundTransparency == 0.2,
	"death replaces rules with dimmed loss panel"
)
check(
	loss.Nights.Text == "NIGHTS    2"
		and loss.PhonesFixed.Text == "PHONES FIXED    7"
		and loss.TimeWorked.Text == "TIME WORKED    02:05",
	"stats use exactly four spaces and elapsed time"
)
retry.Activated:Fire()
check(#actions == 1, "unavailable retry sends no request")
lobby.Activated:Fire()
lobby.Activated:Fire()
check(#actions == 2 and actions[2] == "ReturnLobby", "Lobby routes through existing request once")
check(
	buffer.readu8(pixels, 0) == 54
		and buffer.readu8(pixels, 1) == 54
		and buffer.readu8(pixels, 2) == 54
		and buffer.readu8(pixels, 3) == 127,
	"mugshot really desaturates pixels and preserves alpha"
)
check(
	photo.ImageContent == image and photo:GetAttribute("DPU_GrayscaleReady"),
	"converted mugshot reaches the authored image"
)
state.CanReplay = true
panels:Update(state, false, false)
retry.Activated:Fire()
check(actions[3] == "Replay", "Retry routes through validated shift action")
panels:Update({}, false, false)
finish()
check(
	not loss.Visible and frames.BackgroundTransparency == 1 and settings.Visible,
	"restart closes owned cards without hiding Settings"
)
panels:Destroy()
retry.Activated:Fire()
check(
	#actions == 3 and image.destroyed and photo.ImageContent == "original",
	"teardown disconnects inputs and releases portrait memory"
)
check(rules.Section2.Text == "authored" and rules.Section2.TextScaled, "authored text settings survive teardown")

local Mugshot = h:load("src/GClient/Interface/Mugshot.luau")
local pending = Mugshot.new(photo, 123, assets)
pending:Show()
pending:Destroy()
h:drain()
check(photo.ImageContent == "original", "late thumbnail completion cannot mutate a destroyed view")
local denied = Mugshot.new(photo, 123, {
	CreateEditableImageAsync = function()
		error("disabled")
	end,
})
denied:Show()
h:drain()
check(
	not photo:GetAttribute("DPU_GrayscaleReady") and photo.Image:find("AvatarHeadShot"),
	"Image API failure retains the usable player headshot"
)
denied:Destroy()
print("HUD panels checks passed:", count)
