local Fixture = require("./ShiftFixture")
local Harness = require("./Harness")
local total = 0
local function check(value, label)
	assert(value, label)
	total += 1
end
local function fixture(count)
	local f = Fixture(count, check)
	f.c.ClosingSeconds = 60
	f.c.Events = {}
	return f
end
do
	local f = fixture(2)
	f:start()
	check(f.run:Snapshot(f.p[1]).PhaseLabel == "Preparation", "clock-in, rules and training are the preparation phase")
	f:repair()
	check(
		f.run.phase == "Night" and f.run:Snapshot(f.p[1]).PhaseLabel == "Shop open",
		"guided repair opens normal night service"
	)
	f.run:_newOrder(false)
	f:advance(f.c.ArrivalSeconds)
	check(f:act("TakeOrder"), "accept one more phone before closing")
	local lane, phone = f.run.stations.Bench, f.run.stations.Bench.order
	f.h.time = f.run.nightAt + f.c.NightSeconds
	f.run:Tick()
	check(
		f.run.phase == "Closing" and lane.order == phone and not f.records[f.p[1]],
		"closing retains accepted phone without settling early"
	)
	local snapshot = f.run:Snapshot(f.p[1])
	check(
		snapshot.ClosingEndsAt == f.h.time + 60 and snapshot.ClockHour == 6,
		"closing freezes at dawn and publishes grace deadline"
	)
	check(not f:act("TakeOrder"), "closing cannot accept more work")
	local serial = f.run.serial
	f:advance(1)
	check(f.run.serial == serial, "no new customer is spawned while closing")
	-- Complete the remaining real workflow while the grace period is active.
	for _, action in ipairs({ "Diagnose", "Collect", "Repair", "Secure", "Install", "Test" }) do
		f:advance(0.6)
		check(f:act(action), "closing permits existing repair action " .. action)
		if action == "Secure" then
			f:solve()
		else
			f:advance(f.c.WorkSeconds)
		end
	end
	f:pickup()
	f:advance(0.6)
	check(f:act("Return"), "finished phone can be returned during closing")
	check(f.run.phase == "Results" and f.run.reason == "Dawn", "last return closes shift immediately")
	check(#f.records[f.p[1]] == 1 and #f.records[f.p[2]] == 1, "each employee settles once after closing")
	f:advance(20)
	check(#f.records[f.p[1]] == 1, "repeated closing/results ticks cannot duplicate settlement")
end
do
	local f = fixture()
	f:start()
	f:repair()
	f.run:_newOrder(false)
	f:advance(f.c.ArrivalSeconds)
	f:act("TakeOrder")
	local phone = f.run.stations.Bench.order
	f.run.event = { Kind = "Blackout", EndsAt = math.huge }
	phone.PausedAt = f.h.time
	f.run.players[f.p[1]].ScareImpact = { At = f.h.time + 999, Damage = 25 }
	f.h.time = f.run.nightAt + f.c.NightSeconds
	f.run:Tick()
	check(
		f.run.phase == "Closing" and not phone.PausedAt and not f.run.event,
		"dawn resumes paused existing orders and clears hazards"
	)
	check(not f.run.players[f.p[1]].ScareImpact, "unprocessed scare damage is cancelled at closing")
	f:advance(60)
	check(f.run.phase == "Results" and f.run.missed == 1, "deadline settles once and counts unfinished accepted phone")
	check(
		not f.run.stations.Bench.order and not f.run.stations.Bench.work and not f.parts[f.p[1]],
		"closing deadline clears reservations and carried parts"
	)
end
do
	local f = fixture()
	f:start()
	f:repair()
	f.run:_newOrder(false)
	f.h.time = f.run.nightAt + f.c.NightSeconds
	f.run:Tick()
	check(
		f.run.phase == "Results" and f.run.missed == 0,
		"unaccepted arrival leaves without penalising the completed shift"
	)
end
do
	local f = fixture()
	f:start()
	f:repair()
	f.run:_newOrder(false)
	f:advance(f.c.ArrivalSeconds)
	f:act("TakeOrder")
	f.h.time = f.run.nightAt + f.c.NightSeconds
	f.run:Tick()
	local visitor = f.h:player(9)
	f.run:Add(visitor)
	check(f.run.players[visitor].Spectator and not f.run.players[visitor].Alive, "closing late join is a spectator")
	f.run:Damage(f.p[1], 100, "Character died")
	check(f.run.phase == "Results" and f.run.reason == "AllDead", "real character death still ends a closing shift")
end
local h = Harness.Environment()
local config = h:load("src/GServer/Session/GameConfig.luau")
check(
	config.Enabled and config.ClosingSeconds == 60,
	"restored prototype and production closing period enabled by default"
)
print(string.format("PASS: %d preparation, opening, closing and settlement checks.", total))
