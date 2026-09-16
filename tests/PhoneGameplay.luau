local Harness = require("./Harness")
local Fixture = require("./ShiftFixture")
local total = 0
local function check(value, message)
	assert(value, message)
	total += 1
end
local h = Harness.Environment()
local Phone = h:load("src/GServer/Customers/PhoneSession.luau")
local order = {
	Customer = "Nina",
	PuzzleSeed = 1,
	Evidence = { Id = "private_evidence", Message = "PRIVATE MESSAGE", Discovery = "PRIVATE ARCHIVE" },
}
do
	local p = Phone.New(order, 2)
	local now = 100
	local function press(n)
		local ok, solved = Phone.Input(p, n, p.Revision, now)
		check(ok, "valid phone input on " .. p.Page)
		return solved
	end
	local snapshot = Phone.Snapshot(p)
	check(
		snapshot.Evidence == nil and snapshot.Seen == nil and not snapshot.Hint:find("PRIVATE"),
		"home snapshot hides all private content"
	)
	check(not Phone.Input(p, 5, p.Revision, now), "cannot finish without program or team exception")
	press(2)
	press(2)
	check(
		Phone.Snapshot(p).Hint == "PRIVATE MESSAGE" and p.Discovered and p.Reads == 1 and p.Violations == 1,
		"explicit read discloses one clue and logs prohibited access"
	)
	press(1)
	press(2)
	check(p.Reads == 1 and p.Violations == 1, "repeated reading cannot inflate unique-record counts")
	press(2)
	press(1)
	press(1)
	check(p.InstallAt == 102 and not p.Installed, "installation starts with server deadline")
	check(not Phone.Input(p, 1, p.Revision, 101), "client cannot finish install early")
	now = 103
	press(1)
	check(p.Installed and p.Progress == 1, "explicit check after server deadline completes program")
	press(2)
	check(not Phone.Input(p, 6, p.Revision, now), "cannot pretend to skip an installed program")
	press(3)
	press(1)
	press(2)
	check(
		p.PassMessage and p.Calls == 1 and p.Violations == 1,
		"permitted call carries a message without a call violation"
	)
	press(1)
	press(3)
	check(press(5), "phone completes after installation and optional browsing")
	check(not Phone.Input(p, 1, p.Revision - 1, now), "stale page input rejected")
	check(not Phone.Input(p, 99, p.Revision, now), "unknown control rejected")
end
do
	local p = Phone.New({ Customer = "Ordinary", PuzzleSeed = 5 }, 3)
	check(p.Page == "Ringing", "occasional customer phone rings")
	check(
		Phone.Input(p, 1, 0, 0) and p.Answered == 1 and p.Violations == 1,
		"answering private call follows nightly rule"
	)
	check(Phone.Snapshot(p).Hint:find("Who is speaking"), "answered call has readable dialogue")
	local ignored = Phone.New({ Customer = "Ordinary", PuzzleSeed = 5 }, 3)
	Phone.Input(ignored, 2, 0, 0)
	check(
		ignored.Page == "Home" and ignored.Answered == 0 and ignored.Violations == 0,
		"ignore ends call without snooping"
	)
end
-- Full authority path: two-person choice, ownership, interruptions and continued phone access.
do
	local f = Fixture(2, check)
	f:start()
	f:repair()
	f.c.Events = {}
	f.run:_newOrder(false)
	local lane, p, q = f.run.stations.Bench, f.p[1], f.p[2]
	lane.order.Step, lane.order.Evidence, lane.order.PuzzleSeed = "Install", order.Evidence, 1
	f:advance(0.6)
	check(f:act("Install", p), "operator opens usable customer phone")
	local first = lane.work
	local function press(n)
		f:advance(0.6)
		return f:act(
			"PuzzleInput",
			p,
			{ OrderId = lane.order.Id, WorkId = lane.work.Id, Move = n, PuzzleRevision = lane.work.Puzzle.Revision }
		)
	end
	check(f.run:Snapshot(q).Work.Puzzle == nil, "teammate cannot inspect operator's unopened phone pages")
	check(
		not f:act(
			"PuzzleInput",
			q,
			{ OrderId = lane.order.Id, WorkId = first.Id, Move = 2, PuzzleRevision = first.Puzzle.Revision }
		),
		"teammate cannot send operator's phone inputs"
	)
	check(press(2) and press(2), "operator opens actual private message")
	local reads = f.run.phoneReads
	f:act("Stand", p)
	f:advance(0.6)
	check(f:act("Install", p) and lane.work.Id ~= first.Id, "handoff/reopen has fresh work identity")
	check(
		lane.work.Puzzle.Discovered and f.run.phoneReads == reads,
		"closing keeps discovery without counting a new read"
	)
	check(
		not f:act(
			"PuzzleInput",
			p,
			{ OrderId = lane.order.Id, WorkId = first.Id, Move = 5, PuzzleRevision = first.Puzzle.Revision }
		),
		"old work cannot finish reopened phone"
	)
	check(press(2) and press(6) and press(1), "skip request enters existing team ballot")
	check(
		lane.order.Step == "Evidence" and f.run:Snapshot(q).Vote.Purpose == "Software",
		"teammates see software consequences"
	)
	check(f:act("Vote", p, { OrderId = lane.order.Id, Choice = "Hide" }), "first staff votes")
	check(lane.order.Step == "Evidence", "one staff cannot skip government program alone")
	check(f:act("Vote", q, { OrderId = lane.order.Id, Choice = "Hide" }), "second staff votes")
	check(
		lane.order.Step == "Test" and lane.order.Phone.SkipApproved and not lane.order.Phone.Installed,
		"team refusal preserves uninstalled state and allows testing"
	)
	check(f.run.ruleBreaks == 1 and f.run.suspicion == 20, "software refusal affects government suspicion once")
	check(f.run.answered == 0, "customer phone never triggers disconnected-phone ending counter")
	check(
		not f:act("Vote", q, { OrderId = lane.order.Id, Choice = "Report" }),
		"settled program decision cannot be replayed"
	)
