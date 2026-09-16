local Harness = require("./Harness")
local h = Harness.Environment()
local Engagement = h:load("src/GServer/Services/EngagementService.luau")
local total = 0
local function check(value, label)
	assert(value, label)
	total += 1
end

local alice, ben = h:player(101), h:player(202)
alice.DisplayName, ben.DisplayName = "Alice", "Ben"
local members = {
	[alice] = { Alive = true },
	[ben] = { Alive = true },
}
Engagement.ResetMember(members[alice], false)
Engagement.ResetMember(members[ben], false)
Engagement.Add(members[alice], "Records", 3)
Engagement.Add(members[alice], "Calls", 2)
Engagement.Add(members[alice], "Repairs", 1)
Engagement.Add(members[ben], "Parts", 4)
Engagement.Add(members[ben], "Repairs", 2)
check(members[alice].Activity.Records == 3, "activity counts server actions")

local report = Engagement.Evaluation(alice, members[alice], 2, 60)
check(report.Employee == "Alice" and report.Status == "UNDER REVIEW", "evaluation uses run state")
check(table.concat(report.Observed, " "):find("PRIVATE RECORD", 1, true) ~= nil, "evaluation describes observed action")
check(report.Notice:find("IN%-SHIFT") ~= nil, "evaluation discloses fictional scope")
local public = Engagement.PublicReports({ report })
check(public[1].Employee == "Alice" and public[1].Observed == nil, "public status hides unopened observations")

local awards = Engagement.Awards(members)
check(#awards >= 2, "multiple useful awards selected")
local unique = {}
for _, award in ipairs(awards) do
	check(not unique[award.UserId], "one award per employee")
	unique[award.UserId] = true
end

check(Engagement.Unlock(members[alice], "Customers", "mara"), "first handbook unlock accepted")
check(not Engagement.Unlock(members[alice], "Customers", "mara"), "duplicate handbook unlock idempotent")
local collection = Engagement.CollectionSnapshot(members[alice])
check(collection.Customers == 1 and collection.Anomalies == 0, "collection snapshot reveals totals only")

local time, speech, published = 10, nil, 0
local run = {
	players = members,
	d = { clock = function() return time end },
	_say = function(_, speaker, text)
		speech = speaker .. ": " .. text
	end,
	_publish = function()
		published += 1
	end,
}
local ok = Engagement.Signal(run, alice, "Inside")
check(ok and speech == "Alice: GET INSIDE" and published == 1, "approved signal broadcasts once")
check(not Engagement.Signal(run, alice, "Inside"), "signal cooldown rejects spam")
time += 3
check(Engagement.Signal(run, alice, "Ticket"), "signal works after cooldown")
check(not Engagement.Signal(run, alice, "made_up"), "unknown signal rejected")

local previousHandbook = members[alice].Handbook
Engagement.ResetMember(members[alice], true)
check(members[alice].Handbook == previousHandbook, "continuing night keeps run handbook")
check(members[alice].Activity.Records == 0, "continuing night resets nightly activity")

print(string.format("PASS: %d engagement checks", total))
