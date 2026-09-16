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
	local stations = f.h:load("src/GServer/Prototype/Repair/RepairStations.luau")
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
	local pickup = f.h:load("src/GServer/Prototype/Customers/PickupService.luau")
	local seen = {}
	for _ = 1, 1000 do
		local issued = pickup.Issue(f.run)
		check(not seen[issued] and #issued == 6, "ticket sequence stays distinct")
		seen[issued] = true
	end
end

-- Shared view uses one scoped call, supports all Activated inputs, and cleans up.
do
	local Roblox = require("@lune/roblox")
	local h = Harness.Environment()
	for _, name in ipairs({ "Color3", "Vector2", "UDim2", "Enum" }) do
		h.env[name] = Roblox[name]
	end
	local listener, disconnected
	local input = {
		GamepadEnabled = true,
		InputBegan = {
			Connect = function(_, callback)
				listener = callback
				return {
					Disconnect = function()
						disconnected = true
					end,
				}
			end,
		},
	}
	local gui = h.env.Instance.new("ScreenGui")
	local selection, sent = {}, {}
	local view = h:load("src/GShared/Prototype/UI/FaxView.luau").new(gui, {
		input = input,
		gui = selection,
		clock = function()
			return h.time
		end,
		send = function(action, payload)
			table.insert(sent, { action, payload })
		end,
	})
	local state = {
		Alive = true,
		Phase = "Night",
		Fax = {
			Id = "visit",
			EndsAt = h.time + 90,
			Tickets = { { Ticket = "123456", Customer = "Customer", Step = "ReadyForPickup" } },
		},
	}
	view:Update(state, false, false)
	check(view.panel.Visible and selection.SelectedObject == view.first, "fax is visible and gamepad selectable")
	view.call.Activated:Fire()
	check(#sent == 0, "incomplete local code sends nothing")
	for _, key in ipairs({ "1", "2", "3", "4", "5", "6", "7" }) do
		view.panel:FindFirstChild("Key" .. key).Activated:Fire()
	end
	check(view.digits == "123456" and #sent == 0, "keypad caps six digits without per-key remotes")
	view.call.Activated:Fire()
	check(#sent == 1 and sent[1][2].Ticket == "123456" and sent[1][2].FaxId == "visit", "CALL sends ticket and visit")
	view:Update(state, false, true)
	view.call.Activated:Fire()
	view:Key("CLEAR")
	check(#sent == 1 and view.digits == "123456", "pending request blocks repeated call and digit edits")
	view:Update(state, false, false)
	view:Error("PhoneNotReady")
	view:Update(state, false, false)
	check(view.message.Text:find("Repair"), "repeated snapshot preserves local error")
	listener({ KeyCode = Roblox.Enum.KeyCode.Backspace }, false)
	check(view.digits == "12345", "keyboard backspace edits code")
	listener({ KeyCode = Roblox.Enum.KeyCode.Six }, false)
	check(view.digits == "123456", "keyboard digits work")
	listener({ KeyCode = Roblox.Enum.KeyCode.ButtonB }, false)
	check(not view.panel.Visible and sent[#sent][1] == "CloseFax", "controller B closes fax with scoped request")
	view:Update(state, false, false)
	check(not view.panel.Visible, "unanswered close cannot reopen same visit")
	state.Fax = table.clone(state.Fax)
	state.Fax.Id = "next"
	view:Update(state, false, false)
	check(view.digits == "" and view.panel.Visible, "new visit resets digits")
	view:Update(state, true, false)
	check(not view.panel.Visible and sent[#sent][2].FaxId == "next", "menu interrupts and closes active visit")
	view:Destroy()
	check(disconnected and not view.panel.Parent, "fax UI and input cleaned up")
	local requests = h:load("src/GShared/Prototype/Networking/Requests.luau")
	local _, payload = requests.Payload({ RunId = "run" }, "DialTicket", { FaxId = "visit", Ticket = "123456" })
	check(
		payload.RunId == "run" and payload.Ticket == "123456" and payload.FaxId == "visit",
		"network helper retains ticket scope"
	)
end
print("PASS: " .. total .. " customer drop-off, fax pickup and input checks.")
