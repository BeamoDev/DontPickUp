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

-- Reporting is a resolved team outcome; completed-shift statistics freeze once.
do
	local f = Fixture(2, check)
	f:start()
	local order, lane = f.run.stations.Bench.order, f.run.stations.Bench
	order.Step, order.Phone, order.VotePurpose = "Evidence", nil, "Evidence"
	order.VoteEndsAt, order.Votes = f.h.time + 20, { [f.p[1]] = "Report" }
	f.run:_resolveVote(lane)
	check(f.run.anomaliesReported == 0, "individual vote is not yet a reported anomaly")
	order.Votes[f.p[2]] = "Report"
	f.run:_resolveVote(lane)
	check(f.run.anomaliesReported == 1, "majority Report records one team anomaly")
	f.run:_resolveVote(lane)
	check(f.run.anomaliesReported == 1, "repeated resolver cannot double count a report")
	order.Step, order.VotePurpose = "Evidence", "Software"
	order.VoteEndsAt, order.Votes = f.h.time + 20, { [f.p[1]] = "Report", [f.p[2]] = "Report" }
	f.run:_resolveVote(lane)
	check(f.run.anomaliesReported == 1, "software install vote never counts as an anomaly report")
	f.run.repaired = 3
	f.h.time += 125
	local expectedTime = math.floor(f.h.time - f.run.players[f.p[1]].WorkStartedAt)
	f.run:Finish("Dawn")
	local snapshot = f.run:Snapshot(f.p[1])
	check(
		snapshot.CompleteStats.Nights == 1
			and snapshot.CompleteStats.PhonesFixed == 3
			and snapshot.CompleteStats.AnomaliesReported == 1
			and snapshot.CompleteStats.TimeWorked == expectedTime,
		"successful shift freezes server team totals and the employee's clocked-in time"
	)
	snapshot.CompleteStats.PhonesFixed = 999
	f.h.time += 60
	check(
		f.run:Snapshot(f.p[1]).CompleteStats.PhonesFixed == 3
			and f.run:Snapshot(f.p[1]).CompleteStats.TimeWorked == expectedTime,
		"result snapshots are copies and result-screen waiting adds no work time"
	)
	check(f:act("Replay", f.p[1]), "first survivor readies up")
	f.run:Tick()
	check(f.run.phase == "Results", "NextNight still waits for the other survivor")
	check(f:act("Replay", f.p[2]), "second survivor readies up")
	f.run:Tick()
	check(
		f.run.night == 2 and f.run.anomaliesReported == 0 and not f.run:Snapshot(f.p[1]).CompleteStats,
		"next night clears only the finished-shift summary and report counter"
	)
	check(f:act("ClockIn", f.p[1]), "new night can clock in")
	f.h.time += 10
	f.run:Finish("Dawn")
	check(
		f.run:Snapshot(f.p[1]).CompleteStats.TimeWorked == 10,
		"shift time excludes all previous nights and intermission"
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
	loss.Nights.Text == "2"
		and loss.PhonesFixed.Text == "PHONES FIXED    7"
		and loss.TimeWorked.Text == "TIME WORKED    02:05",
	"night count is a bare value and other loss statistics preserve formatting"
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

-- Briefing has one acknowledgement and bounded, colored copy in the authored text box.
do
	local card = node("ImageLabel", "Briefing", frames)
	local section = node("TextLabel", "Section1", card)
	section.RichText = false
	node("TextLabel", "Title", card)
	local understood = node("ImageButton", "Understood", card)
	local modes = h:load("src/GServer/Session/ModeRules.luau")
	local acknowledged, briefPanels, briefState = 0, nil, {}
	briefPanels = Module.new(gui, {
		userId = 123,
		assets = assets,
		tweens = tweens,
		reduced = function()
			return false
		end,
		introUnderstood = function()
			acknowledged += 1
			briefPanels:Update(briefState, false, false, false)
		end,
	})
	local originalSize, originalPosition = card.Size, card.Position
	for _, mode in ipairs({ "Story", "Endless" }) do
		for night = 1, 5 do
			briefState = { Intro = modes.Intro(mode, night) }
			local _, _, bound = briefPanels:Update(briefState, false, false, true)
			finish()
			local plain = section.Text:gsub("<[^>]+>", "")
			local _, words = plain:gsub("%S+", "")
			check(
				bound and card.Visible and card.Title.Text == briefState.Intro.Title and plain == briefState.Intro.Text,
				"single Section1 retains the complete nightly briefing"
			)
			check(
				words >= 25 and words <= 55 and section.Text:find('<font color="', 1, true),
				"every Story/Endless briefing stays compact and uses colored emphasis"
			)
		end
	end
	check(
		section.TextScaled and section.RichText and card.Size == originalSize and card.Position == originalPosition,
		"briefing enables rich text without changing text scaling or authored open geometry"
	)
	local buttons = 0
	for _, child in ipairs(card:GetDescendants()) do
		if child:IsA("GuiButton") then
			buttons += 1
		end
	end
	check(buttons == 1, "briefing never creates extra buttons or replacement layouts")
	briefPanels:Update(briefState, true, false, true)
	understood.Activated:Fire()
	check(acknowledged == 0 and not understood.Active, "busy briefing cannot acknowledge early")
	briefPanels:Update(briefState, false, false, true)
	understood.Activated:Fire()
	understood.Activated:Fire()
	check(acknowledged == 1 and briefPanels:IsOpen(), "one acknowledgement retains input through exit tween")
	finish()
	check(not card.Visible, "understood finishes the downward exit")
	briefState.Intro = { Title = "ESCAPING", Text = "<b>Unauthored</b> & Clock in" }
	briefPanels:Update(briefState, false, false, true)
	check(
		section.Text:find("&lt;b&gt;Unauthored&lt;/b&gt; &amp;", 1, true),
		"server copy is escaped before owned color markup"
	)
	briefPanels:Update(briefState, false, false, false)
	briefPanels:Update(briefState, false, false, true)
	finish()
	check(card.Visible, "cancelled exit cannot hide a reopened briefing")
	briefPanels:Destroy()
	understood.Activated:Fire()
	check(
		acknowledged == 1 and not section.RichText and section.Text == "authored" and section.TextScaled,
		"briefing cleanup restores authored rich text/text and disconnects its button"
	)
	card:Destroy()
end

-- New card drives the real station controller; the old Timecard hierarchy is absent.
do
	local card = node("ImageLabel", "ClockIn", frames)
	local start = node("ImageButton", "Start", card)
	local back = node("ImageButton", "Back", card)
	node("ImageLabel", "Mugshot", card)
	for _, name in ipairs({ "Night", "EmployeeNumber", "EmployeeName", "Department", "Title" }) do
		node("TextLabel", name, card)
	end
	local employee = h:player(501)
	employee.Name, employee.DisplayName = "ActualUsername", "DifferentDisplayName"
	local character = node("Model", "Character")
	employee.Character = character
	local root = node("Part", "HumanoidRootPart", character)
	root.Position = Roblox.Vector3.zero
	local human = node("Humanoid", "Humanoid", character)
	human.Health, human.MoveDirection = 100, Roblox.Vector3.zero
	local world = node("Workspace", "Workspace")
	world.GetServerTimeNow = function()
		return h.time
	end
	local container = node("Folder", "Prototype", world)
	local shop = node("Model", "DPU_Prototype", container)
	local station = node("Part", "Timeclock", shop)
	station.Position = Roblox.Vector3.zero
	local input, pendingRequest, requests = { InputBegan = Signal() }, false, {}
	local controller, clockPanels
	local clockState = {
		Alive = true,
		NeedsClockIn = true,
		Phase = "Tutorial",
		Night = 3,
		Focus = { Id = "card1", Station = "Timeclock", EndsAt = h.time + 30 },
	}
	clockPanels = Module.new(gui, {
		player = employee,
		userId = employee.UserId,
		tweens = tweens,
		assets = {
			CreateEditableImageAsync = function()
				error("unavailable")
			end,
		},
		reduced = function()
			return false
		end,
		clockAction = function(action)
			controller:Submit(action)
		end,
		understood = function() end,
		act = function() end,
	})
	controller = h:load("src/GClient/Interaction/StationInteractionController.luau").new({
		panels = clockPanels,
		player = employee,
		workspace = world,
		tweens = tweens,
		input = input,
		render = { RenderStepped = Signal() },
		reduced = function()
			return false
		end,
		menuOpen = function()
			return false
		end,
		isBusy = function()
			return pendingRequest
		end,
		send = function(action, payload)
			table.insert(requests, { action, payload })
			pendingRequest = true
			clockPanels:Update(clockState, true, false)
		end,
	}, gui)
	controller:Update(clockState, false)
	check(
		card.Visible and card.EmployeeNumber.Text == "----" and not start.Active,
		"identity replication delay never invents a temporary employee number"
	)
	start.Activated:Fire()
	check(#requests == 0, "Start waits for the server-owned employee identity")
	employee:SetAttribute("DPU_EmployeeNumber", 4862)
	controller:Update(clockState, false)
	finish()
	check(
		card.EmployeeName.Text == employee.Name
			and card.EmployeeNumber.Text == "4862"
			and card.Night.Text == "3"
			and card.Department.Text == "authored",
		"new card uses username, saved identity and server night without changing authored department"
	)
	check(clockPanels:IsOpen() and card.EmployeeName.TextScaled, "clock card owns pointer and preserves text styling")
	start.Activated:Fire()
	start.Activated:Fire()
	check(
		#requests == 1 and requests[1][1] == "ClockIn" and requests[1][2].FocusId == "card1",
		"Start submits exactly one request with the current server focus"
	)
	clockState.Focus, clockState.NeedsClockIn, clockState.NeedsRules = nil, false, true
	pendingRequest = false
	clockPanels:Update(clockState, false, true)
	controller:Update(clockState, false)
	finish()
	check(not card.Visible and rules.Visible, "successful clock-in replaces card with tonight's rules")
	clockState.NeedsRules, clockState.NeedsClockIn = false, true
	clockState.Focus = { Id = "card2", Station = "Timeclock", EndsAt = h.time + 30 }
	clockPanels:Update(clockState, false, false)
	controller:Update(clockState, false)
	back.Activated:Fire()
	back.Activated:Fire()
	check(
		#requests == 2 and requests[2][1] == "CloseFocus" and requests[2][2].FocusId == "card2",
		"Back closes once without stamping the timecard"
	)
	check(card.Visible and clockPanels:IsOpen(), "exit tween retains modal ownership")
	finish()
	check(not card.Visible, "Back finishes below the authored position and hides the card")
	pendingRequest = false
	controller:Update(clockState, false)
	check(not card.Visible, "stale dismissed focus does not reopen card")
	clockState.Focus = { Id = "card3", Station = "Timeclock", EndsAt = h.time + 30 }
	clockPanels:Update(clockState, false, false)
	controller:Update(clockState, false)
	clockState.Alive = false
	controller:Update(clockState, false)
	finish()
	check(not card.Visible, "death interrupts clock-in presentation")
	controller:Destroy()
	clockPanels:Destroy()
	h:drain()
	start.Activated:Fire()
	check(
		#requests == 2 and card.EmployeeName.Text == "authored",
		"teardown disconnects clock controls and restores authored text"
	)
end

-- New completion card keeps its static labels and displays values only.
do
	local card = node("ImageLabel", "ShiftComplete", frames)
	local nextNight = node("ImageButton", "NextNight", card)
	local returnLobby = node("ImageButton", "Lobby", card)
	for _, name in ipairs({ "Nights", "AnomaliesSpotted", "PhonesFixed", "TimeWorked", "Label" }) do
		node("TextLabel", name, card)
	end
	local sent, completion = {}, nil
	local completed = {
		Phase = "Results",
		Outcome = "Survived",
		ContinueRun = true,
		CompleteStats = { Nights = 1, AnomaliesReported = 2, PhonesFixed = 4, TimeWorked = 125 },
	}
	completion = Module.new(gui, {
		userId = 123,
		assets = assets,
		tweens = tweens,
		reduced = function()
			return false
		end,
		act = function(action)
			table.insert(sent, action)
			completion:Update(completed, true, false, false)
		end,
	})
	local _, _, _, showing = completion:Update(completed, false, false, false)
	finish()
	check(
		showing
			and card.Visible
			and frames.BackgroundTransparency == 0.2
			and not nextNight.Active
			and not returnLobby.Active,
		"successful completion opens authored card while pending settlement keeps actions disabled"
	)
	check(
		card.Nights.Text == "1"
			and card.AnomaliesSpotted.Text == "2"
			and card.PhonesFixed.Text == "4"
			and card.TimeWorked.Text == "02:05"
			and card.Label.Text == "authored",
		"completion fields show only values and retain static labels"
	)
	completed.CanReplay, completed.CanReturn = true, true
	completion:Update(completed, false, false, false)
	nextNight.Activated:Fire()
	nextNight.Activated:Fire()
	check(#sent == 1 and sent[1] == "Replay", "NextNight sends exactly one validated replay intent")
	completed.Replay = true
	completion:Update(completed, false, false, false)
	check(
		not nextNight.Active and returnLobby.Active,
		"readied survivor can still return to Lobby while waiting for team"
	)
	returnLobby.Activated:Fire()
	returnLobby.Activated:Fire()
	check(#sent == 2 and sent[2] == "ReturnLobby", "completion Lobby uses existing travel request once")
	completion:Update({ Phase = "Tutorial" }, false, false, false)
	finish()
	check(
		not card.Visible and frames.BackgroundTransparency == 1,
		"next shift dismisses completion and restores background"
	)
	completion:Destroy()
	nextNight.Activated:Fire()
	check(
		#sent == 2 and card.PhonesFixed.Text == "authored",
		"completion teardown disconnects buttons and restores text"
	)
	card:Destroy()
end

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
