local Harness = require("./Harness")
local Fixture = require("./ShiftFixture")
local total = 0
local function check(value, message)
	assert(value, message)
	total += 1
end

do
	local f = Fixture(2, check)
	f:start()
	local p, q = f.p[1], f.p[2]
	local lane = f.run.stations.Bench
	local ticket = lane.order.Ticket
	check(type(ticket) == "string" and ticket:match("^%d%d%d%d%d%d$"), "ticket has six digits")
	check(f.run:Snapshot(p).Order.Ticket == ticket, "drop-off ticket reaches the HUD")
	check(f:act("TakeOrder"), "customer drops off phone")
	f:advance(0.6)
	check(f:act("OpenFax"), "fax opens without owning the repair")
	local visit = f.run.players[p].Fax.Id
	local function dial(code, who, id)
		f:advance(0.6)
		return f:act("DialTicket", who or p, { FaxId = id or visit, Ticket = code })
	end
	local ok, code = dial(ticket)
	check(not ok and code == "PhoneNotReady" and lane.order.Step == "Diagnose", "early call cannot skip repair")
	for _, bad in ipairs({ "12345", "1234567", "abcdef", 123456 }) do
		ok, code = dial(bad)
		check(not ok and code == "InvalidTicket", "reject malformed ticket")
	end
	ok, code = dial("999999")
	check(not ok and code == "TicketNotFound", "unknown six-digit ticket does not summon a customer")
	ok, code = dial(ticket, q)
	check(not ok and code == "FaxClosed", "another player's fax visit is not accepted")
	f.near[p] = "Bench"
	ok = dial(ticket)
	check(not ok and f.run.players[p].Fax == nil, "walking away closes the fax and rejects dialing")
	f.near[p] = "Fax"
	check(f:act("OpenFax"), "fax reopens with a fresh visit")
	local newVisit = f.run.players[p].Fax.Id
	check(newVisit ~= visit, "fax visit identities are not reused")
	ok, code = dial(ticket)
	check(not ok and code == "FaxClosed", "delayed previous-visit call is rejected")
	visit = newVisit
	-- Complete the existing work chain through its authoritative puzzle driver.
	f.near[p] = nil
	f:act("CloseFax", p, { FaxId = visit })
	for _, action in ipairs({ "Diagnose", "Collect", "Repair", "Secure", "Install", "Test" }) do
		f:advance(0.6)
		check(f:act(action), "perform " .. action)
		if action ~= "Collect" then
			f:solve()
		end
	end
	check(lane.order.Step == "ReadyForPickup" and lane.order.ExpiresAt == nil, "finished phone waits for its call")
	check(not f:act("Return") and f.run.repaired == 0, "return and payment blocked before call")
	f:advance(0.6)
	check(f:act("OpenFax"), "open fax for finished phone")
	visit = f.run.players[p].Fax.Id
	check(dial(ticket), "correct code summons repaired-phone owner")
	local arrival = lane.order.PickupAt
	check(lane.order.Step == "PickupArriving" and f.run.revenue == 0, "calling starts arrival without payment")
	check(not f:act("Return"), "cannot hand phone to customer before arrival")
	check(dial(ticket) and lane.order.PickupAt == arrival, "duplicate call does not restart arrival")
	-- A separate bench/customer has its own ticket and callback state.
	f.run:_newOrder(false, f.run.stations.Bench2)
	local second = f.run.stations.Bench2.order
	second.Step, second.ExpiresAt = "ReadyForPickup", nil
	check(second.Ticket ~= ticket, "parallel customers get distinct tickets")
	check(dial(second.Ticket), "same fax can call another bench's customer")
	check(lane.order.PickupAt == arrival, "second callback leaves first arrival unchanged")
	local stations = f.h:load("src/GServer/Repair/RepairStations.luau")
	f:advance(f.c.ArrivalSeconds)
	check(lane.order.Step == "Return" and second.Step == "Return", "both owners return after calls")
	check(f:act("Return"), "first owner receives repaired phone")
	local revenue = f.run.revenue
	check(not f:act("Return") and f.run.revenue == revenue, "returned ticket cannot pay twice")
	f:advance(0.6)
	check(stations.AtCounter(f.run, p).order == second, "counter selects waiting pickup from other bench")
	check(f:act("Return", p, { OrderId = second.Id }), "counter hands back the correctly scoped other phone")
	check(f.run.repaired == 2, "each handover pays exactly once")
	ok, code = dial(ticket)
	check(not ok and code == "TicketNotFound", "completed ticket cannot summon another customer")
	f.run.event = { Kind = "Blackout", Id = "test", EndsAt = f.h.time + 5 }
	f.run:Tick()
	check(f.run.players[p].Fax == nil and not f:act("OpenFax"), "hazard closes and blocks fax")
	f.run.event = nil
	f:advance(0.6)
	check(f:act("OpenFax"), "fax usable after hazard")
	f:advance(91)
	check(f.run.players[p].Fax == nil, "unused fax visit expires")
	local pickup = f.h:load("src/GServer/Orders/CustomerPickupService.luau")
	local seen = {}
	for _ = 1, 1000 do
		local issued = pickup.Issue(f.run)
		check(not seen[issued] and #issued == 6, "ticket sequence stays distinct")
		seen[issued] = true
	end
end

print("PASS: " .. total .. " customer drop-off, fax pickup and input checks.")
