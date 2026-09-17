local Harness = require("./Harness")
local Fixture = require("./ShiftFixture")
local total = 0
local function check(value, label)
	assert(value, label)
	total += 1
end
local function fixture(count)
	local f = Fixture(count or 1, check)
	f.c.ShopDirection, f.c.Events, f.c.OutsideRisk.Enabled = true, {}, false
	f.manualPuzzles = true
	f:start()
	return f
end
local h = Harness.Environment()
local Phone = h:load("src/GServer/Repair/PhoneSoftware.luau")
local Records = h:load("src/GServer/Story/DeviceRecords.luau")
local Policy = h:load("src/GServer/Story/GovernmentService.luau")
local Puzzles = h:load("src/GServer/Repair/RepairPuzzles.luau")
check(h:load("src/GServer/Session/GameConfig.luau").ShopDirection, "new direction is production default")
local function device(fault, night, required)
	return Phone.New({
		Customer = "Test customer",
		Fault = fault,
		Ticket = "100015",
		EmployeeId = "17",
		UpdateRequired = required,
		ShopPolicy = Policy.Current(night),
		PuzzleSeed = 1,
		Evidence = { Id = "case", Message = "PRIVATE CLUE", Discovery = "PRIVATE RECOVERY" },
		DiscoveryNumber = "041984",
	}, night)
end
local function press(p, n, now)
	local ok, done, code = Phone.Input(p, n, p.Revision, now or 0)
	check(ok, "phone input " .. n .. " / " .. p.Page .. " / " .. tostring(code))
	return done