end
do
	local f = Fixture(1, check)
	f:start()
	f:repair()
	f.c.Events = {}
	f.run:_newOrder(false)
	local lane = f.run.stations.Bench
	lane.order.Step, lane.order.Evidence, lane.order.PuzzleSeed = "Install", order.Evidence, 1
	f:advance(0.6)
	check(f:act("Install"), "start evidence phone")
	f:solve()
	check(lane.order.Step == "Evidence", "opening clue before finishing triggers evidence choice")
	check(f:act("Vote", nil, { OrderId = lane.order.Id, Choice = "Investigate" }), "solo investigation resolves")
	check(
		lane.order.Step == "Install" and lane.order.Phone.Page == "Archive",
		"investigation returns to actual recovered phone record"
	)
	local reads = f.run.phoneReads
	f:advance(0.6)
	check(f:act("Install"), "reopen recovered record")
	check(f.run.phoneReads == reads + 1, "opening recovered archive logs a new record")
	check(f.run:Snapshot(f.p[1]).Work.Puzzle.Hint == "PRIVATE ARCHIVE", "investigation reveals current record only")
	f:solve()
	check(lane.order.Step == "Test" and #f.run.decisions == 1, "finishing investigation cannot create endless votes")
end
-- Browsing is optional even on a clue-bearing device; refusal approval cannot bypass installation.
for _, requestSkip in ipairs({ false, true }) do
	local f = Fixture(1, check)
	f:start()
	f:repair()
	f.c.Events = {}
	f.run:_newOrder(false)
	local lane = f.run.stations.Bench
	lane.order.Step, lane.order.Evidence, lane.order.PuzzleSeed = "Install", order.Evidence, 1
	f:advance(0.6)
	check(f:act("Install"), "open phone without reading")
	local function press(n)
		f:advance(0.6)
		return f:act(
			"PuzzleInput",
			nil,
			{ OrderId = lane.order.Id, WorkId = lane.work.Id, Move = n, PuzzleRevision = lane.work.Puzzle.Revision }
		)
	end
	if requestSkip then
		check(press(6) and press(1), "ask team before omitting software")
		check(
			f:act("Vote", nil, { OrderId = lane.order.Id, Choice = "Report" }),
			"team can require the government program"
		)
		check(
			lane.order.Step == "Install" and not lane.order.Phone.Installed,
			"approval does not pretend installation happened"
		)
		f:advance(0.6)
		check(f:act("Install"), "reopen mandated installation")
	else
		check(press(1), "open program")
	end
	check(press(1), "start copying")
	f:advance(2)
	check(press(1) and press(2) and press(5), "check installed program and finish")
	check(
		lane.order.Step == "Test" and not lane.order.Phone.Discovered and f.run.phoneReads == 0,
		"unopened clue never forces evidence popup"
	)
end
do
	local Schema = h:load("src/LServer/Core/ProfileSchema.luau")
	local legacy = Schema.Default()
	legacy.Version, legacy.Stats.Credits = 1, nil
	legacy.Stats.ShiftsSurvived, legacy.Progress.HighestShift = 12, 6
	legacy.Progress.Evidence.kept = true
	legacy.RecentOutcomes = { "already_paid" }
	local decoded = Schema.Decode({ Format = 1, Data = legacy })
	check(
		decoded.Version == 2 and decoded.Stats.Credits == 0 and decoded.Progress.HighestShift == 6,
		"v1 migration preserves best completed night and starts wallet at zero"
	)
	check(
		decoded.Stats.ShiftsSurvived == 12
			and decoded.Progress.Evidence.kept
			and decoded.RecentOutcomes[1] == "already_paid",
		"migration preserves lifetime stats, unlocks and deduplication ledger"
	)
	check(legacy.Version == 1 and legacy.Stats.Credits == nil, "migration does not mutate stored input")
	legacy.Settings = nil
	check(Schema.Decode({ Format = 1, Data = legacy }) == nil, "malformed old profile fails closed")
	local future = Schema.Default()
	future.Version = 3
	check(Schema.Decode({ Format = 1, Data = future }) == nil, "future schemas cannot be silently downgraded")
	local malformed = Schema.Default()
	malformed.Stats.Credits = -1
	check(not Schema.Validate(malformed), "negative wallet rejected")
end
do
	local Tasks = h:load("src/GServer/Repair/RepairTasks.luau")
	for seed = 1, 20 do
		local p = Tasks.New("Repair", "Speaker", seed)
		check(#p.Slots == 4 and #p.Placed == 4, "four wire entry and exit ports")
		for i = 1, 4 do
			local ok, solved = Tasks.Input(p, i * 10 + table.find(p.Slots, i), p.Revision, 0)
			check(ok and solved == (i == 4), "only four correctly connected wires finish task")
		end
	end
end
print("PASS: " .. total .. " phone privacy, choices, government policy, migration and four-wire checks.")