end
do
	for fault, page in pairs({ Speaker = "RestoredRecording", Battery = "Ringing", Keypad = "RestoredKeypad" }) do
		local p = device(fault, 1, false)
		check(p.Page == page, "repaired component determines discovery")
		local snapshot = Phone.Snapshot(p)
		check(
			not snapshot.Hint:find("PRIVATE") and snapshot.Evidence == nil and snapshot.Policy == nil,
			"initial page reveals no unvisited private records"
		)
		press(p, 2)
		check(press(p, 6), "unmarked phone can finish without software or snooping")
		check(p.Reads == 0 and not p.Discovered, "ignoring discovery remains a valid repair")
	end
	local p = device("Speaker", 2, true)
	press(p, 1)
	check(p.Discovered and p.Reads == 1, "fixed speaker opens optional evidence")
	press(p, 1)
	check(not Phone.Input(p, 6, p.Revision, 0), "red marked phone requires update or team exception")
	press(p, 1)
	press(p, 2)
	check(Phone.Snapshot(p).Hint:find("Microphone"), "permission preview reveals surveillance")
	press(p, 1)
	press(p, 1, 1)
	check(not Phone.Input(p, 1, p.Revision, 2), "server time prevents instant installation")
	press(p, 1, 3)
	press(p, 4)
	press(p, 5)
	check(Phone.Snapshot(p).Hint:find("EMPLOYEE 17"), "service records identify current technician")
	press(p, 1)
	press(p, 1, 10)
	check(#p.AccessLog == 1 and p.Violations == 1, "prohibited recovery records employee and one violation")
	check(not Phone.Input(p, 1, p.Revision, 15), "recovery deadline cannot be bypassed")
	press(p, 2)
	press(p, 5)
	press(p, 1)
	press(p, 1, 16)
	check(
		p.Recovered and #p.AccessLog == 1 and p.Violations == 1,
		"leaving and reopening retains recovery deadline and trace"
	)
	check(Phone.Snapshot(p).Hint == "PRIVATE RECOVERY", "only opened recovered record is exposed")
	check(p.KnownNumbers["041984"] == "Archive", "archive contact unlocks after actual recovery")
	check(not Phone.Input(p, 1, p.Revision - 1, 20), "old revisions cannot act on a new page")
	check(not Phone.Input(p, 0 / 0, p.Revision, 20), "NaN input rejected")
end
do
	for _, fault in ipairs({ "Battery", "Speaker", "Keypad" }) do
		local p = Puzzles.New("Diagnose", fault, 10, 4, 0, true, false, true)
		check(p.Kind == "Screws" and p.TurnsRequired == 1, "diagnosis starts with casing screws")
		check(not Puzzles.Input(p, 11, p.Revision, 0), "cannot remove cover before screws")
		for i = 1, 4 do
			check(Puzzles.Input(p, i, p.Revision, i), "remove each screw once")
		end
		check(p.DeviceStage == "RemoveCover", "cover follows screws")
		check(not Puzzles.Input(p, 11, 0, 5), "stale screw revision cannot remove cover")
		check(Puzzles.Input(p, 11, p.Revision, 5), "remove cover")
		check(p.DeviceStage == "RemoveBattery", "battery follows cover")
		check(Puzzles.Input(p, 11, p.Revision, 6), "slide battery out")
		check(
			p.Kind == "Probes" and Puzzles.Snapshot(p).RoutineFault == nil,
			"diagnosis starts only after disassembly without leaking fault"
		)
		p = Puzzles.New("Repair", fault, 10, 4, 0, true, false, true)
		check(p.Kind == "Screen" and p.ExchangeOnly, "repair exchanges diagnosed component without reopening screws")
		if fault ~= "Battery" then
			local ok, done = Puzzles.Input(p, 11, p.Revision, 5)
			check(ok and not done and p.Phase == 2, "remove failed component")
		end
		local ok, done = Puzzles.Input(p, 11, p.Revision, 6)
		check(ok and done, "fit replacement; battery was already removed during diagnosis")

		local projected = Puzzles.Snapshot(p)
		check(projected.Seed == nil and projected.Pending == nil, "repair projection omits private puzzle state")
	end
end
local function act(f, action, player, payload)
	f:advance(0.6)
	local ok, code = f:act(action, player, payload)
	check(ok, action .. ": " .. tostring(code))
end
local function solve(f)
	local lane = f.run.stations.Bench
	local work = lane.work
	local moves = 0
	while lane.work == work and work.Puzzle do
		moves += 1
		assert(moves < 35, "short routine must terminate")
		local p, move = work.Puzzle, nil
		if p.Kind == "Probes" then
			move = p.Progress < 3 and table.find(p.Tested, false) or p.Answer + 3
		elseif p.Kind == "Screws" then
			move = table.find(p.Turns, 0)
		elseif p.Kind == "Screen" then
			move = 11
		elseif p.Kind == "Stamp" then
			move = 1
		elseif p.Kind == "Phone" then
			if p.Page == "Home" then
				move = p.UpdateRequired and not p.Installed and 1 or 6
			elseif p.Page == "Program" then
				move = p.Installed and 4 or 1
				if p.InstallAt then
					f.h.time = math.max(f.h.time, p.InstallAt)
				end
			else
				move = 2
			end
		else
			error("Unexpected routine: " .. p.Kind)
		end
		act(
			f,
			"PuzzleInput",
			nil,
			{ WorkId = work.Id, OrderId = work.OrderId, Move = move, PuzzleRevision = p.Revision }
		)
	end
	f:advance(f.c.FittingSeconds + 0.6)
	return moves
end
do
	local f = fixture()
	local order = f.run.stations.Bench.order
	act(f, "TakeOrder")
	local moves = 0
	for _, action in ipairs({ "Diagnose", "Collect", "Repair", "Secure", "Install", "Test" }) do
		act(f, action)
		if action ~= "Collect" then
			moves += solve(f)
		end
	end
	check(
		order.Step == "ReadyForPickup" and moves <= 24,
		"full production routine reaches pickup in a bounded set of meaningful moves"
	)
	f:pickup()
	act(f, "Return")
	check(
		f.run.phase == "Night" and f.run.repaired == 1 and f.run.government.Trust == 1,
		"normal return opens shop and audits required update once"
	)
	Policy.Audit(f.run, order)
	check(f.run.government.Trust == 1, "repeat audit cannot farm government trust")
	f:advance(19)
	check(f.run.stations.Bench.order ~= nil, "next solo order arrives after quiet gap")
	f.run.stations.Bench2.nextOrder = f.h.time
	f.run:_tickRepair(f.run.stations.Bench2, f.h.time)
	check(f.run.stations.Bench2.order == nil, "solo cannot spawn second job by selecting second bench")
	local snapshot = f.run:Snapshot(f.p[1])
	check(
		snapshot.Rules:find("RED service sticker") and not snapshot.Rules:find("TONIGHT'S RULES 01"),
		"one current directive replaces legacy pile of regulations"
	)
end
do
	for _, choice in ipairs({ "Report", "Hide", "Investigate" }) do
		local f = fixture(2)
		f.run.stations.Bench.order = nil
		f.run.serial, f.run.nextIntakeAt = 2, 0
		f.run:_newOrder(false)
		local o = f.run.stations.Bench.order
		check(o.Customer == "Mara" and o.Fault == "Speaker", "case begins with understandable speaker repair")
		o.Step, o.Votes, o.VotePurpose = "Evidence", {}, "Evidence"
		f.run:_resolveVote(f.run.stations.Bench)
		f.h.time = o.VoteEndsAt + 0.1
		f.run:_resolveVote(f.run.stations.Bench)
		check(o.Step == "Evidence" and #f.run.decisions == 0, "no votes at deadline never reports a civilian")
		o.Votes[f.p[1]] = choice
		f.run:_resolveVote(f.run.stations.Bench)
		check(o.Step == "Evidence", "one of two workers cannot decide alone")
		o.Votes[f.p[2]] = choice
		f.run:_resolveVote(f.run.stations.Bench)
		check(f.run.customerStory.Choice == choice and #f.run.decisions == 1, "majority records one story consequence")
		f.run:_start(true)
		f.run.serial, f.run.nextIntakeAt = 2, 0
		f.run:_newOrder(false)
		local nextOrder = f.run.stations.Bench.order
		check(nextOrder.DeviceSerial == "MW-041", "same device returns across nights")
		check(
			nextOrder.Customer == (choice == "Report" and "Officer Vale" or "Mara"),
			"choice changes returning customer"
		)
		if choice == "Report" then
			check(
				f.run:Snapshot(f.p[2]).Dialogue ~= nil and f.run:Snapshot(f.p[1]).Dialogue == nil,
				"only one coworker hears warning before officer arrival"
			)
		end
	end
end
do
	local f = fixture(2)
	local o = f.run.stations.Bench.order
	o.Phone = device("Speaker", 3, false)
	local p = o.Phone
	act(f, "OpenFax")
	local fax = f.run.players[f.p[1]].Fax
	local payload = { FaxId = fax.Id, Ticket = p.ContactNumber }
	f:advance(0.6)
	check(not f:act("DialTicket", nil, payload), "cannot guess unrevealed private contact")
	press(p, 2)
	press(p, 3)
	act(f, "DialTicket", nil, payload)
	check(p.Calls == 1 and p.Violations == 1 and f.run.ruleBreaks == 1, "physical call logs curfew violation")
	local caller, coworker = f.run:Snapshot(f.p[1]), f.run:Snapshot(f.p[2])
	check(
		caller.Dialogue.Text:find("still at work") and caller.Fax.CallSerial == 1,
		"caller receives line and receiver animation acknowledgment"
	)
	check(
		not coworker.Dialogue or not coworker.Dialogue.Text:find("still at work"),
		"private caller content is not broadcast"
	)
	act(f, "DialTicket", nil, payload)
	check(p.Calls == 1 and f.run.ruleBreaks == 1, "repeated number does not farm records or penalties")
	f.near[f.p[1]] = "Bench"
	f:advance(0.6)
	check(not f:act("DialTicket", nil, payload), "private calls still enforce physical telephone range")
end
do
	for _, count in ipairs({ 1, 2 }) do
		local f = fixture(count)
		act(f, "TakeOrder")
		act(f, "Diagnose")
		local work = f.run.stations.Bench.work
		f.run.phase, f.run.nightAt = "Night", f.h.time
		f.c.Events = { { At = 0, Kind = "Inspection", Warning = "Show repair papers", Duration = 30 } }
		f.run:_tickDisturbance(f.h.time)
		local s = f.run:Snapshot(f.p[1])
		check(s.ArrivalsPaused and s.WorkBlocked == (count == 1), "inspection pacing scales to living workers")
		check(
			(f.run.stations.Bench.work == work) == (count == 2),
			"cooperative inspection retains active repair; solo pauses"
		)
		if count == 2 then
			act(
				f,
				"PuzzleInput",
				nil,
				{ WorkId = work.Id, OrderId = work.OrderId, Move = 1, PuzzleRevision = work.Puzzle.Revision }
			)
			check(work.Puzzle.Progress == 1, "real server input continues during cooperative inspection")
		end
		f.run:_newOrder(false, f.run.stations.Bench2)
		check(f.run.stations.Bench2.order == nil, "inspection blocks new customer intake")
	end
end
do
	local f = fixture()
	f.run.government.Trust = 2
	f.run:_start(true)
	check(f.run.stock.Battery == 5 and f.run.stock.Speaker == 5, "compliance pays supplies on following night")
	check(f.run.policy.RecoveryForbidden and not f.run.policy.CallsForbidden, "next night changes one directive")
	f.run.phase, f.run.nightAt = "Night", f.h.time
	f.c.Events = { { At = 0, Kind = "Blackout", Warning = "Power cut", Duration = 10 } }
	f.run:_tickDisturbance(f.h.time)
	check(f.run.event.Kind == "Knocks" and f.run.event.Minor, "priority power replaces outage with quiet anomaly")
	f.run.government.Discrepancies = 1
	local before = f.run.suspicion
	check(
		Policy.Inspection(f.run):find("do not match") and f.run.suspicion > before,
		"hidden evidence produces inspection consequences"
	)
end
do
	local f = fixture(2)
	f.run.stations.Bench.order = nil
	f.run.serial, f.run.nextIntakeAt = 2, 0
	f.run:_newOrder(false)
	local order = f.run.stations.Bench.order
	order.Phone = device("Speaker", 1, true)
	order.Phone.Discovered, order.Phone.RequestSkip = true, true
	order.Step, order.Votes, order.VotePurpose = "Evidence", {}, "Software"
	f.run:_resolveVote(f.run.stations.Bench)
	order.Votes[f.p[1]], order.Votes[f.p[2]] = "Hide", "Hide"
	f.run:_resolveVote(f.run.stations.Bench)
	check(
		order.Phone.SoftwareDecisionResolved and not order.Phone.DecisionResolved and order.Step == "Install",
		"software exception does not consume separate evidence decision"
	)
	check(f.run.customerStory.Choice == nil, "software exception does not decide missing-worker story")
	order.Phone.RequestSkip = false
	f.run:_completeWork({ Action = "Install", Player = f.p[1], OrderId = order.Id }, f.run.stations.Bench)
	check(
		order.Step == "Evidence" and order.VotePurpose == "Evidence",
		"finishing discovered phone still asks for evidence decision"
	)
end
do
	local f = fixture(2)
	act(f, "TakeOrder")
	act(f, "Diagnose")
	f.run.phase, f.run.nightAt = "Night", f.h.time
	f.c.Events = { { At = 0, Kind = "Inspection", Warning = "Papers", Duration = 30 } }
	f.run:_tickDisturbance(f.h.time)
	f.p[2].Parent = nil
	f.run:_tickDisturbance(f.h.time)
	check(
		f.run.stations.Bench.order.PausedAt ~= nil and f.run.stations.Bench.work == nil,
		"losing coworker during audit safely changes to solo pacing"
	)
end
do
	local f = fixture()
	f.run.stations.Bench.order = nil
	f.run.serial, f.run.nextIntakeAt = 2, 0
	f.run:_newOrder(false)
	f.run.customerStory.Choice = "Report"
	for chapter = 2, 5 do
		f.run:_start(true)
		f.run.serial, f.run.nextIntakeAt = 2, 0
		f.run:_newOrder(false)
		local order = f.run.stations.Bench.order
		check(
			order.CaseId == "missing_worker" and order.DeviceSerial == "MW-041",
			"connected case survives each chapter"
		)
		if chapter == 2 then
			check(
				order.CustomerId == "vale_worker" and order.ArrivesAt >= f.h.time + 12,
				"solo warning precedes officer arrival"
			)
		elseif chapter == 3 then
			check(
				order.Fault == "Battery" and order.Evidence.Id == "worker_transfer",
				"third shift connects transfer recording"
			)
		elseif chapter == 4 then
			check(order.Fault == "Keypad" and order.UpdateRequired, "courier follows all-devices directive")
		else
			check(order.Evidence.Id == "worker_final_copy", "final case ties repairs to the archive")
		end
	end
end
do
	local Roblox = require("@lune/roblox")
	local Physical = h:load(
		"src/GClient/Repair/PhysicalRepairTasks.luau",
		nil,
		{ Color3 = Roblox.Color3, Vector3 = Roblox.Vector3 }
	)
	local p = Puzzles.New("Secure", "Battery", 1, 1, 0, false, true, true)
	Puzzles.Input(p, 11, p.Revision, 0)
	Puzzles.Input(p, 1, p.Revision, 1)
	local nodes, hint = Physical.Build(Puzzles.Snapshot(p))
	check(
		nodes[1].Disabled and not nodes[2].Disabled and hint:find("once"),
		"physical screw control matches one-turn server contract"
	)
	local q = Puzzles.New("Repair", "Speaker", 1, 1, 0, false, true, true)
	for i = 1, 4 do
		Puzzles.Input(q, i, q.Revision, i)
	end
	Puzzles.Input(q, 11, q.Revision, 5)
	local parts = Physical.Build(Puzzles.Snapshot(q))
	check(parts[2].Text == "SPEAKER", "physical replacement labels identify diagnosed component")
end
print(
	string.format(
		"PASS: %d integrated shop direction, device privacy, simple repair, pacing and consequence checks.",
		total
	)
)
