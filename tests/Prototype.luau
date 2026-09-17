local Harness = require("./Harness")
local benchMove = require("./BenchDriver")
local total = 0
local function check(value, message)
	assert(value, message)
	total += 1
end

local createFixture = require("./ShiftFixture")
local function fixture(count)
	return createFixture(count, check)
end

do
	local f = fixture(2)
	f.session.Ready = false
	f.run:Tick()
	f:advance(10)
	check(f.run.phase == "Waiting", "admission and data readiness gate gameplay")
	f.session.Ready = true
	f.run:Tick()
	f:advance(3)
	check(
		f.run.phase == "Tutorial" and not f.run.stations.Bench.order,
		"tutorial opens automatically after party ready"
	)
	check(
		f.run:Snapshot(f.p[1]).NeedsClockIn and not f.run:Snapshot(f.p[1]).NeedsRules,
		"entry comes before directive modal"
	)
	check(not f:act("ReadRules", f.p[1]), "cannot acknowledge training before clocking in")
	f:act("ClockIn", f.p[1])
	f:act("ReadRules", f.p[1])
	check(not f.run.stations.Bench.order, "training waits for all staff to read directive")
	f:act("ClockIn", f.p[2])
	f:act("ReadRules", f.p[2])
	f:advance(f.c.ArrivalSeconds)
	check(
		f.run.stations.Bench.order.Step == "Waiting" and not f.run.stations.Bench.order.ExpiresAt,
		"first customer waits without tutorial timeout"
	)
	f:advance(400)
	check(
		f.run.phase == "Tutorial" and not f.run.event and f.run.stations.Bench.order.Step == "Waiting",
		"tutorial has no clock pressure or hazards"
	)
	f:repair()
	check(
		f.run.phase == "Night" and f.run.repaired == 1 and f.run.revenue == 45,
		"first completed repair starts night and pays once"
	)
	check(f.tutorial[f.p[1]] and f.tutorial[f.p[2]], "guided team repair marks tutorial complete")
	check(not f:act("Return"), "duplicate return cannot award another payment")
	check(f.run.revenue == 45, "payment cannot duplicate")
	check(f.run:Snapshot(f.p[1]).Order == nil, "returned phone leaves current order")
end

do
	local f = fixture()
	f:start()
	f.near[f.p[1]] = "Stock"
	check(not f:act("TakeOrder"), "remote interaction from wrong station rejected")
	f.near[f.p[1]] = nil
	f:act("TakeOrder")
	f:advance(0.6)
	check(not f:act("Repair"), "cannot skip diagnosis")
	f:advance(0.6)
	check(f:act("Diagnose"), "diagnosis begins")
	check(f.run.stations.Bench.order.Step == "Diagnose", "work does not finish on click")
	f.near[f.p[1]] = "Counter"
	f:advance(f.c.WorkSeconds)
	check(
		f.run.stations.Bench.order.Step == "Diagnose" and not f.run.stations.Bench.work,
		"walking away cancels work without advancing"
	)
	f.near[f.p[1]] = nil
	f:act("Diagnose")
	f:advance(f.c.WorkSeconds)
	local old = f.run.stations.Bench.order.Id
	check(not f:act("Collect", nil, { OrderId = "stale" }), "stale order action rejected")
	f:advance(0.6)
	f:act("Collect")
	f:advance(f.c.WorkSeconds)
	check(
		f.run.stock.Battery == 3 and f.run.stations.Bench.order.Step == "Repair",
		"part consumed exactly once on completed collection"
	)
	f:advance(0.6)
	f:act("Collect", nil, { OrderId = old })
	check(f.run.stock.Battery == 3, "repeated collection cannot consume duplicate part")
end

do
	local f = fixture(3)
	f:start()
	f:repair()
	f.run:_newOrder(false)
	f.run.stations.Bench.order.Sensitive, f.run.stations.Bench.order.Step = true, "Evidence"
	f.run.stations.Bench.order.Evidence = { Id = "prototype_ward7", Discovery = "Ward Seven" }
	f.run.stations.Bench.order.Phone = { Discovered = true, Installed = true, Revision = 1 }
	f.run.stations.Bench.order.Votes, f.run.stations.Bench.order.VoteEndsAt = {}, f.h.time + f.c.VoteSeconds
	local id = f.run.stations.Bench.order.Id
	f:act("Vote", f.p[1], { OrderId = id, Choice = "Investigate" })
	check(f.run.stations.Bench.order.Step == "Evidence", "one teammate cannot decide for three")
	check(not f:act("Vote", f.p[2], { OrderId = id, Choice = "Cheat" }), "invalid evidence choice rejected")
	f:act("Vote", f.p[2], { OrderId = id, Choice = "Investigate" })
	check(
		f.run.stations.Bench.order.Step == "Install"
			and f.run.stations.Bench.order.Phone.Page == "Archive"
			and f.run.suspicion == 30,
		"strict majority resolves once with consequences"
	)
	check(f.evidence[f.p[1]] == "prototype_ward7", "investigation unlocks server-issued evidence")
	check(not f:act("Vote", f.p[3], { OrderId = id, Choice = "Report" }), "resolved choice cannot change")
	check(#f.run.decisions == 1, "evidence decision applied exactly once")
end

do
	local f = fixture(2)
	f:start()
	f:repair()
	f.run:_newOrder(false)
	f.run.stations.Bench.order.Step, f.run.stations.Bench.order.Votes, f.run.stations.Bench.order.VoteEndsAt =
		"Evidence", {}, f.h.time + 5
	f:act("Vote", f.p[1], { OrderId = f.run.stations.Bench.order.Id, Choice = "Hide" })
	f:act("Vote", f.p[2], { OrderId = f.run.stations.Bench.order.Id, Choice = "Report" })
	f:advance(5)
	check(f.run.decisions[1] == "Report", "vote timeout tie prefers report")
end

do
	local f = fixture()
	f:start()
	f:repair()
	local start = f.run.nightAt
	f.h.time = start + 55.1
	f.run:Tick()
	check(f.run.event.Kind == "Blackout", "night scheduler triggers first strange event")
	f.near[f.p[1]] = "Counter"
	check(not f:act("RestorePower"), "hazard response requires correct station")
	f.near[f.p[1]] = nil
	f:advance(0.6)
	check(f:act("RestorePower") and not f.run.event, "fuse interaction resolves blackout")
	f.h.time = start + 130.1
	f.run:Tick()
	f:advance(0.6)
	f:act("Silence")
	check(f.run.players[f.p[1]].HP == 100, "silencing disconnected call is safe")
	f.h.time = start + 215.1
	f.run:Tick()
	f:advance(0.6)
	f:act("Records")
	f.h.time = start + 305.1
	f.run:Tick()
	check(f.run.event.Kind == "Visitor", "visitor warns before fatal attack")
	f.near[f.p[1]] = "Shelter"
	f:advance(20)
	check(f.run.players[f.p[1]].Alive, "physical shelter protects player from visitor")
	f.h.time = start + f.c.NightSeconds + 0.1
	f.run:Tick()
	check(f.run.phase == "Results" and f.run.reason == "Dawn", "surviving full clock shows dawn results")
	check(
		#f.records[f.p[1]] == 1 and f.records[f.p[1]][1].Survived and f.saves[f.p[1]] == 1,
		"survival outcome recorded and save requested once"
	)
	f:advance(12)
	check(#f.records[f.p[1]] == 1, "results ticks cannot duplicate survival")
	check(f.run:CanReturn(f.p[1]), "recorded results allow return teleport")
	local previous = f.run.id
	f:act("Replay")
	f.run:Tick()
	check(
		f.run.phase == "Tutorial" and f.run.id ~= previous and f.run.repaired == 0,
		"unanimous replay resets night with new outcome identity"
	)
end

do
	local f = fixture(2)
	f:start()
	f:repair()
	f.run.event = { Id = "fatal", Kind = "Visitor", EndsAt = f.h.time + 1, Warning = "Hide" }
	f.near[f.p[1]], f.near[f.p[2]] = "Bench", "Shelter"
	f:advance(1)
	check(
		not f.run.players[f.p[1]].Alive and f.run.players[f.p[2]].Alive,
		"exposed player dies while sheltered teammate survives"
	)
	check(not f:act("Restock", f.p[1]), "dead/respawned player cannot work")
	check(f.run:CanReturn(f.p[1]), "settled dead player can return to Lobby without ending the surviving team run")
	f.run:Damage(f.p[1], 100, "second death callback")
	check(
		#f.records[f.p[1]] == 1 and not f.records[f.p[1]][1].Survived,
		"death callbacks do not duplicate persisted deaths"
	)
	f.run:Damage(f.p[2], 100, "test")
	check(f.run.phase == "Results" and f.run.reason == "AllDead", "all dead ends night immediately")
	check(f.run:Snapshot(f.p[1]).Outcome == "Died", "personal death result survives team end")
end

do
	local f = fixture(2)
	f:start()
	f:repair()
	f.session.State, f.session.Ready = "Interrupted", false
	f.run:Tick()
	check(f.run.phase == "Results" and f.run.reason == "Interrupted", "party interruption cancels active shift")
	check(next(f.records) == nil, "interruption does not fabricate survival or deaths")
end

do
	local f = fixture(2)
	f:start()
	f:act("TakeOrder")
	f:advance(0.6)
	f:act("Diagnose", f.p[1])
	check(not f:act("Diagnose", f.p[2]), "two staff cannot start the same repair work")
	f.run:Remove(f.p[1])
	check(
		not f.run.stations.Bench.work and f.run.stations.Bench.order.Step == "Diagnose",
		"disconnect releases unfinished workstation work"
	)
	f:advance(0.6)
	check(f:act("Diagnose", f.p[2]), "remaining staff can resume abandoned work")
end

do
	local f = fixture()
	f:start()
	f:repair()
	f.run:_newOrder(false)
	f.run.stations.Bench.order.Step, f.run.stations.Bench.order.ExpiresAt = "Return", f.h.time + 1
	f.h.time += 2
	local revenue = f.run.revenue
	check(not f:act("Return") and f.run.revenue == revenue, "expired order cannot be returned between timer ticks")
	f.run:Tick()
	check(f.run.missed == 1 and not f.run.stations.Bench.order, "expired customer leaves and counts as missed")
	f.run:_newOrder(false)
	f.run.stations.Bench.order.Step = "Install"
	f:advance(0.6)
	f:act("Install")
	f.run.event = { Kind = "Blackout", Id = "1", EndsAt = f.h.time + 20, Warning = "Restore power" }
	f:advance(f.c.WorkSeconds)
	check(
		f.run.stations.Bench.order.Step == "Install" and not f.run.stations.Bench.work,
		"power failure cancels an in-progress install without granting completion"
	)
end

do
	local f = fixture()
	f:start()
	f:repair()
	local attempts, permitted = 0, false
	f.run.d.outcome = function()
		attempts += 1
		return permitted
	end
	f.run:Damage(f.p[1], 100, "test")
	check(
		not f.run:CanReturn(f.p[1]) and not f.run.players[f.p[1]].Settled,
		"unrecorded result prevents departing before stats enter profile"
	)
	permitted = true
	f:advance(6)
	check(
		f.run.players[f.p[1]].Settled and f.run:CanReturn(f.p[1]) and attempts >= 2 and f.saves[f.p[1]] == 1,
		"temporarily unavailable outcome recording retries safely"
	)
end

do
	local f = fixture()
	f:start()
	local Roblox = require("@lune/roblox")
	f.h.env.Color3 = Roblox.Color3
	local prototypeClass = f.h:load("src/GServer/Session/GameService.luau")
	local prototype = setmetatable({ run = f.run }, prototypeClass)
	local stranger = f.h:player(99)
	local response = prototype:Request(stranger, "GetPrototype", {})
	check(
		not response.State.Roster and not response.State.Order,
		"unadmitted requests cannot read live shift information"
	)
	response = prototype:Request(
		f.p[1],
		"PrototypeAction",
		{ RunId = "previous_run", Action = "TakeOrder", OrderId = f.run.stations.Bench.order.Id }
	)
	check(
		not response.Ok and f.run.stations.Bench.order.Step == "Waiting",
		"stale run ID cannot operate new session order"
	)
end

-- Exercise the generated world/UI adapters against exact Roblox-shaped instances.
do
	local f = fixture()
	f.explicitWorkshop = true
	f:start()
	local player = f.p[1]
	local function act(action, station, payload)
		f.near[player] = station
		f:advance(0.6)
		return f:act(action, player, payload)
	end
	check(act("TakeOrder", "Counter"), "explicit journey accepts a customer")
	check(not f.run:Snapshot(player).Order.Fault, "fault is hidden until diagnosis completes")
	local ok, code = act("Diagnose", "Bench")
	check(not ok and code == "SitFirst", "standing players cannot start bench work")
	check(act("Sit", "Bench") and f.run:Snapshot(player).Seated, "sit action enters the repair chair")
	check(act("Diagnose", "Bench"), "seated player begins diagnosis")
	check(f:act("Stand"), "stand is accepted while work and cooldown are active")
	check(
		not f.run.stations.Bench.work and f.run.stations.Bench.order.Step == "Diagnose",
		"standing cancels unfinished diagnosis"
	)
	check(act("Sit", "Bench") and act("Diagnose", "Bench"), "player can resume cancelled diagnosis")
	f:advance(f.c.WorkSeconds)
	check(f.run:Snapshot(player).Order.Fault == "Battery", "completed diagnosis reveals the replacement type")
	check(f:act("Stand"), "solo repairer can leave for the parts room")
	ok, code = act("Collect", "Part_Speaker", { OrderId = f.run.stations.Bench.order.Id, Part = "Speaker" })
	check(not ok and code == "WrongPart" and f.run.stock.Battery == 4, "wrong shelf cannot spend stock or issue a part")
	check(act("Collect", "Part_Battery"), "matching shelf starts collection")
	f:advance(f.c.WorkSeconds)
	check(
		f.parts[player] == f.run.players[player].CarriedPart and f.run.stock.Battery == 3,
		"completed collection issues one authentic carried part and reserves one stock"
	)
	check(f.run:Snapshot(player).CarriedPart == "Battery", "HUD receives carried part type")
	check(
		act("DepositPart", "Bench") and not f.parts[player] and f.run.stations.Bench.order.PartDelivered,
		"placing tool at bench transfers the reservation to the phone"
	)
	check(not act("DepositPart", "Bench"), "deposit cannot be replayed")
	check(act("Sit", "Bench") and act("Repair", "Bench"), "seated repair consumes deposited component through work")
	f:advance(f.c.WorkSeconds)
	check(
		f.run.stations.Bench.order.Step == "Secure" and not f.run.stations.Bench.order.PartDelivered,
		"component is fitted once"
	)
	check(not act("Install", "Bench"), "installation waits for all four screws")
	check(f:act("Stand") and not act("Secure", "Bench"), "contacts require physical seating")
	check(act("Sit", "Bench"), "repairer can reseat to secure the fitted component")
	check(not act("Secure", "Bench", { OrderId = "stale" }), "stale contact request cannot alter phone")
	check(
		act("Secure", "Bench") and f.run.stations.Bench.order.Contacts == 0,
		"starting secure does not tighten any screws"
	)
	check(not f:act("Secure"), "duplicate secure requests are rejected while puzzle is open")
	check(
		not act("Secure", "Bench", { OrderId = f.run.stations.Bench.order.Id, Contact = 1 }),
		"legacy contact clicks cannot bypass puzzle"
	)
	f:solve()
	check(
		f.run.stations.Bench.order.Contacts == 4 and f.run.stations.Bench.order.Step == "Install",
		"reassembly and all four screws gate installation"
	)
	check(act("Install", "Bench"), "installation starts after fitting")
	f:advance(f.c.WorkSeconds)
	check(act("Test", "Bench"), "repaired phone can be tested")
	f:advance(f.c.WorkSeconds)
	f:act("Stand")
	f:pickup()
	check(
		act("Return", "Counter") and f.run.phase == "Night" and f.run.revenue == 45,
		"explicit seated/tool journey finishes training and starts a playable night"
	)
end

do
	local f = fixture(2)
	f.explicitWorkshop = true
	f:start()
	local a, b = f.p[1], f.p[2]
	local function act(player, action)
		f:advance(0.6)
		return f:act(action, player)
	end
	act(a, "TakeOrder")
	act(a, "Sit")
	local ok, code = act(b, "Sit")
	check(not ok and code == "BenchOccupied", "second repairer cannot take occupied chair")
	act(a, "Diagnose")
	f:advance(f.c.WorkSeconds)
	act(b, "Collect")
	f:advance(f.c.WorkSeconds)
	check(f.run:Snapshot(a).Order.PartCarrier == b.DisplayName, "repairer sees teammate carrying the replacement")
	ok, code = act(a, "Repair")
	check(not ok and code == "MissingPart", "repair cannot start from a teammate's undeployed tool")
	check(act(b, "DepositPart"), "restocker deposits while another player remains seated")
	f.run:Damage(b, 100, "test")
	check(
		f.run.stations.Bench.order.PartDelivered and act(a, "Repair"),
		"deposited part survives carrier death and can be fitted by teammate"
	)
	f:advance(f.c.WorkSeconds)
	check(
		f.run.stations.Bench.order.Step == "Secure" and f.run.stock.Battery == 3,
		"cooperative fitting spends exactly one stock"
	)
end

do
	local f = fixture(2)
	f:start()
	f:act("TakeOrder")
	f:advance(0.6)
	f:act("Diagnose")
	f:advance(f.c.WorkSeconds)
	f:act("Collect")
	f:advance(f.c.WorkSeconds)
	local a = f.p[1]
	f.parts[a] = nil
	f:advance(0.25)
	check(
		f.run.stations.Bench.order.Step == "Collect" and f.run.stock.Battery == 4 and not f.run.players[a].CarriedPart,
		"destroyed or lost tool returns one reservation to its shelf"
	)
	f:advance(1)
	check(f.run.stock.Battery == 4, "lost-tool recovery cannot refund twice")
	f:act("Collect")
	f:advance(f.c.WorkSeconds)
	f.run:Remove(a)
	check(
		f.run.stock.Battery == 4 and f.run.stations.Bench.order.Step == "Collect" and not f.parts[a],
		"disconnecting carrier cannot strand the shared order"
	)
end

do
	local f = fixture()
	f:start()
	f:repair()
	f.c.Events = { { At = 1, Kind = "Blackout", Duration = 10, Warning = "Test outage" } }
	f.run.stations.Bench.nextOrder = f.run.nightAt + 1
	f:advance(1)
	check(
		f.run.event and not f.run.stations.Bench.order,
		"disturbance wins when arrival and hazard are due on the same tick"
	)
	f:advance(10)
	check(
		not f.run.stations.Bench.order and f.run.resumeAt,
		"normal arrivals remain stopped through disturbance recovery"
	)
	f:advance(f.c.AfterDisturbanceSeconds - 1)
	check(not f.run.stations.Bench.order, "recovery quiet period prevents immediate customer spawn")
	f:advance(1)
	check(
		f.run.stations.Bench.order and f.run.stations.Bench.order.Step == "Arriving",
		"customers resume once shop is safe"
	)
end

do
	local f = fixture()
	f:start()
	f:repair()
	f.run:_newOrder(false)
	f.c.Events = { { At = 0, Kind = "Call", Duration = 10, Warning = "Test call" } }
	f:advance(0.25)
	local order = f.run.stations.Bench.order
	check(
		order.PausedAt and f.run:Snapshot(f.p[1]).ArrivalsPaused,
		"approaching customer is suspended during disturbance"
	)
	f:advance(4)
	check(order.Step == "Arriving", "suspended arrival cannot enter the service window")
	check(f:act("Silence", nil, { EventId = f.run.event.Id }), "counteraction resolves the disturbance")
	f:advance(f.c.AfterDisturbanceSeconds)
	check(
		order.Step == "Arriving" and order.ArrivesAt == f.h.time + f.c.ArrivalSeconds,
		"suspended customer receives a fresh approach animation after recovery"
	)
	f:advance(f.c.ArrivalSeconds)
	check(
		order.Step == "Waiting" and order.ExpiresAt == f.h.time + order.Patience,
		"resumed customer receives full personal patience"
	)
	order.Step, order.Votes, order.VoteEndsAt = "Evidence", {}, f.h.time + 2
	local oldExpiry = order.ExpiresAt
	f.c.Events[2] = { At = 0, Kind = "Blackout", Duration = 8, Warning = "Outage" }
	f:advance(0.25)
	f:advance(8)
	check(
		order.Step == "Evidence" and f.run.missed == 0,
		"evidence votes and patience do not expire while handling danger"
	)
	f:advance(f.c.AfterDisturbanceSeconds)
	check(order.ExpiresAt > oldExpiry and order.Step == "Evidence", "paused deadlines resume with time preserved")
end

do
	local h = Harness.Environment()
	require("./PrototypeAssets").Install(h)
	local catalog = h:load("src/GServer/Customers/CustomerCatalog.luau")
	local ids, normal = {}, 0
	check(#catalog.Customers == 270, "customer database contains 270 unique records")
	for _, customer in ipairs(catalog.Customers) do
		check(
			not ids[customer.Id]
				and customer.Patience > 0
				and customer.Fee > 0
				and table.find({ "Battery", "Speaker", "Keypad" }, customer.Fault),
			"customer record has unique identity and playable repair data"
		)
		ids[customer.Id] = true
		if customer.Kind == "Normal" then
			normal += 1
		end
	end
	check(
		normal / #catalog.Customers >= 0.7 and normal / #catalog.Customers <= 0.8,
		"ordinary repairs remain 70-80 percent of customer content"
	)
	local deck = catalog.Deck(function(low)
		return low
	end)
	local seen = {}
	for _, index in ipairs(deck) do
		seen[index] = true
	end
	check(
		#deck == #catalog.Customers and deck[1] == 1 and deck[2] == 2 and deck[3] == 3,
		"onboarding customer sequence remains stable"
	)
	local count = 0
	for _ in pairs(seen) do
		count += 1
	end
	check(count == #catalog.Customers, "shuffled customer cycle has no duplicate or missing records")
end

do
	local f = fixture()
	f:start()
	local revision = f.run.revision
	for _ = 1, 40 do
		f:advance(0.25)
	end
	check(f.run.revision == revision, "idle tutorial ticks do not generate revisions")
	f:act("TakeOrder")
	f:advance(0.6)
	f:act("Diagnose")
	local work = f.run:Snapshot(f.p[1]).Work
	check(
		work.UserId == f.p[1].UserId and work.Station == "Bench" and work.StartedAt < work.EndsAt,
		"work exposes authoritative owner, station and timing for local presentation"
	)
	local before = f.run.revision
	f:advance(f.c.WorkSeconds)
	check(f.run.revision > before and not f.run.stations.Bench.work, "work completion publishes immediately")
	local Roblox = require("@lune/roblox")
	f.h.env.Color3 = Roblox.Color3
	local prototypeClass = f.h:load("src/GServer/Session/GameService.luau")
	local pushes = 0
	f.run.dialogueChannel:Clear()
	f.run.dialogue = nil
	local prototype = setmetatable({
		run = f.run,
		world = { Render = function() end },
		saving = {},
		nextPush = 0,
		net = {
			Push = function()
				pushes += 1
			end,
		},
	}, prototypeClass)
	for _ = 1, 40 do
		f.h.time += 0.25
		prototype:Tick()
	end
	check(pushes == 2, "ten idle seconds send two refresh snapshots instead of twenty")
	f:act("Collect")
	prototype:Tick()
	check(pushes == 3, "accepted work bypasses idle refresh delay")
end

do
	local Roblox = require("@lune/roblox")
	local h = Harness.Environment()
	require("./PrototypeAssets").Install(h)
	for _, key in ipairs({ "Color3", "Vector3", "Vector2", "CFrame", "UDim", "UDim2" }) do
		h.env[key] = Roblox[key]
	end
	h.env.Enum = setmetatable({}, {
		__index = function(_, kind)
			return setmetatable({}, {
				__index = function(_, name)
					return kind .. "." .. name
				end,
			})
		end,
	})
	h.env.TweenInfo = {
		new = function()
			return {}
		end,
	}
	h.env.task.delay = function(_, fn)
		h.env.task.spawn(fn)
	end
	local function signal()
		local callbacks = {}
		return {
			Connect = function(_, fn)
				local connection = { Connected = true }
				function connection:Disconnect()
					self.Connected = false
				end
				table.insert(callbacks, { fn, connection })
				return connection
			end,
			Fire = function(_, ...)
				for _, callback in ipairs(callbacks) do
					if callback[2].Connected then
						callback[1](...)
					end
				end
			end,
		}
	end
	h.env.Instance = {
		new = function(class)
			local object = h.instance(class)
			if class == "TextButton" then
				object.InputBegan = signal()
			end
			if class == "Sound" then
				object.Play = function(self)
					self.Played = true
				end
				object.Stop = function(self)
					self.Played = false
				end
			end
			if class == "ProximityPrompt" then
				object.Triggered = signal()
			end
			return object
		end,
	}
	local workspace = h.instance("Workspace")
	workspace.Raycast = function()
		return nil
	end
	workspace.GetServerTimeNow = function()
		return h.time
	end
	workspace.CurrentCamera = { ViewportSize = Roblox.Vector2.new(1100, 800) }
	h.env.workspace = workspace
	local lighting = {
		ClockTime = 12,
		Brightness = 2,
		Ambient = Roblox.Color3.new(),
		OutdoorAmbient = Roblox.Color3.new(),
		FogEnd = 999,
		FogColor = Roblox.Color3.new(),
	}
	local tweens = 0
	local services = {
		Workspace = workspace,
		CollectionService = require("./TagFixture").Collection(),
		Players = h.players,
		ReplicatedStorage = h.instance("ReplicatedStorage"),
		Lighting = lighting,
		TweenService = {
			Create = function(_, target, _, properties)
				tweens += 1
				return {
					Completed = signal(),
					Cancel = function() end,
					Play = function()
						for key, value in pairs(properties) do
							target[key] = value
							if target.GetPropertyChangedSignal then
								target:GetPropertyChangedSignal(key):Fire()
							end
						end
					end,
				}
			end,
		},
	}
	h.env.RaycastParams = {
		new = function()
			return {}
		end,
	}
	require("./CustomerFixture").Install(h)
	local config = h:load("src/GServer/Session/GameConfig.luau")
	local world = h:load("src/GServer/World/WorldService.luau").new(services, config)
	check(
		workspace.Prototype.DPU_Prototype == world.folder and world.spawn.Parent == world.folder,
		"prototype binds saved shop and staff spawn"
	)
	check(
		world.stations.Counter and world.stations.Bench and world.stations.Stock and world.stations.Shelter,
		"all required work and shelter stations exist"
	)
	check(#world.folder:GetChildren() < 90, "compact generated scene remains bounded")
	check(
		not world.stations.TestBench and not world.workshop.seats.TestBench and not world.testPhone,
		"all phone work shares one bench and chair"
	)
	check(
		world.stations.Tools and not world.stations.Tool_Tester and not world.stations.Tool_Cartridge,
		"one repair kit replaces scattered tool pickups"
	)
	check(world.folder:FindFirstChild("StockroomDoorway") ~= nil, "one doorway connects shop and stockroom")
	for _, point in ipairs({ { 0, 8 }, { 0, 0 }, { 0, 16 }, { 0, -8 } }) do
		local center = world.origin * Roblox.Vector3.new(point[1], 3.5, point[2])
		for _, object in ipairs(world.folder:GetChildren()) do
			if object:IsA("Part") and object.CanCollide ~= false then
				local delta = object.CFrame:PointToObjectSpace(center)
				check(
					not (
							math.abs(delta.X) < object.Size.X / 2 + 0.8
							and math.abs(delta.Z) < object.Size.Z / 2 + 0.8
							and math.abs(delta.Y) < object.Size.Y / 2 + 2.5
						),
					"doorway has avatar clearance: " .. object.Name
				)
			end
		end
	end
	local smallSign = world.stations.Bench.Sign
	check(
		smallSign.Size == Roblox.UDim2.fromScale(3.8, 0.55)
			and smallSign.MaxDistance == 22
			and smallSign.TextLabel.TextColor3 == Roblox.Color3.fromRGB(228, 224, 216),
		"placeholder labels are small, white and distance-limited"
	)
	check(world.origin:PointToObjectSpace(world.spawn.CFrame.Position).X > 24, "new staff spawn outside the shop walls")
	check(
		world.folder.RightWallFront and world.folder.RightWallBack and not world.folder:FindFirstChild("RightWall"),
		"staff doorway replaces the solid side wall"
	)
	local template = services.ReplicatedStorage.Assets.Devices.Phone
	check(
		world.repairPhone ~= template and world.repairPhone:FindFirstChild("Battery"),
		"phone is cloned from reusable component template"
	)
	check(
		template.Phone.CFrame.Position.X == 0 and world.repairPhone.Phone.CFrame.Position.Z == 399,
		"placing a phone preserves the source template pivot"
	)
	check(
		not world.repairPhone.Battery.CanCollide and not world.repairPhone.Battery.CanTouch,
		"repair components create no touch events or physical collisions"
	)
	for _, station in pairs(world.stations) do
		if station:IsA("BasePart") then
			station.Position = station.CFrame.Position
		end
	end
	local p = h:player(1)
	local character = h.instance("Model")
	character.DescendantAdded = signal()
	p.Character = character
	local root = h.instance("Part")
	root.Name, root.Parent = "HumanoidRootPart", character
	local humanoid = h.instance("Humanoid")
	humanoid.Name, humanoid.Parent, humanoid.Health = "Humanoid", character, 100
	root.Position = world.origin * Roblox.Vector3.new(22.2, 3, 5)
	check(not world:Near(p, "Timeclock"), "timeclock rejects use through the exterior wall")
	check(world:Outside(p) == false, "doorway tolerance avoids exposure flicker at the shop edge")
	root.Position = world.origin * Roblox.Vector3.new(30, 3, 5)
	check(world:Outside(p) == true, "exterior spawn position counts as outside for night exposure")
	root.Position = world.origin * Roblox.Vector3.new(0, 16, 2)
	check(world:Outside(p) == true, "being above the roof does not count as shelter")
	local originalOrigin = world.origin
	world.origin = Roblox.CFrame.new(100, 0, -300) * Roblox.CFrame.Angles(0, 0.7, 0)
	root.Position = world.origin * Roblox.Vector3.new(-15, 3, 15)
	check(world:Outside(p) == false, "outside classification follows translated and rotated shop origin")
	world.origin = originalOrigin
	root.Position = world.origin * Roblox.Vector3.new(18, 3, 3)
	check(world:Near(p, "Timeclock"), "clock-in is reachable inside the entrance")
	root.Position = world.stations.Shelter.Position + Roblox.Vector3.new(0, 3, 0)
	check(world:Near(p, "Shelter"), "shelter accepts a living avatar above marked floor")
	root.Position += Roblox.Vector3.new(0, 0, 10)
	check(not world:Near(p, "Shelter"), "shelter rejects an avatar outside its actual bounds")
	root.Position = world.origin * Roblox.Vector3.new(-21, 3, 7)
	check(not world:Near(p, "Part_Battery"), "shelf interaction cannot pass through parts-room front wall")
	root.Position = world.origin * Roblox.Vector3.new(-19, 3, 12)
	check(
		world:Near(p, "Part_Battery") and not world:Near(p, "Bench"),
		"parts must be collected inside the room, away from the repair chair"
	)
	local backpack = h.instance("Backpack")
	backpack.Parent = p
	humanoid.EquipTool = function(_, tool)
		tool.Parent = character
	end
	local record = { RunId = "run", OrderId = "order", Fault = "Battery" }
	check(world.workshop:GivePart(p, record), "physical adapter creates and equips replacement tool")
	local actual = world.workshop.tools[p].Tool
	check(
		actual.Parent == character
			and actual:IsA("Tool")
			and not actual.CanBeDropped
			and not actual.Handle.Anchored
			and actual.Handle.Size == world.stations.Part_Battery.Size,
		"tool has a physical non-droppable handle cloned from the Storage pickup"
	)
	check(
		world.repairPhone.Battery.Anchored and world.workshop:HasPart(p, record),
		"carrying does not alter phone template and authentic tool is recognized"
	)
	actual.Parent = backpack
	check(world.workshop:HasPart(p, record), "unequipping into backpack preserves reservation")
	local forged = actual:Clone()
	forged.Parent = backpack
	actual.Parent = nil
	check(not world.workshop:HasPart(p, record), "matching attributes on a cloned tool cannot forge authority")
	world.workshop:ClearPart(p)
	check(forged.Parent == backpack, "part cleanup removes only the tool issued by this adapter")
	forged:Destroy()
	world.workshop.seat.Sit = function(seat, occupant)
		seat.Occupant, occupant.SeatPart, occupant.Sit = occupant, seat, true
	end
	check(
		world.workshop:Sit(p) and world.workshop:IsSeated(p),
		"physical chair uses Seat occupancy and Humanoid seating together"
	)
	world.workshop:Stand(p)
	check(not world.workshop:IsSeated(p), "standing invalidates physical seating immediately")
	world.workshop.seat.Occupant, humanoid.SeatPart = nil, nil
	check(not world.workshop:Sit(p, "OtherSeat"), "unknown chair cannot authorize work")
	root.Position = world.origin * Roblox.Vector3.new(5.5, 3, 10)
	check(not world:Near(p, "Records"), "records cannot be read from the stockroom")
	root.Position = world.origin * Roblox.Vector3.new(5.5, 3, -10)
	check(world:Near(p, "Records"), "inspection records are accessible on the counter")
	local appearances = services.ReplicatedStorage.Assets.NPC:GetChildren()
	local Templates = h:load("src/GShared/Customers/CustomerTemplates.luau")
	check(
		appearances[1].Name == appearances[2].Name
			and appearances[1]:GetAttribute(Templates.Attribute) ~= appearances[2]:GetAttribute(Templates.Attribute),
		"duplicate NPC names receive distinct appearance identities"
	)
	local appearanceId = appearances[2]:GetAttribute(Templates.Attribute)
	check(
		Templates.Find(services.ReplicatedStorage, appearanceId) == appearances[2],
		"portrait lookup resolves the exact duplicate-name template"
	)
	for _ = 1, 30 do
		check(
			Templates.Find(services.ReplicatedStorage, world:ChooseAppearance()) ~= nil,
			"random customer appearance always names an authored template"
		)
	end
	h.env.RaycastParams = {
		new = function()
			return {}
		end,
	}
	local phonePart = world.telephone:FindFirstChildWhichIsA("BasePart")
	phonePart.Position = phonePart.CFrame.Position
	root.Position = phonePart.Position + Roblox.Vector3.new(0, 0, 3)
	workspace.Raycast = function()
		return nil
	end
	check(
		world:Near(p, "Fax") and world.stations.Fax == workspace.Prototype.DPU_Prototype.Fax,
		"telephone access follows the actual authored model"
	)
	local wall = h.instance("Part")
	wall.CanCollide = true
	workspace.Raycast = function()
		return { Instance = wall, Position = phonePart.Position }
	end
	check(not world:Near(p, "Fax"), "physical customer calls cannot pass through actual walls")
	workspace.Raycast = function()
		return nil
	end
	root.Position = phonePart.Position + Roblox.Vector3.new(0, 0, 20)
	check(not world:Near(p, "Fax"), "physical calls enforce server distance")
	local fakeRun = {
		players = {},
		phase = "Tutorial",
		stock = { Battery = 4 },
		stations = {
			Bench = {
				Id = "Bench",
				order = {
					Id = "1",
					Customer = "Mara",
					AppearanceId = appearanceId,
					Step = "Waiting",
					Fault = "Battery",
				},
			},
			Bench2 = { Id = "Bench2" },
		},
	}
	world:Render(fakeRun)
	check(
		world.repairLanes.Bench.customer
			and tweens == 0
			and world.prompts.Counter.Enabled
			and world.actions.Counter == "TakeOrder",
		"waiting customer is placed immediately without a walking tween and intake prompt activates"
	)
	local arriving = world.repairLanes.Bench.customer
	check(
		arriving:GetAttribute(Templates.Attribute) == appearanceId and arriving.Head.Color == appearances[2].Head.Color,
		"world customer clones the selected authored NPC"
	)
	check(
		not arriving:FindFirstChild("AuthoredScript") and appearances[2]:FindFirstChild("AuthoredScript"),
		"customer clones are sanitized without changing source NPC scripts"
	)
	check(
		not arriving:FindFirstChild("Torso") and not arriving:FindFirstChild("Sign"),
		"no generated body or customer billboard is substituted"
	)
	fakeRun.doorOpen, fakeRun.lampOn = true, false
	world:Render(fakeRun)
	check(
		world.stations.StaffDoor.CFrame == world.doorOpened and not world.stations.StaffDoor.CanCollide,
		"opening tweens door to its hinge pose and clears the entry"
	)
	check(
		not world.benchLight.Enabled and world.actions.Radio == "TuneRadio" and not world.actions.Records,
		"optional light and radio remain; records only prompt during inspections"
	)
	fakeRun.stations.Bench.order.Step, fakeRun.stations.Bench.order.PausedAt = "Arriving", h.time
	world:Render(fakeRun)
	check(not world.repairLanes.Bench.customer, "disturbance removes an approaching normal customer from the scene")
	fakeRun.stations.Bench.order.PausedAt = nil
	world:Render(fakeRun)
	check(world.repairLanes.Bench.customer ~= nil, "suspended approach can be rebuilt after the disturbance")
	fakeRun.stations.Bench.order.Step = "Collect"
	world:Render(fakeRun)
	check(
		world.actions.Part_Battery == "Collect"
			and world.actions.Stock == "Restock"
			and not world.prompts.Counter.Enabled,
		"world prompts follow repair step"
	)
	check(not world.repairLanes.Bench.customer, "customer leaves after dropping off the phone")
	check(world.stations.Fax and world.actions.Fax == "OpenFax", "fax is available for pickup calls")
	fakeRun.stations.Bench.order.Step = "ReadyForPickup"
	world:Render(fakeRun)
	check(
		not world.repairLanes.Bench.customer and not world.prompts.Counter.Enabled,
		"ready phone does not summon its owner automatically"
	)
	fakeRun.stations.Bench.order.Step = "PickupArriving"
	world:Render(fakeRun)
	check(world.repairLanes.Bench.customer ~= nil, "callback brings customer back into the scene")
	check(
		world.repairLanes.Bench.customer:GetAttribute(Templates.Attribute) == appearanceId,
		"pickup returns the same NPC appearance"
	)
	fakeRun.stations.Bench.order.Step = "Return"
	world:Render(fakeRun)
	check(
		world.prompts.Counter.Enabled and not world.repairLanes.Bench.visible,
		"return moves phone from bench to counter"
	)
	for part, alpha in pairs(world.repairLanes.Bench.counterParts) do
		check(part.Transparency == alpha, "pickup phone is visible at counter")
	end
	fakeRun.event = { Kind = "Blackout" }
	world:Render(fakeRun)
	check(
		not world.lamps[1].Enabled and world.actions.Fuse == "RestorePower",
		"blackout dims shop and exposes fuse action"
	)
	fakeRun.event = { Kind = "Visitor" }
	world:Render(fakeRun)
	check(world.watcher and world.watcher.Name == "Visitor", "visitor manifests outside the shop")
	fakeRun.phase, fakeRun.event, fakeRun.stations.Bench.order = "Results", nil, nil
	world:Render(fakeRun)
	check(
		not world.watcher and not world.prompts.Counter.Enabled and world.lamps[1].Enabled,
		"ending clears threats and disables work prompts"
	)
	fakeRun.revision = 50
	world:Render(fakeRun)
	local actions = world.actions
	for _ = 1, 40 do
		world:Render(fakeRun)
	end
	check(world.actions == actions, "unchanged revisions reuse world bindings instead of rebuilding prompt actions")
	for _ = 1, 20 do
		fakeRun.revision += 1
		world:Render(fakeRun)
	end
	check(world.actions == actions, "twenty puzzle/profile revisions cause zero unchanged-scene prompt rebuilds")
	local playerGui = h.instance("PlayerGui")
	local used, lobbyCalls = nil, 0
	local view = h:load("src/GClient/Interface/HUDController.luau").new(playerGui, {
		act = function(action)
			used = action
		end,
		lobby = function()
			lobbyCalls += 1
		end,
	})
	local state = {
		Phase = "Tutorial",
		RunId = "one",
		NeedsRules = true,
		Alive = true,
		HP = 100,
		Rules = config.Rules,
		Roster = {},
		Stock = {},
		Decisions = {},
	}
	state.NeedsRules, state.NeedsClockIn, state.Target = false, true, "StaffDoor"
	view:SetState(state)
	check(
		not view.modal.Visible and view:CurrentAction() == "ToggleDoor",
		"arrival UI guides entry without covering the world"
	)
	state.Intro = { Title = "ENDLESS / NIGHT 1", Text = "Survive as many nights as you can." }
	view:SetState(state)
	check(
		view.modal.Visible and view.modalTitle.Text == state.Intro.Title and not view.bottom.Visible,
		"mode introduction replaces the HUD before clock-in"
	)
	view.ack.Activated:Fire()
	view:SetState(state)
	check(
		not view.modal.Visible and view.bottom.Visible and used == nil,
		"intro acknowledgement is local and does not skip server clock-in"
	)
	-- HUD routing selects the authored card and keeps the multipurpose legacy modal hidden.
	local introWanted = false
	view.panels = {
		Update = function(_, _, _, _, wanted)
			introWanted = wanted
			return false, false, true
		end,
		IsOpen = function()
			return introWanted
		end,
	}
	view.introSeen = nil
	view:SetState(state)
	check(
		introWanted and not view.modal.Visible and not view.bottom.Visible,
		"authored briefing suppresses legacy extra-button panel and owns modal input"
	)
	view:AcknowledgeIntro()
	check(
		not introWanted and view.introSeen == state.RunId and state.NeedsClockIn and used == nil,
		"new Understood acknowledgement stays local and preserves required clock-in"
	)
	view:SetState(state)
	check(not introWanted, "acknowledged briefing does not reopen on another snapshot")
	view.panels = nil
	state.Intro = nil
	state.Target = "Timeclock"
	view:SetState(state)
	check(view:CurrentAction() == "OpenClock" and view.use.Text == "OPEN TIMECLOCK", "entry action changes to clock-in")
	state.Focus = { Id = "clock", Station = "Timeclock" }
	view:SetState(state)
	check(not view.clockPanel.Visible and not view.bottom.Visible, "timeclock inspection hides the ordinary HUD")
	state.Focus = nil
	state.NeedsRules, state.NeedsClockIn = true, false
	view:SetState(state)
	check(
		view.modal.Visible and view.ack.Visible and not view.use.Visible,
		"tutorial directive appears immediately and hides work action"
	)
	view.ack.Activated:Fire()
	check(used == "ReadRules", "tutorial acknowledgement is wired to server intent")
	state.NeedsRules, state.Order, state.Target =
		false, { Id = "1", Customer = "Mara", Complaint = "Broken", Step = "Waiting" }, "Counter"
	view:SetState(state)
	check(
		not view.modal.Visible and view.use.Visible and view:CurrentAction() == "TakeOrder",
		"work HUD replaces tutorial and offers correct action"
	)
	view:ToggleRules()
	check(
		view.modal.Visible
			and not view.clockPanel.Visible
			and not view.bottom.Visible
			and string.find(view.modalText.Text, "Mara", 1, true) ~= nil
			and string.find(view.modalText.Text, "ON DUTY", 1, true) ~= nil,
		"shift info opens ticket and team details without competing HUD panels"
	)
	view.ack.Activated:Fire()
	check(
		not view.modal.Visible and view.bottom.Visible and view.clockPanel.Visible,
		"closing shift info restores work controls"
	)
	state.Order.Step, state.Target = "Diagnose", "Bench"
	view:SetState(state)
	check(view:CurrentAction() == "Sit", "standing HUD directs the player to sit before diagnosis")
	state.Seated = true
	view:SetState(state)
	check(
		view:CurrentAction() == "Diagnose" and view.bottom.Visible,
		"seated UI focuses the repair action and hides side cards"
	)
	state.Work = { Name = "Mara", Action = "Diagnose", Station = "Bench", Interactive = true, Puzzle = {} }
	state.Notice = "Working on phone"
	view:SetState(state)
	check(
		not view.clockPanel.Visible and not view.bottom.Visible and not view.warning.Visible,
		"puzzle owns the screen without duplicate work or notice cards"
	)
	view:Error("InvalidInput")
	check(view.warning.Visible, "important input errors remain visible during puzzle work")
	view.error, state.Work, state.Notice = nil, nil, nil
	state.Order.Step, state.Order.Fault = "Collect", "Battery"
	view:SetState(state)
	check(view:CurrentAction() == "Stand", "solo seated player is guided to stand for collection")
	state.Seated, state.CarriedPart, state.Order.Step = false, "Battery", "Repair"
	view:SetState(state)
	check(
		view:CurrentAction() == "DepositPart" and view.use.Text == "PUT PART ON BENCH",
		"carried tool changes HUD to bench delivery"
	)
	state.CarriedPart = nil
	state.Vote = { OrderId = "1", EndsAt = h.time + 10, Message = "Clue", Report = 0, Hide = 0, Investigate = 0 }
	view:SetState(state)
	check(
		view.modal.Visible and view.voteButtons.Report.Visible and not view.ack.Visible,
		"evidence opens team vote instead of old tutorial buttons"
	)
	state.Event = { Kind = "Call", Warning = "Silence the phone", EndsAt = h.time + 20 }
	view:SetState(state)
	check(
		not view.modal.Visible and view:CurrentAction() == "Silence",
		"disturbance hides vote modal so players can respond to danger"
	)
	state.Event = nil
	view:SetState(state)
	workspace.CurrentCamera.ViewportSize = Roblox.Vector2.new(844, 390)
	view:Render()
	check(
		not view.clockPanel.Visible and not view.bottom.Visible and view.modal.Position.Y.Offset == 116,
		"landscape mobile hides side cards and keeps warning space above modal"
	)
	state.NightStartedAt, state.NightDuration, state.Phase = h.time - 60, 360, "Night"
	view:SetState(state)
	check(view.night.Text == "1" and view.clock.Text == "01:00 AM", "night clock derives from authoritative start time")
	state.Outside, state.DoorOpen = { Since = h.time - 15, ThreatEndsAt = h.time + 7 }, false
	view:SetState(state)
	check(
		view.warning.Visible
			and string.find(view.warningText.Text, "GET INSIDE", 1, true)
			and view:CurrentAction() == "ToggleDoor",
		"outdoor pursuit exposes escape countdown and door action"
	)
	state.DoorOpen = true
	view:SetState(state)
	check(view:CurrentAction() == nil, "escape button cannot close an already open staff door")
	state.Outside = nil
	state.Injury, state.HP = { Damage = 25, Reason = "The signal struck you", ExpiresAt = h.time + 8 }, 75
	view:SetState(state)
	check(
		view.warning.Visible and string.find(view.warningText.Text, "75 HP LEFT", 1, true),
		"injury aftermath makes the health consequence readable"
	)
	state.Injury = nil
	h.time += 30
	view:Render()
	check(view.night.Text == "1" and view.clock.Text == "01:30 AM", "clock advances without repeated network snapshots")
	state.TimeFrozenAt = h.time
	h.time += 30
	view:Render()
	check(view.night.Text == "1" and view.clock.Text == "01:30 AM", "finished night freezes its displayed time")
	state.Phase, state.Outcome, state.Reason, state.Alive, state.CanReturn, state.CanReplay, state.Vote =
		"Results", "Died", "AllDead", false, true, true, nil
	view:SetState(state)
	check(
		view.modal.Visible
			and view.replay.Visible
			and view.lobby.Visible
			and view.modalTitle.Text == "YOU DID NOT MAKE IT",
		"death results expose replay and lobby actions"
	)
	state.Ending = { Title = "MISSING EMPLOYEE", Summary = "Your timecard is still in the rack." }
	view:SetState(state)
	check(
		view.modalTitle.Text == state.Ending.Title and string.find(view.modalText.Text, state.Ending.Summary, 1, true),
		"results combine personal epilogue and shift statistics"
	)
	view.lobby.Activated:Fire()
	check(lobbyCalls == 0, "return button requires visible confirmation")
	view.lobby.Activated:Fire()
	check(lobbyCalls == 1, "confirmed return invokes lobby action")
	view:Destroy()
	check(playerGui:FindFirstChild("DPU_PrototypeHUD") == view.gui, "prototype UI cleanup preserves authored HUD")
	local hud = h.env.Instance.new("ScreenGui")
	hud.Name, hud.Parent = "HUD", playerGui
	local oldClock, oldBriefing, oldSignals = view.gui.Clock, view.gui.Briefing, view.gui.TeamSignals
	oldClock.Parent, oldBriefing.Parent, oldSignals.Parent = hud, nil, nil
	local oldObjective = view.gui.Objective
	oldObjective.Parent = nil
	local objectiveFrame = h.env.Instance.new("Frame")
	objectiveFrame.Name, objectiveFrame.Parent = "Objective", hud
	local objectiveInner = h.env.Instance.new("Frame")
	objectiveInner.Name, objectiveInner.Parent, objectiveInner.Visible = "Frame", objectiveFrame, false
	local objectiveText = h.env.Instance.new("TextLabel")
	objectiveText.Name, objectiveText.Parent = "Text", objectiveInner
	objectiveText.Size, objectiveText.TextSize, objectiveText.TextScaled = Roblox.UDim2.fromScale(0.9, 0.9), 23, true

	h.skipPrototypeAssets = true
	local migrated = h:load("src/GClient/Interface/HUDController.luau").new(playerGui, {
		act = function(action)
			used = action
		end,
		lobby = function() end,
	})
	h.skipPrototypeAssets = false
	check(
		migrated.clockPanel == oldClock and not migrated.modal and not migrated.signalMenu and hud.Enabled,
		"HUD.Clock loads with removed DPU Clock, Briefing and TeamSignals"
	)
	check(
		migrated.objective == objectiveText
			and objectiveInner.Visible
			and objectiveText.Visible
			and not migrated.use
			and objectiveText.TextScaled
			and objectiveText.TextSize == 23
			and objectiveText.Size == Roblox.UDim2.fromScale(0.9, 0.9),
		"HUD.Objective.Frame binds without legacy Objective, optional Use or geometry overrides"
	)
	local notice
	migrated.panels = {
		briefing = {},
		Update = function()
			return true, false, true
		end,
		Notice = function(_, value)
			notice = value
		end,
		IsOpen = function()
			return notice ~= nil
		end,
		Destroy = function() end,
	}
	migrated:SetState({
		RunId = "new",
		Phase = "Results",
		CanReplay = true,
		Reason = "Dawn",
		NightsCleared = 1,
		Repaired = 4,
	})
	check(notice and notice.Action == "Replay", "removed legacy results route to new single-button briefing")
	migrated:AcknowledgeNotice()
	check(used == "Replay", "successful shift can still continue through validated replay")
	migrated:SetState({
		RunId = "new",
		Phase = "Night",
		Alive = true,
		Event = { Id = "call-new", Kind = "Call", EndsAt = h.time + 20, Warning = "Phone ringing" },
	})
	used = nil
	migrated:RequestAnswer()
	check(
		notice and notice.Action == "ArmAnswer" and not used,
		"first receiver click still warns before harmful answer"
	)
	migrated:AcknowledgeNotice()
	check(not used, "Understood closes warning without answering")
	migrated:RequestAnswer()
	check(used == "Answer", "explicit second receiver click confirms current warned call")
	migrated:Destroy()
	oldClock.Parent, oldBriefing.Parent, oldSignals.Parent = view.gui, view.gui, view.gui
	oldObjective.Parent = view.gui
	hud:Destroy()
	-- Delayed tween completions exercise ownership, cancellation and restore paths.
	local camera = h.instance("Camera")
	camera.ViewportSize = Roblox.Vector2.new(1100, 800)
	camera.CFrame, camera.Focus = Roblox.CFrame.new(0, 5, 2), Roblox.CFrame.new()
	camera.CameraType, camera.CameraSubject, camera.FieldOfView = "CameraType.Custom", humanoid, 73
	camera.Parent, workspace.CurrentCamera = workspace, camera
	humanoid.MoveDirection = Roblox.Vector3.zero
	humanoid.Sit, humanoid.SeatPart = true, world.workshop.seat
	root.Position = world.stations.Bench.Position + Roblox.Vector3.new(0, 0, 5)
	for _, marker in ipairs(world.stations.Bench:GetChildren()) do
		if marker:IsA("Attachment") then
			marker.WorldCFrame = world.stations.Bench.CFrame * marker.CFrame
		end
	end
	local renderSignal, inputSignal = signal(), signal()
	local reduced, menu = false, false
	local tweenList = {}
	local presentation = h:load("src/GClient/Repair/RepairPresentation.luau").new({
		stand = function()
			humanoid.Sit = false
		end,
		workspace = workspace,
		player = p,
		render = { RenderStepped = renderSignal },
		input = { InputBegan = inputSignal },
		reduced = function()
			return reduced
		end,
		menuOpen = function()
			return menu
		end,
		tweens = {
			Create = function(_, target, _, props)
				local tween = { Completed = signal() }
				function tween:Play()
					for key, value in pairs(props) do
						target[key] = value
					end
				end
				function tween:Cancel()
					self.Cancelled = true
				end
				table.insert(tweenList, tween)
				return tween
			end,
		},
	}, playerGui)
	local repair = {
		Seated = true,
		SeatVisit = 1,
		RunId = "repair",
		Phase = "Night",
		Alive = true,
		Target = "Bench",
		Order = { Id = "1", Step = "Repair", Fault = "Battery" },
		Work = {
			UserId = p.UserId,
			Station = "Bench",
			Action = "Repair",
			StartedAt = h.time,
			EndsAt = h.time + 2.5,
		},
	}
	local original = camera.CFrame
	repair.Work.UserId = 999
	repair.Seated = false
	presentation:Update(repair, false)
	check(not presentation:OwnsCamera() and not presentation.card.Visible, "teammate work never steals local camera")
	repair.Work.UserId = p.UserId
	repair.Seated = true
	presentation:Update(repair, false)
	check(
		presentation:OwnsCamera() and camera.CameraType == "CameraType.Scriptable",
		"local repair eases into scriptable bench camera"
	)
	check(
		camera.CFrame.Position.Y > camera.Focus.Position.Y + 6 and math.abs(camera.CFrame.LookVector.Y) > 0.98,
		"repair camera is above the phone with an almost vertical viewing axis"
	)
	check(root.LocalTransparencyModifier == 1, "repair close-up hides only the local character")
	local lateHat = h.instance("Part")
	lateHat.Name, lateHat.LocalTransparencyModifier, lateHat.Parent = "LateAccessory", 0.35, character
	character.DescendantAdded:Fire(lateHat)
	check(lateHat.LocalTransparencyModifier == 1, "accessories arriving during repair are hidden locally")
	check(
		presentation.highlight.Adornee == world.repairPhone.Battery and presentation.card.Visible,
		"repair highlights the requested component with one reusable progress card"
	)
	local count = #tweenList
	for _ = 1, 20 do
		presentation:Update(repair, false)
	end
	check(#tweenList == count, "repeated repair snapshots never restart camera or progress tweens")
	camera.ViewportSize = Roblox.Vector2.new(375, 812)
	renderSignal:Fire()
	check(
		camera.CFrame.Position.Y < world.folder.Roof.CFrame.Position.Y - 0.5 and camera.FieldOfView > 45,
		"portrait reframing keeps trays visible without moving the camera through the shop roof"
	)
	camera.ViewportSize = Roblox.Vector2.new(1100, 800)
	renderSignal:Fire()
	check(camera.FieldOfView == 45, "landscape resize returns to the close repair lens")
	local fittingWork = repair.Work
	repair.Work, repair.Order.Step, repair.Order.Contacts, repair.Order.RequiredContacts = nil, "Secure", 1, 3
	presentation:Update(repair, false)
	check(
		presentation.highlight.Adornee == world.repairPhone.Screws.Screw2
			and math.abs(presentation.fill.Size.X.Scale - 1 / 3) < 0.001,
		"tightening advances highlighted physical contact and progress"
	)
	repair.Work, repair.Order.Step = fittingWork, "Repair"
	inputSignal:Fire({ KeyCode = "KeyCode.Q" }, false)
	check(
		root.LocalTransparencyModifier == 0 and lateHat.LocalTransparencyModifier == 0.35,
		"standing restores the captured local transparency of body and accessories"
	)
	check(
		not presentation:OwnsCamera()
			and camera.CameraType == "CameraType.Custom"
			and camera.FieldOfView == 73
			and camera.CFrame == original,
		"look-around input restores exact camera and FOV without stopping work"
	)
	presentation:Update(repair, false)
	check(not presentation:OwnsCamera() and presentation.card.Visible, "dismissed work never traps the camera again")
	local function newWork()
		h.time += 1
		repair.Seated, repair.SeatVisit, humanoid.Sit = true, repair.SeatVisit + 1, true
		repair.Work.StartedAt, repair.Work.EndsAt = h.time, h.time + 2.5
		presentation:Update(repair, false)
	end
	newWork()
	humanoid.MoveDirection = Roblox.Vector3.new(1, 0, 0)
	renderSignal:Fire()
	check(not presentation:OwnsCamera(), "movement cancels close-up immediately")
	humanoid.MoveDirection = Roblox.Vector3.zero
	newWork()
	repair.Event = { Kind = "Visitor" }
	presentation:Update(repair, false)
	check(
		not presentation:OwnsCamera() and presentation.highlight.Adornee == world.stations.Shelter,
		"danger releases camera and highlights shelter"
	)
	repair.Event = nil
	reduced = true
	newWork()
	check(
		not presentation:OwnsCamera() and presentation.card.Visible,
		"reduced motion keeps repair feedback without camera animation"
	)
	reduced = false
	newWork()
	local previousCamera = camera
	workspace.CurrentCamera = h.instance("Camera")
	renderSignal:Fire()
	check(
		not presentation:OwnsCamera() and previousCamera.CameraType == "CameraType.Custom",
		"camera replacement restores the old camera and detaches frame updates"
	)
	workspace.CurrentCamera = previousCamera
	newWork()
	humanoid.Health = 0
	renderSignal:Fire()
	check(not presentation:OwnsCamera(), "real humanoid death releases camera before a network snapshot")
	humanoid.Health = 100
	newWork()
	menu = true
	renderSignal:Fire()
	check(not presentation:OwnsCamera(), "Roblox menu releases camera")
	menu = false
	newWork()
	local savedWork = repair.Work
	repair.Work, repair.Seated = nil, false
	presentation:Update(repair, false)
	local returning = tweenList[#tweenList]
	check(presentation.saved.Returning, "standing eases back before handing control to Roblox")
	returning.Completed:Fire()
	check(
		not presentation:OwnsCamera() and camera.CameraType == "CameraType.Custom" and camera.FieldOfView == 73,
		"completed return tween restores exact normal camera settings"
	)
	repair.Work = savedWork
	newWork()
	returning.Completed:Fire()
	check(
		presentation:OwnsCamera() and not presentation.saved.Returning,
		"stale completion cannot restore a newer close-up"
	)
	presentation:Destroy()
	local testPresentation = h:load("src/GClient/Repair/RepairPresentation.luau").new(presentation.d, playerGui)
	local testState = {
		RunId = "testing",
		Phase = "Night",
		Alive = true,
		Seated = true,
		SeatStation = "Bench",
		SeatVisit = 1,
		Target = "Bench",
		Order = { Id = "phone", Step = "Test" },
	}
	root.Position = world.stations.Bench.Position + Roblox.Vector3.new(0, 0, 5)
	humanoid.Sit, humanoid.SeatPart = true, world.workshop.seat
	for _, marker in ipairs(world.stations.Bench:GetChildren()) do
		if marker:IsA("Attachment") then
			marker.WorldCFrame = world.stations.Bench.CFrame * marker.CFrame
		end
	end
	testPresentation:Update(testState, false)
	check(
		testPresentation:OwnsCamera()
			and testPresentation.highlight.Adornee == world.repairPhone.Screen
			and testPresentation.highlight.DepthMode == "HighlightDepthMode.AlwaysOnTop",
		"final testing keeps the repair camera and phone highlight"
	)
	testPresentation:Destroy()
	humanoid.SeatPart = world.workshop.seat
	root.Position = world.stations.Bench.Position + Roblox.Vector3.new(0, 0, 5)
	check(
		camera.FieldOfView == 73 and presentation.highlight.Parent ~= nil and presentation.card.Parent ~= nil,
		"cleanup restores camera and preserves authored visuals"
	)
	-- Loading after a saved helper was deleted still mounts the actual repair controller.
	local savedRepairHighlight = presentation.highlight
	local highlightParent = savedRepairHighlight.Parent
	savedRepairHighlight.Parent = nil
	local directLoad = Harness.Environment().load
	local recovered = directLoad(h, "src/GClient/Repair/RepairPresentation.luau").new(presentation.d, playerGui)
	check(
		recovered.highlight.Parent == highlightParent and recovered.highlight ~= savedRepairHighlight,
		"repair presentation starts without saved DPU_RepairFocus"
	)
	recovered:Update({ Alive = true, Phase = "Tutorial", Target = "Timeclock" }, false)
	check(
		recovered.highlight.Adornee == world.stations.Timeclock and recovered.highlight.Enabled,
		"fallback repair highlight follows the next real objective"
	)
	recovered:Destroy()
	recovered:Destroy()
	check(
		recovered.highlight.Parent == nil and recovered.card.Parent == playerGui,
		"repair teardown removes only its temporary highlight, retaining authored UI"
	)
	savedRepairHighlight.Parent = highlightParent
	local after = #tweenList
	inputSignal:Fire({ KeyCode = "KeyCode.Q" }, false)
	renderSignal:Fire()
	check(#tweenList == after, "input and render callbacks are disconnected on cleanup")
	-- Cosmetic assembly follows authoritative timestamps and cannot complete gameplay.
	local battery, tray = world.repairPhone.Battery, world.replacement
	battery.LocalTransparencyModifier, tray.LocalTransparencyModifier = 0.2, 0.3
	battery.Transparency, tray.Position = 0, tray.CFrame.Position
	local assembly = h:load("src/GClient/Repair/RepairAssembly.luau").new({
		workspace = workspace,
		tweens = presentation.d.tweens,
		reduced = function()
			return reduced
		end,
	})
	repair.Work.StartedAt, repair.Work.EndsAt = h.time, h.time + 4
	assembly:Update(repair)
	check(not assembly.part, "authored device uses replicated fitting without duplicate local assembly")
	world.repairPhone:SetAttribute("DPU_DeviceId", nil)
	assembly:Update(repair)
	local moving, lifting = assembly.part, tweenList[#tweenList]
	check(
		moving
			and moving.Parent == workspace
			and moving.CanCollide == false
			and battery.LocalTransparencyModifier == 1
			and tray.LocalTransparencyModifier == 1,
		"assembly moves one local component while hiding duplicate visuals"
	)
	local countBefore = #tweenList
	assembly:Update(repair)
	check(#tweenList == countBefore and assembly.part == moving, "same work snapshot reuses assembly tween")
	h.time += 2.6
	lifting.Completed:Fire()
	check(moving.CFrame == battery.CFrame, "lowering tween targets the exact authored component pose")
	h.time += 1.4
	assembly:Update(repair)
	check(
		not moving.Parent and battery.LocalTransparencyModifier == 0.2 and tray.LocalTransparencyModifier == 0.3,
		"finished assembly restores captured local visibility"
	)
	repair.Work.StartedAt, repair.Work.EndsAt = h.time - 3, h.time + 1
	countBefore = #tweenList
	assembly:Update(repair)
	check(
		#tweenList == countBefore + 1 and assembly.part.CFrame == battery.CFrame,
		"late replication enters the remaining lowering stage"
	)
	repair.Event = { Kind = "Visitor" }
	assembly:Update(repair)
	check(
		not assembly.part and battery.LocalTransparencyModifier == 0.2,
		"hazard cancels fitting visuals and restores phone"
	)
	repair.Event = nil
	repair.Work.StartedAt, repair.Work.EndsAt = h.time, h.time + 4
	assembly:Update(repair)
	lifting = tweenList[#tweenList]
	assembly:Clear()
	countBefore = #tweenList
	lifting.Completed:Fire()
	check(
		lifting.Cancelled and #tweenList == countBefore and not assembly.part,
		"stale tween completion cannot resurrect cancelled assembly"
	)
	reduced = true
	assembly:Update(repair)
	check(not assembly.part, "reduced motion skips fitting travel")
	reduced = false
	assembly:Update(repair)
	assembly:Destroy()
	world.repairPhone:SetAttribute("DPU_DeviceId", "Phone")
	local lookups = 0
	assembly.d.workspace = {
		GetServerTimeNow = function()
			return h.time
		end,
		FindFirstChild = function()
			lookups += 1
			return nil
		end,
	}
	for _ = 1, 50 do
		assembly:Update({ Alive = true, Phase = "Night" })
	end
	check(lookups == 0, "idle assembly updates perform zero world lookups")
	check(
		not workspace:FindFirstChild("DPU_FittingPart") and tray.LocalTransparencyModifier == 0.3,
		"assembly teardown removes only local effect and restores tray"
	)
	local soundTemplate = h.instance("Sound")
	soundTemplate.Name, soundTemplate.Volume = "ScareSound", 0.9
	soundTemplate.Parent = services.ReplicatedStorage.Assets
	soundTemplate.Play = function(self)
		self.Played = true
	end
	local ScarePresentation = h:load("src/GClient/Effects/HorrorController.luau")
	local scares = ScarePresentation.new({
		workspace = workspace,
		storage = services.ReplicatedStorage,
		tweens = presentation.d.tweens,
		reduced = function()
			return reduced
		end,
		menuOpen = function()
			return menu
		end,
		volume = function()
			return 0.5
		end,
	}, playerGui)
	local savedScareCamera = scares.camera
	local savedScareFrame, savedScareFOV = savedScareCamera.CFrame, savedScareCamera.FieldOfView
	local scareState = { RunId = "night", Scare = { Id = "one", Kind = "Signal", At = h.time } }
	scares:Update(scareState)
	check(
		scares.frame.Visible and scares.viewport.Visible and scares.sound.Played and scares.sound.Volume == 0.3,
		"fresh scare uses pooled face and capped master-scaled optional sound"
	)
	check(camera.CFrame == original and camera.CameraType == "CameraType.Custom", "scare never owns the world camera")
	local scareTween = scares.tween
	scares:Update(scareState)
	check(scares.tween == scareTween, "repeated snapshots cannot replay a scare")
	scares.d.shake = function()
		return false
	end
	scares:Update(scareState)
	check(
		scares.lunge == nil and scares.camera.FieldOfView == 54 and scares.sound.Played,
		"disabling camera shake stops active lunge without muting sound"
	)
	scareState.Scare = { Id = "static", Kind = "Signal", At = h.time }
	scares:Update(scareState)
	check(
		scares.lunge == nil and scares.viewport.Visible and scares.sound.Played,
		"camera shake off preserves static scare and audio"
	)
	scares.d.shake = nil

	scareState.Scare = { Id = "injury", Kind = "Signal", At = h.time, Damage = 25, Fatal = false }
	scares:Update(scareState)
	check(string.find(scares.caption.Text, "25 HP", 1, true), "injuring scare displays its server-issued consequence")
	scareState.Scare = { Id = "fatal", Kind = "Visitor", At = h.time, Damage = 100, Fatal = true }
	scares:Update(scareState)
	check(scares.caption.Text == "IT FOUND YOU.", "fatal attack has a distinct caption before death")
	h.time += 1
	scares:Update(scareState)
	check(not scares.frame.Visible and not scares.sound, "scare and audio expire on bounded update")
	scareState.Scare = { Id = "old", At = h.time - 3 }
	scares:Update(scareState)
	check(not scares.frame.Visible, "late scare snapshot never surprises a reconnecting client")
	reduced = true
	scareState.Scare = { Id = "reduced", At = h.time }
	scares:Update(scareState)
	check(
		scares.frame.Visible and not scares.viewport.Visible and not scares.sound,
		"reduced motion replaces jump effect with silent text"
	)
	menu = true
	scares:Update(scareState)
	check(not scares.frame.Visible, "menu opening clears active scare")
	menu, reduced = false, false
	scareState.RunId, scareState.Scare = "replay", nil
	scares:Update(scareState)
	check(not scares.frame.Visible and not scares.seen, "new run clears scare identity")
	soundTemplate.Parent = nil
	scareState.Scare = { Id = "coming", At = h.time + 0.25, Variant = 3, Kind = "Visitor" }
	scares:Update(scareState)
	check(not scares.frame.Visible and not scares.seen, "upcoming cue waits for its hit timestamp")
	h.time += 0.3
	scares:Update(scareState)
	check(
		scares.sound == scares.fallback and scares.sound.Played and scares.lunge and scares.camera.FieldOfView == 43,
		"fallback impact and viewport lunge work without uploaded scare assets"
	)
	local ownedImpact = scares.fallback
	h.time += 1
	scares:Update(scareState)
	check(
		not scares.frame.Visible and not ownedImpact.Played and ownedImpact.Parent,
		"impact sound is stopped and pooled after the hit"
	)
	scareState.Event = { Id = "knock", Kind = "Knocks", Minor = true, StartedAt = h.time, EndsAt = h.time + 6 }
	scares:Update(scareState)
	check(
		scares.ambient.Played and scares.ambient.Parent == world.stations.StaffDoor,
		"knocks are localized at the door"
	)
	h.time += 0.6
	scares:Update(scareState)
	check(scares.knock == 2, "knock beats advance without per-frame callbacks or delayed tasks")
	scareState.Event = nil
	scares:Update(scareState)
	check(not scares.ambient.Played, "anomaly audio stops when event ends")
	scares:Destroy()
	soundTemplate:Destroy()
	check(scares.frame.Parent ~= nil, "scare cleanup preserves authored viewport and caption")
	check(
		savedScareCamera.Parent == scares.viewport
			and savedScareCamera.CFrame == savedScareFrame
			and savedScareCamera.FieldOfView == savedScareFOV,
		"scare teardown restores the borrowed camera"
	)
	savedScareCamera.Name, scares.viewport.CurrentCamera = "AuthoredScareCamera", nil
	local renamedScare = ScarePresentation.new(scares.d, playerGui)
	check(
		renamedScare.camera == savedScareCamera and not renamedScare.ownsCamera,
		"scare camera lookup does not depend on the name Camera"
	)
	renamedScare:Destroy()
	check(
		scares.viewport.CurrentCamera == nil,
		"borrowed scare camera teardown restores the original nil viewport reference"
	)
	savedScareCamera.Parent = nil
	local originalChildren = #scares.viewport:GetChildren()
	local missingScare = ScarePresentation.new(scares.d, playerGui)
	local runtimeCamera = missingScare.camera
	check(
		missingScare.ownsCamera
			and runtimeCamera.Parent == scares.viewport
			and #scares.viewport:GetChildren() == originalChildren + 1,
		"missing scare camera creates one runtime camera without rebuilding viewport geometry"
	)
	missingScare:Update({ RunId = "missing-camera", Scare = { Id = "test", Kind = "Visitor", At = h.time } })
	check(
		missingScare.frame.Visible and missingScare.lunge and runtimeCamera.FieldOfView == 43,
		"scare animation works with a runtime camera"
	)
	check(
		camera.CFrame == original and workspace.CurrentCamera == camera,
		"runtime scare camera never changes world camera"
	)
	missingScare:Destroy()
	missingScare:Destroy()
	check(
		runtimeCamera.Parent == nil
			and scares.viewport.CurrentCamera == nil
			and #scares.viewport:GetChildren() == originalChildren,
		"scare cleanup deletes only its own camera and is idempotent"
	)
	scares.viewport.CurrentCamera = camera
	local copiedReference = ScarePresentation.new(scares.d, playerGui)
	check(
		copiedReference.ownsCamera and copiedReference.camera ~= camera,
		"copied world camera reference is not borrowed by scare animations"
	)
	copiedReference:Destroy()
	check(
		scares.viewport.CurrentCamera == camera and camera.CFrame == original,
		"copied reference is restored without modifying the world camera"
	)
	scares.viewport.CurrentCamera, savedScareCamera.Parent = savedScareCamera, scares.viewport
	-- Authored HUD scare uses the real monster, its saved framing, and a slow viewport-only zoom.
	local newHud = h.env.Instance.new("ScreenGui")
	newHud.Name, newHud.Parent = "HUD", playerGui
	local oldScareParent = scares.frame.Parent
	scares.frame.Parent = newHud
	local oldHead = scares.head
	oldHead.Parent = nil
	local monster = h.env.Instance.new("Model")
	monster.Name, monster.Parent = "ScaryNPC", scares.viewport
	local monsterRoot = h.env.Instance.new("Part")
	monsterRoot.Name, monsterRoot.Parent, monsterRoot.CFrame = "RootPart", monster, Roblox.CFrame.new(8, 3, -2)
	monster.Archivable = false
	local originalNew = h.env.Instance.new
	local playedTracks = {}
	h.env.Instance.new = function(class)
		local item = originalNew(class)
		if class == "Animator" then
			item.LoadAnimation = function(_, clip)
				local track = {
					Id = clip.AnimationId,
					Play = function(self)
						self.played = true
					end,
					Stop = function(self)
						self.stopped = true
					end,
					Destroy = function(self)
						self.destroyed = true
					end,
				}
				table.insert(playedTracks, track)
				return track
			end
		end
		return item
	end
	h.skipPrototypeAssets = true
	local animated = ScarePresentation.new(scares.d, view.gui)
	h.skipPrototypeAssets = false
	check(
		animated.frame.Parent == newHud
			and animated.actor
			and not animated.head
			and monster.Parent == nil
			and monster.Archivable == false,
		"new scare binds HUD and pools an animated copy without requiring old Part head"
	)
	check(
		animated.actor.model.RootPart.CFrame == monsterRoot.CFrame and animated.actor.world:IsA("WorldModel"),
		"monster keeps authored framing inside animation-enabled WorldModel"
	)
	local animState = { RunId = "monster-run", Scare = { Id = "animation", Kind = "Visitor", At = h.time } }
	animated:Update(animState)
	local track = animated.actor.track
	check(
		track and track.played and animated.zoom and animated.untilAt == h.time + 2.5,
		"monster plays a supplied animation throughout a bounded slow zoom"
	)
	check(
		animated.camera.CFrame == savedScareFrame
			and animated.camera.FieldOfView == math.max(1, savedScareFOV * 0.7)
			and camera.CFrame == original,
		"new scare preserves authored camera angle and never changes world camera"
	)
	local ids = {}
	for _, clip in ipairs(h:load("src/GClient/Effects/MonsterAnimations.luau").Clips) do
		ids["rbxassetid://" .. clip.Id] = true
	end
	check(ids[track.Id], "scare chooses only supplied Monster 2 animations")
	animated:Update(animState)
	check(animated.actor.track == track and #playedTracks == 1, "repeated snapshot never restarts or reloads animation")
	animated.zoom.Completed:Fire()
	reduced = true
	animated:Update(animState)
	check(
		track.stopped
			and not animated.zoom
			and not animated.viewport.Visible
			and animated.camera.FieldOfView == savedScareFOV,
		"reduced motion stops animation/zoom and restores FOV"
	)
	reduced = false
	animated:Destroy()
	check(
		track.destroyed and monster.Parent == scares.viewport and animated.actor.world.Parent == nil,
		"scare teardown releases tracks and restores the original rig"
	)
	h.env.Instance.new = originalNew
	monster:Destroy()
	oldHead.Parent, scares.frame.Parent = scares.viewport, oldScareParent
	newHud:Destroy()
	check(
		world.workshop:GiveGear(p, "Tester") and world.workshop:GiveGear(p, "Screwdriver"),
		"workshop issues separate reusable kit Tools"
	)
	local tester = world.workshop.gear[p].Tester
	local counterfeit = tester:Clone()
	counterfeit.Parent = backpack
	tester.Parent = nil
	check(
		not world.workshop:HasGear(p, "Tester") and world.workshop:HasGear(p, "Screwdriver"),
		"kit possession checks actual server-issued Tool identity"
	)
	world.workshop:ClearGear(p)
	check(counterfeit.Parent == backpack and not tester.Parent, "kit cleanup preserves unrelated tools")
	counterfeit:Destroy()
	local sent, args
	local stationUi = h:load("src/GClient/Interaction/StationInteractionController.luau").new({
		workspace = workspace,
		player = p,
		tweens = presentation.d.tweens,
		render = { RenderStepped = renderSignal },
		input = { InputBegan = inputSignal },
		reduced = function()
			return reduced
		end,
		menuOpen = function()
			return menu
		end,
		send = function(action, payload)
			sent, args = action, payload
		end,
	}, playerGui)
	local clock = world.stations.Timeclock
	clock.InteractionCamera.WorldCFrame = clock.CFrame * clock.InteractionCamera.CFrame
	root.Position, humanoid.MoveDirection = clock.Position + Roblox.Vector3.new(0, 0, 3), Roblox.Vector3.zero
	local inspecting = {
		Alive = true,
		Phase = "Tutorial",
		Focus = { Id = "clock1", Station = "Timeclock", EndsAt = h.time + 30 },
	}
	stationUi:Update(inspecting, false)
	check(
		stationUi.panel.Visible
			and camera.CameraType == "CameraType.Scriptable"
			and camera.CFrame == clock.InteractionCamera.WorldCFrame,
		"timeclock interaction zooms into authored marker"
	)
	stationUi.panel.ClockIn.Activated:Fire()
	check(sent == "ClockIn" and args.FocusId == "clock1", "clock-in button sends current inspection identity")
	inspecting.Focus = nil
	stationUi:Update(inspecting, false)
	check(
		camera.CameraType == "CameraType.Custom" and camera.CFrame == original and not stationUi.panel.Visible,
		"successful stamp restores the original camera"
	)
	inspecting.Focus = { Id = "clock2", Station = "Timeclock", EndsAt = h.time + 30 }
	stationUi:Update(inspecting, false)
	humanoid.MoveDirection = Roblox.Vector3.new(1, 0, 0)
	renderSignal:Fire()
	check(
		sent == "CloseFocus" and not stationUi.saved and not stationUi.panel.Visible,
		"walking releases timeclock camera immediately"
	)
	humanoid.MoveDirection, reduced = Roblox.Vector3.zero, true
	inspecting.Focus.Id = "clock3"
	stationUi:Update(inspecting, false)
	check(
		stationUi.panel.Visible and camera.CameraType == "CameraType.Custom",
		"reduced motion retains clickable timecard without camera override"
	)
	menu = true
	stationUi:Update(inspecting, false)
	menu = false
	stationUi:Update(inspecting, false)
	check(not stationUi.panel.Visible, "dismissed clock visit never recaptures after closing menu")
	stationUi:Destroy()
	reduced = false
	check(
		stationUi.panel.Parent ~= nil and not stationUi.frame,
		"clock teardown disconnects input and camera callbacks"
	)
	local taskInput = { InputChanged = signal(), InputEnded = signal() }
	local puzzleUi = h:load("src/GClient/Repair/PuzzleView.luau").new(playerGui, function(action, payload)
		sent, args = action, payload
	end, {
		input = taskInput,
		reduced = function()
			return reduced
		end,
	})
	camera.ViewportSize = Roblox.Vector2.new(1100, 800)
	local puzzleRules = h:load("src/GServer/Repair/RepairPuzzles.luau")
	local working = {
		Alive = true,
		Seated = true,
		Work = {
			Id = "work1",
			OrderId = "phone",
			Station = "Bench",
			Puzzle = puzzleRules.Snapshot(puzzleRules.New("Repair", "Speaker", 2)),
		},
	}
	puzzleUi:Update(working, false, false)
	check(
		puzzleUi.panel.Visible and string.find(puzzleUi.tasks.buttons[1].Text, "WIRE"),
		"speaker puzzle renders distinct wire ends and sockets"
	)
	puzzleUi.tasks.buttons[1].Activated:Fire()
	puzzleUi.tasks.buttons[5].Activated:Fire()
	check(
		sent == "PuzzleInput" and args.Move == 11 and args.PuzzleRevision == 0 and args.WorkId == "work1",
		"puzzle controls submit task-scoped intent"
	)
	puzzleUi:Update(working, true, false)
	sent = nil
	puzzleUi.tasks.buttons[1].Activated:Fire()
	puzzleUi.tasks.buttons[5].Activated:Fire()
	check(sent == nil, "busy puzzle cannot queue overlapping inputs")
	puzzleUi:Update(working, false, false)
	local taskUi = puzzleUi.tasks
	taskUi.root.AbsolutePosition, taskUi.root.AbsoluteSize = Roblox.Vector2.new(100, 100), Roblox.Vector2.new(300, 180)
	for i, button in ipairs(taskUi.buttons) do
		button.AbsolutePosition = Roblox.Vector2.new(i <= 4 and 100 or 310, 100 + (i - 1) % 4 * 45)
		button.AbsoluteSize = Roblox.Vector2.new(90, 39)
	end
	local finger = { UserInputType = h.env.Enum.UserInputType.Touch, Position = Roblox.Vector3.new(145, 163, 0) }
	taskUi.buttons[1].InputBegan:Fire(finger)
	finger.Position = Roblox.Vector3.new(355, 163, 0)
	taskInput.InputChanged:Fire(finger)
	check(
		taskUi.ghost.Visible and taskUi.ghost.Position.X.Offset == 255,
		"touch drag previews movement locally with inset-independent coordinates"
	)
	taskInput.InputEnded:Fire({ UserInputType = h.env.Enum.UserInputType.Touch, Position = finger.Position })
	check(sent == nil and taskUi.drag ~= nil, "unrelated second finger cannot complete the drag")
	taskInput.InputEnded:Fire(finger)
	check(
		sent == "PuzzleInput" and args.Move == 11 and not taskUi.ghost.Visible,
		"release submits one source-to-socket move"
	)
	sent = nil
	finger.Position = Roblox.Vector3.new(145, 163, 0)
	taskUi.buttons[1].InputBegan:Fire(finger)
	working.Work.Id = "work2"
	puzzleUi:Update(working, false, false)
	taskInput.InputEnded:Fire(finger)
	check(sent == nil and not taskUi.drag, "new task identity cancels an old held drag")
	working.Event = { Kind = "Visitor" }
	puzzleUi:Update(working, false, false)
	check(not puzzleUi.panel.Visible, "hazard hides repair controls for escape")
	working.Event = nil
	working.Work.Id = "memory"
	working.Work.Puzzle = puzzleRules.Snapshot(puzzleRules.New("Test", "Battery", 4, 4, h.time))
	puzzleUi:Update(working, false, false)
	check(
		not taskUi.buttons[1].Active and not string.find(puzzleUi.hint.Text, "LABEL:", 1, true),
		"memory demonstration disables answers and does not print a permanent solution"
	)
	reduced = true
	puzzleUi:Update(working, false, false)
	for _, button in ipairs(taskUi.buttons) do
		check(button.BackgroundColor3 == Roblox.Color3.new(0, 0, 0), "reduced flashes uses text-only memory cues")
	end
	h.time = working.Work.Puzzle.RevealUntil + 1
	puzzleUi:Update(working, false, false)
	check(
		taskUi.buttons[1].Active and taskUi.check.Text == "WATCH AGAIN",
		"memory controls unlock after server demonstration time"
	)
	working.Work.Id = "dial"
	working.Work.Puzzle = puzzleRules.Snapshot(puzzleRules.New("Install", "Battery", 2, 4, h.time))
	puzzleUi:Update(working, false, false)
	check(taskUi.dials[1].Visible and not taskUi.buttons[4].Visible, "data link uses three physical dial faces")
	working.Work.Id = "circuit"
	working.Work.Puzzle = puzzleRules.Snapshot(puzzleRules.New("Repair", "Keypad", 2, 4, h.time))
	puzzleUi:Update(working, false, false)
	check(
		not taskUi.dials[1].Visible and taskUi.buttons[4].Visible and taskUi.buttons[1].Text == "START",
		"task changes reset pooled geometry and reveal circuit controls"
	)
	local benchRules = h:load("src/GServer/Repair/BenchTasks.luau")
	local function showBench(kind, seed)
		working.Work.Id = "extra_" .. kind
		working.Work.Puzzle = puzzleRules.Snapshot(benchRules.New(kind, seed or 3, h.time))
		taskUi.ignoreClickUntil = nil
		sent = nil
		puzzleUi:Update(working, false, false)
	end
	for _, kind in ipairs({
		"Clean",
		"Debris",
		"Broken",
		"Screen",
		"SIM",
		"Fuse",
		"Charger",
		"Sort",
		"Assembly",
		"Screws",
		"Buttons",
		"PhoneNumber",
		"Waves",
		"Meter",
		"Stamp",
		"Speaker",
	}) do
		showBench(kind)
		check(taskUi.root.Visible and puzzleUi.panel.Visible, "new bench task renders: " .. kind)
		check(not puzzleUi.buttons[1].Visible, "only one task surface is visible: " .. kind)
	end
	showBench("PhoneNumber")
	taskUi.buttons[10].Activated:Fire()
	check(
		args.Move == 10 and taskUi.buttons[10].Text == "0" and taskUi.buttons[11].Visible,
		"phone keypad includes zero and clear"
	)
	showBench("SIM", 1)
	taskUi.check.Activated:Fire()
	check(args.Move == 7, "SIM rotation uses discrete server control")
	taskUi.buttons[1].Activated:Fire()
	taskUi.buttons[4].Activated:Fire()
	check(args.Move == 11, "SIM tap-select then slot matches drag intent")
	showBench("Screen")
	taskUi.buttons[1].InputBegan:Fire(finger)
	working.Work.Puzzle.Phase, working.Work.Puzzle.Revision = 2, 1
	puzzleUi:Update(working, false, false)
	taskInput.InputEnded:Fire(finger)
	check(not taskUi.drag and sent == nil, "screen stage change cancels old drag")
	working.Work.Puzzle.Phase, working.Work.Puzzle.Revision = 3, 2
	puzzleUi:Update(working, false, false)
	check(taskUi.buttons[4].Visible and taskUi.buttons[4].Text == "CLIP 4", "screen finish exposes all four clips")
	showBench("Waves")
	check(
		taskUi.extra.graph.Visible and taskUi.extra.segments[1][1].Visible and taskUi.extra.segments[2][1].Visible,
		"wave task draws reference and adjustable traces"
	)
	showBench("Meter")
	local firstMeterPosition = taskUi.extra.needle.Position
	h.time += 0.5
	puzzleUi:Update(working, false, false)
	check(taskUi.extra.needle.Position ~= firstMeterPosition, "meter predicts drift without per-frame server input")
	showBench("Speaker")
	reduced = false
	h.time = working.Work.Puzzle.RevealAt + 0.1
	puzzleUi:Update(working, false, false)
	check(
		taskUi.extra.tone.Played and not taskUi.buttons[1].Active,
		"speaker demonstration plays tone and locks answers"
	)
	check(
		not string.find(puzzleUi.hint.Text, "LABEL:", 1, true),
		"speaker sequence is not printed as a permanent answer"
	)
	reduced = true
	puzzleUi:Update(working, false, false)
	check(not taskUi.extra.tone.Played, "reduced effects provides silent numbered speaker cues")
	working.Event = { Kind = "Blackout" }
	puzzleUi:Update(working, false, false)
	check(not taskUi.root.Visible and not taskUi.extra.tone.Played, "interruption stops sound and hides controls")
	working.Event = nil
	check(
		world.direct.Part_Battery:GetAttribute("DPU_Direct") == "Part_Battery"
			and world.prompts.Bench.HoldDuration == 0.4
			and world.prompts.Fuse.HoldDuration == 1.2
			and world.direct.Timeclock:GetAttribute("DPU_Direct") == "Timeclock",
		"small objects use direct interactions; bench and fuse retain deliberate prompts"
	)
	puzzleUi:Destroy()
	sent = nil
	taskInput.InputEnded:Fire(finger)
	check(sent == nil and taskUi.root.Parent ~= nil, "destroy disconnects task input and preserves authored UI")
	-- Authored subtitle integration is covered by PrototypeBindings and Dialogue.
	-- Physical inputs use the same server tasks; rendered travel carries no authority.
	local physicalInput = {
		InputBegan = signal(),
		InputChanged = signal(),
		InputEnded = signal(),
		WindowFocusReleased = signal(),
	}
	local lastInput = h.env.Enum.UserInputType.MouseMovement
	physicalInput.GetLastInputType = function()
		return lastInput
	end
	local cameraReady, physicalCalls = true, 0
	local physicalState = { RunId = "physical", Phase = "Night", Alive = true, Seated = true, SeatStation = "Bench" }
	local physicalPuzzle, physicalMove, physicalPayload
	local physical = h:load("src/GClient/Repair/PhysicalRepairView.luau").new(playerGui, function(action, payload)
		check(action == "PuzzleInput", "physical tasks use the existing scoped action")
		physicalCalls += 1
		physicalMove, physicalPayload = payload.Move, payload
	end, {
		workspace = workspace,
		player = p,
		input = physicalInput,
		render = { RenderStepped = renderSignal },
		tweens = presentation.d.tweens,
		reduced = function()
			return reduced
		end,
		menuOpen = function()
			return menu
		end,
		cameraReady = function()
			return cameraReady
		end,
	})
	humanoid.Sit, humanoid.SeatPart = true, world.workshop.seat
	local benchTasks = h:load("src/GServer/Repair/BenchTasks.luau")
	local function startPhysical(puzzle)
		physicalPuzzle = puzzle
		physicalState.Work = {
			Id = "physical-" .. tostring(physicalCalls) .. puzzle.Kind,
			OrderId = "phone-3d",
			Station = "Bench",
			UserId = p.UserId,
			Puzzle = puzzleRules.Snapshot(puzzle),
		}
		check(physical:Update(physicalState, false, false), "supported physical task takes over the button panel")
	end
	camera.ViewportPointToRay = function(_, x, y)
		return {
			Origin = physical.frameOfPhone:PointToWorldSpace(Roblox.Vector3.new(x, 5, y)),
			Direction = physical.frameOfPhone:VectorToWorldSpace(Roblox.Vector3.new(0, -1, 0)),
		}
	end
	local function fingerAt(node)
		return {
			UserInputType = h.env.Enum.UserInputType.Touch,
			Position = Roblox.Vector3.new(node.Spec.Position.X, node.Spec.Position.Z, 0),
		}
	end
	local function gesture(source, destination)
		local finger = fingerAt(source)
		physicalInput.InputBegan:Fire(finger, false)
		local before = physicalCalls
		finger.Position = Roblox.Vector3.new(destination.X, destination.Z, 0)
		physicalInput.InputChanged:Fire(finger)
		renderSignal:Fire()
		check(physicalCalls == before, "3D preview never sends pointer movement over the network")
		physicalInput.InputEnded:Fire(finger)
	end
	local function acceptPhysical()
		local accepted = puzzleRules.Input(physicalPuzzle, physicalMove, physicalPayload.PuzzleRevision, h.time)
		check(
			accepted and physicalPayload.WorkId == physicalState.Work.Id and physicalPayload.OrderId == "phone-3d",
			"physical gesture is validated by current server work and revision"
		)
		physicalState.Work.Puzzle = puzzleRules.Snapshot(physicalPuzzle)
		physical:Update(physicalState, false, false)
	end
	startPhysical(puzzleRules.New("Repair", "Battery", 2))
	local physicalFolder = physical.folder
	local loose = physical.nodes.item1
	local finger = fingerAt(loose)
	physicalInput.InputBegan:Fire(finger, false)
	finger.Position = Roblox.Vector3.new(-0.8, 0.3, 0)
	physicalInput.InputChanged:Fire(finger)
	renderSignal:Fire()
	check(
		(loose.Part.CFrame.Position - physical.frameOfPhone:PointToWorldSpace(loose.Spec.Position)).Magnitude > 0.4,
		"drag moves a real local 3D part above the phone"
	)
	physicalInput.InputEnded:Fire({
		UserInputType = h.env.Enum.UserInputType.Touch,
		Position = finger.Position,
	})
	check(physical.drag ~= nil and physicalCalls == 0, "second finger cannot release someone else's 3D drag")
	physicalInput.WindowFocusReleased:Fire()
	check(not physical.drag and physicalCalls == 0, "losing window focus cancels physical drag without a move")
	local bay = table.find(physicalPuzzle.Slots, 1)
	gesture(loose, physical.nodes["slot" .. bay].Spec.Position)
	check(physicalMove == 10 + bay and physicalCalls == 1, "battery release submits one matching bay move")
	gesture(loose, physical.nodes["slot" .. bay].Spec.Position)
	check(physicalCalls == 1, "pending physical move cannot send duplicate gestures")
	acceptPhysical()
	check(
		physicalPuzzle.Placed[1] and physical.folder == physicalFolder and physical.nodes.item1 == loose,
		"accepted placement reuses the scene and snaps the existing part into its bay"
	)
	local beforeStale = physicalCalls
	physicalInput.InputBegan:Fire(fingerAt(physical.nodes.item2), false)
	physicalState.Work.Id = "replacement-work"
	physical:Update(physicalState, false, false)
	physicalInput.InputEnded:Fire(finger)
	check(
		not physical.drag and physicalCalls == beforeStale and not physicalFolder.Parent,
		"work replacement destroys old local pieces and cancels held gestures"
	)
	startPhysical(benchTasks.New("Screws", 3, h.time))
	local screw = physical.nodes.screw1
	gesture(screw, screw.Spec.Position)
	check(not physical.submitted, "clicking a physical screw without turning cannot tighten it")
	gesture(screw, screw.Spec.Position + Roblox.Vector3.new(0.35, 0, 0))
	acceptPhysical()
	check(physicalPuzzle.Turns[1] == 1, "sideways screw gesture advances one server notch")
	startPhysical(benchTasks.New("Clean", 3, h.time))
	gesture(physical.nodes.dirt1, physical.nodes.dirt1.Spec.Position + Roblox.Vector3.new(0.5, 0, 0))
	acceptPhysical()
	check(physicalPuzzle.Dirt[1] == 1, "scrubbing changes a real patch only after server validation")
	startPhysical(benchTasks.New("Screen", 3, h.time))
	gesture(physical.nodes.screen, physical.nodes.socket.Spec.Position)
	acceptPhysical()
	check(
		physicalPuzzle.Phase == 2 and physical.nodes.screen.Spec.Position.X < -1,
		"removing a display reveals a replacement beside the phone"
	)
	gesture(physical.nodes.screen, physical.nodes.socket.Spec.Position)
	acceptPhysical()
	check(
		physicalPuzzle.Phase == 3 and physical.nodes.clip1 and not physical.nodes.screen,
		"fitting the display changes to physical clip targets"
	)
	startPhysical(benchTasks.New("Debris", 3, h.time))
	gesture(physical.nodes.item1, physical.nodes.waste.Spec.Position)
	acceptPhysical()
	check(
		physicalPuzzle.Removed[1] and physical.nodes.item1.Part.Transparency == 1,
		"waste tray removes accepted debris"
	)
	startPhysical(puzzleRules.New("Repair", "Speaker", 2))
	check(physical.nodes.item1.Wire ~= nil, "wire task has a real cord attached to its draggable end")
	local wireBay = table.find(physicalPuzzle.Slots, 1)
	gesture(physical.nodes.item1, physical.nodes["slot" .. wireBay].Spec.Position)
	acceptPhysical()
	check(physicalPuzzle.Placed[1], "physical wire connects through server matching rules")
	startPhysical(benchTasks.New("Assembly", 3, h.time))
	local boardBay = table.find(physicalPuzzle.Slots, 1)
	gesture(physical.nodes.item1, physical.nodes["slot" .. boardBay].Spec.Position)
	acceptPhysical()
	check(physicalPuzzle.Progress == 1, "3D ordered assembly places the circuit board first")
	startPhysical(puzzleRules.New("Diagnose", "Speaker", 3))
	gesture(physical.nodes.probe1, physical.nodes.probe1.Spec.Position)
	acceptPhysical()
	check(
		physicalPuzzle.Tested[1] and physical.nodes.probe1.Label.Text == "BATTERY\n" .. physicalPuzzle.Readings[1],
		"physical probe displays only a reading the server has revealed"
	)

	startPhysical(puzzleRules.New("Diagnose", "Speaker", 3, 4, h.time, true, false, true))
	check(
		physical.nodes.screw1.Spec.Source == world.repairPhone.Screws.Screw1
			and physical.nodes.screw1.Part ~= physical.nodes.screw1.Spec.Source
			and physical.nodes.screw1.Part.Size == world.repairPhone.Screws.Screw1.Size,
		"physical screw gesture uses authored mesh without resizing source"
	)
	local screwNode = physical.nodes.screw1
	local hitTest = { nodes = { screwNode } }
	local radius = screwNode.Spec.HitRadius
	check(
		radius <= 0.12
			and physical.Hit(hitTest, screwNode.Spec.Position) == screwNode
			and physical.Hit(hitTest, screwNode.Spec.Position + Roblox.Vector3.new(radius + 0.01, 0, 0)) == nil,
		"screws have small circular hit targets without the old wide padding"
	)
	local savedRay = camera.ViewportPointToRay
	camera.ViewportPointToRay = function()
		return {
			Origin = physical.frameOfPhone:PointToWorldSpace(screwNode.Spec.Position + Roblox.Vector3.new(3, 5, 2)),
			Direction = physical.frameOfPhone:VectorToWorldSpace(Roblox.Vector3.new(-3, -5, -2).Unit),
		}
	end
	local picked, pickedPoint = physical:Pick(Roblox.Vector2.zero)
	check(
		picked == screwNode and (pickedPoint - screwNode.Spec.Position).Magnitude < 0.001,
		"angled camera targets the actual screw height without a table-plane pointer offset"
	)
	camera.ViewportPointToRay = savedRay
	-- Mouse event coordinates differ from the live cursor by the GUI inset.
	-- Exercise press, render-driven movement, release and the single-request guard.
	local cursor = Roblox.Vector2.zero
	physicalInput.GetMouseLocation = function()
		return cursor
	end
	local mouseRay = camera.ViewportPointToRay
	camera.ViewportPointToRay = function(_, x, y)
		return mouseRay(camera, (x - 500) / 100, (y - 350) / 100)
	end
	for _, inset in ipairs({ 0, 36, 58 }) do
		for index = 1, 4 do
			local node = physical.nodes["screw" .. index]
			cursor = Roblox.Vector2.new(500 + node.Spec.Position.X * 100, 350 + node.Spec.Position.Z * 100)
			local button = {
				UserInputType = h.env.Enum.UserInputType.MouseButton1,
				Position = Roblox.Vector3.new(cursor.X, cursor.Y - inset, 0),
			}
			physicalInput.InputBegan:Fire(button, true)
			check(not physical.drag, "processed UI clicks cannot start a screw gesture")
			physicalInput.InputBegan:Fire(button, false)
			check(
				physical.drag and physical.drag.Node == node,
				"live mouse selects the visible screw without a GUI-inset offset"
			)
			physical:CancelDrag()
		end
	end
	cursor = Roblox.Vector2.new(500 + screwNode.Spec.Position.X * 100, 350 + screwNode.Spec.Position.Z * 100)
	local mouseButton = {
		UserInputType = h.env.Enum.UserInputType.MouseButton1,
		Position = Roblox.Vector3.new(cursor.X, cursor.Y - 58, 0),
	}
	local beforeMouse = physicalCalls
	physicalInput.InputBegan:Fire(mouseButton, false)
	cursor += Roblox.Vector2.new(15, 0)
	physicalInput.InputChanged:Fire({
		UserInputType = h.env.Enum.UserInputType.MouseMovement,
		Position = mouseButton.Position,
	})
	renderSignal:Fire()
	check(
		physical.drag and math.abs(physical.drag.Last.X - physical.drag.Start.X - 0.15) < 0.001,
		"mouse movement uses live coordinates instead of offset event coordinates"
	)
	cursor += Roblox.Vector2.new(20, 0)
	renderSignal:Fire()
	check(
		physical.drag
			and math.abs(physical.drag.Last.X - physical.drag.Start.X - 0.35) < 0.001
			and physicalCalls == beforeMouse,
		"existing render loop tracks latest cursor without stale button positions or movement remotes"
	)
	physicalInput.InputEnded:Fire(mouseButton)
	check(
		physicalCalls == beforeMouse + 1 and physicalMove == 1 and not physical.drag,
		"release uses current mouse position and submits exactly one screw turn"
	)
	physicalInput.InputEnded:Fire(mouseButton)
	check(physicalCalls == beforeMouse + 1, "duplicate mouse release cannot resubmit the screw turn")
	physical.submitted = nil -- Keep the original untouched puzzle for the touch/server checks below.
	camera.ViewportPointToRay = savedRay
	renderSignal:Fire()
	check(screwNode.Indicator and screwNode.Indicator.gui.Enabled, "screw has non-blocking screen indicator")
	local indicator = h:load("src/GClient/Repair/ScrewIndicator.luau")
	indicator.Update(screwNode.Indicator, screwNode.Spec, true, 0.5, h.time, false)
	check(screwNode.Indicator.ring.Rotation == 180, "ring rotation follows screw turn progress")
	indicator.Update(screwNode.Indicator, screwNode.Spec, false, 0, h.time, true)
	check(screwNode.Indicator.ring.Rotation == 0, "reduced motion disables ring rotation")
	for index = 1, 4 do
		local node = physical.nodes["screw" .. index]
		gesture(node, node.Spec.Position + Roblox.Vector3.new(0.4, 0, 0))
		acceptPhysical()
	end
	check(
		physicalPuzzle.DeviceStage == "RemoveCover" and physical.nodes.screen.Spec.Source == world.repairPhone.BackCover,
		"four authored screws lead to actual back cover"
	)
	gesture(physical.nodes.screen, physical.nodes.socket.Spec.Position)
	acceptPhysical()
	check(
		physicalPuzzle.DeviceStage == "RemoveBattery" and physical.nodes.screen.Spec.Source == world.repairPhone.Battery,
		"dragging cover permits actual battery removal"
	)
	gesture(physical.nodes.screen, physical.nodes.socket.Spec.Position)
	acceptPhysical()
	check(
		physicalPuzzle.DeviceStage == "Probes" and not physical.folder and not physical.mode.Visible,
		"battery removal switches away from floating physical probe/replace blocks"
	)
	local diagnosticPayload
	local diagnosticUi = h:load("src/GClient/Repair/PuzzleView.luau").new(playerGui, function(_, payload)
		diagnosticPayload = payload
	end, {
		player = p,
		tweens = presentation.d.tweens,
		reduced = function()
			return reduced
		end,
	})
	diagnosticUi:Update(physicalState, false, false)
	check(
		diagnosticUi.panel.Visible
			and diagnosticUi.tasks.dials[1].Visible
			and diagnosticUi.tasks.buttons[1].Text:find("RUN TEST")
			and not diagnosticUi.tasks.buttons[4].Active,
		"on-screen diagnosis starts with meters and locked replacement choices"
	)
	check(
		not puzzleRules.Input(physicalPuzzle, 4, physicalPuzzle.Revision, h.time),
		"server rejects selecting a replacement before completing all tests"
	)
	for index = 1, 3 do
		diagnosticUi.tasks.buttons[index].Activated:Fire()
		check(
			diagnosticPayload.Move == index and diagnosticPayload.WorkId == physicalState.Work.Id,
			"diagnostic card sends revision-scoped test intent"
		)
		check(
			puzzleRules.Input(physicalPuzzle, index, diagnosticPayload.PuzzleRevision, h.time),
			"server accepts component test"
		)
		physicalState.Work.Puzzle = puzzleRules.Snapshot(physicalPuzzle)
		diagnosticUi:Update(physicalState, false, false)
	end
	check(
		diagnosticUi.tasks.buttons[2].Text:find("FAULT")
			and diagnosticUi.tasks.buttons[1].Text:find("PASS")
			and diagnosticUi.tasks.buttons[5].Active,
		"server readings drive visible fault and unlocked choices"
	)
	diagnosticUi.tasks.buttons[5].Activated:Fire()
	local accepted, solved = puzzleRules.Input(physicalPuzzle, 5, diagnosticPayload.PuzzleRevision, h.time)
	check(accepted and solved, "choosing the faulty speaker completes diagnosis on server")
	diagnosticUi:Update(physicalState, false, true)
	check(
		not diagnosticUi.panel.Visible and next(diagnosticUi.tasks.diagnosis.tweens) == nil,
		"blocking UI cancels diagnosis animations"
	)
	diagnosticUi:Destroy()
	startPhysical(benchTasks.New("Screen", 3, h.time))
	physical.mode.Activated:Fire()
	check(not physical:Update(physicalState, false, false) and not physical.folder, "button fallback clears 3D pieces")
	physical.mode.Activated:Fire()
	physical:Update(physicalState, false, false)
	lastInput = h.env.Enum.UserInputType.Gamepad1
	check(
		not physical:Update(physicalState, false, false),
		"controller input retains the existing selectable button tasks"
	)
	lastInput = h.env.Enum.UserInputType.MouseMovement
	physical:Update(physicalState, false, false)
	local finalFolder = physical.folder
	cameraReady = false
	renderSignal:Fire()
	check(
		not physical.folder and not finalFolder.Parent and not physical.render,
		"camera release immediately removes 3D props and its active-only render callback"
	)
	check(
		world.repairPhone.Battery.LocalTransparencyModifier == 0.2,
		"physical cleanup restores original phone transparency"
	)
	physical:Destroy()
	check(physical.hint.Parent ~= nil and physical.mode.Parent ~= nil, "physical task teardown preserves authored UI")
	cameraReady = true
	local mixed = h:load("src/GClient/Repair/PuzzleView.luau").new(playerGui, function() end, physical.d)
	mixed:Update(physicalState, false, false)
	check(
		mixed.physical.folder and not mixed.panel.Visible,
		"physical tasks replace rather than overlay the button panel"
	)
	mixed.physical.mode.Activated:Fire()
	mixed:Update(physicalState, false, false)
	check(mixed.panel.Visible and not mixed.physical.folder, "fallback exposes the same puzzle's existing controls")
	physicalState.SeatStation = "OtherSeat"
	mixed:Update(physicalState, false, false)
	check(
		not mixed.panel.Visible and not mixed.physical.folder,
		"repair controls cannot appear at the wrong seated station"
	)
	physicalState.SeatStation = "Bench"
	physicalState.Work.UserId = 999
	mixed:Update(physicalState, false, false)
	check(
		not mixed.panel.Visible and not mixed.physical.folder,
		"neither input surface accepts another operator's work"
	)
	mixed:Destroy()
	world:Shutdown()
	check(
		workspace.Prototype.DPU_Prototype == world.folder and lighting.ClockTime == 12,
		"world cleanup preserves saved shop and restores lighting"
	)
	local template = services.ReplicatedStorage.Assets.Devices.Phone
	check(
		h:load("src/GServer/Repair/RepairTemplates.luau").Get(services.ReplicatedStorage) == template,
		"saved template is reused and preserved on shutdown"
	)
end

-- Optional activities remain available without a customer and never award repairs.
do
	local f = fixture(2)
	local a, b = f.p[1], f.p[2]
	f.run:Tick()
	f:advance(3)
	f.near[a] = "StaffDoor"
	check(f.run:Snapshot(a).Target == "StaffDoor", "outside first objective points at entry")
	check(f:act("ToggleDoor", a) and f.run.doorOpen, "unclocked staff can open the door")
	check(not f:act("ToggleDoor", b) and f.run.doorOpen, "shared door cooldown prevents competing toggles")
	check(not f:act("ClockIn", a), "cannot clock in from the doorway")
	f.near[a] = "Timeclock"
	check(f:act("ClockIn", a) and f.run:Snapshot(a).NeedsRules, "inside clock-in reveals directive")
	local revision = f.run.revision
	check(f:act("ClockIn", a) and f.run.revision == revision, "repeat stamping is idempotent")
	f:advance(1)
	f:act("ToggleDoor", b)
	check(
		f.run:Snapshot(b).NeedsClockIn and not f.run:Snapshot(b).NeedsRules,
		"another staff member must clock in independently"
	)
	check(not f:act("TuneRadio", b), "off-duty staff cannot use work activities")
	f.near[a] = "Radio"
	check(
		f:act("TuneRadio", a) and string.find(f.run:Snapshot(a).Dialogue.Text, "CITY RADIO"),
		"radio plays a readable bulletin before any customer"
	)
	check(not f.run:Snapshot(b).Scare and not f.run:Snapshot(a).Scare, "training remains free of scares")
	check(not f:act("InspectRecords", a), "optional activity checks actual station")
	f.near[a] = "DeskLamp"
	check(f:act("ToggleLamp", a) and not f.run.lampOn, "work light can be switched independently")
	f.near[a] = "Records"
	check(
		f:act("InspectRecords", a) and string.find(f.run:Snapshot(a).Notice, "SHIFT LOG"),
		"log exposes current shift facts"
	)
	check(
		f.run.repaired == 0 and f.run.revenue == 0 and not f.run.stations.Bench.order,
		"ambient interactions never pay or start a customer"
	)
end

do
	local f = fixture()
	f:start()
	f:repair()
	f.c.Events = {}
	f.run.stations.Bench.nextOrder = f.h.time + 100
	f.run.stock.Speaker = 1
	f:advance(0.6)
	check(
		f:act("Restock") and f.run.stations.Bench.work.Fault == "Speaker",
		"between-customer restock chooses the lowest shelf"
	)
	f:advance(f.c.WorkSeconds)
	check(f.run.stock.Speaker == 3 and f.run.repaired == 1, "restock fills supplies without reward farming")
	f.run.event = { Id = "test", Kind = "Blackout", EndsAt = f.h.time + 30 }
	check(f:act("InspectRecords") and f:act("TuneRadio"), "optional observation remains available during a disturbance")
	for _ = 1, 2 do
		f:advance(3)
		f:act("TuneRadio")
	end
	local scare = f.run:Snapshot(f.p[1]).Scare
	check(scare and scare.Kind == "Signal", "dead-air station delivers a personal scare at night")
	f.run:Damage(f.p[1], 1, "test")
	check(f.run:Snapshot(f.p[1]).Scare.Id == scare.Id, "nearby scare triggers cannot stack")
	f.run.event = nil
	f:advance(21)
	f.run:Damage(f.p[1], 1, "test")
	check(f.run:Snapshot(f.p[1]).Scare.Id ~= scare.Id, "later danger can create a new scare")
	for _ = 1, 3 do
		f:advance(3)
		f:act("TuneRadio")
	end
	check(f.run:Snapshot(f.p[1]).Scare.Kind == "Visitor", "revisiting dead air cannot farm radio scares")
	f.run:Finish("Dawn")
	f:act("Replay")
	f.run:Tick()
	local state = f.run:Snapshot(f.p[1])
	check(
		state.NeedsClockIn and not state.Scare and not state.Ending and not f.run.doorOpen,
		"replay resets entry, scares, and ending presentation"
	)
end

do
	local h = Harness.Environment()
	require("./PrototypeAssets").Install(h)
	local endings = h:load("src/GServer/Story/EndingRules.luau")
	local cases = {
		{ "missing_employee", "Died", 80, 1, { "Investigate" } },
		{ "line_open", "Survived", 80, 1, { "Investigate" } },
		{ "under_observation", "Survived", 50, 0, { "Investigate" } },
		{ "afterhours_witness", "Survived", 49, 0, { "Report", "Hide", "Investigate" } },
		{ "civilian_protector", "Survived", 20, 0, { "Report", "Hide" } },
		{ "loyal_employee", "Survived", 0, 0, { "Report" } },
		{ "another_morning", "Survived", 0, 0, {} },
	}
	for _, case in ipairs(cases) do
		local run = { suspicion = case[3], answered = case[4], decisions = case[5] }
		check(
			endings.Resolve(run, { Outcome = case[2] }).Id == "prototype_" .. case[1],
			"ending precedence: " .. case[1]
		)
	end
	check(
		endings.Resolve({ suspicion = 80, answered = 1, decisions = {} }, {}) == nil,
		"interrupted survivor receives no epilogue unlock"
	)
	local f = fixture(2)
	f:start()
	f:repair()
	check(not f.run:Snapshot(f.p[1]).Ending, "future ending is not exposed while alive")
	f.run:Damage(f.p[1], 100, "test")
	f.run.answered = 1
	f.run.night = 5
	f.run:Finish("Dawn")
	check(
		f.records[f.p[1]][1].Ending == "prototype_missing_employee",
		"death persists its own ending before teammates finish"
	)
	check(
		f.records[f.p[2]][1].Ending == "prototype_line_open",
		"survivor persists the team consequence with the run outcome"
	)
	f.run:Finish("Dawn")
	check(#f.records[f.p[1]] == 1 and #f.records[f.p[2]] == 1, "endings share existing once-per-run settlement")
end

do
	local f = fixture()
	f.run:Tick()
	f:advance(3)
	local p = f.p[1]
	f.near[p] = "Timeclock"
	check(not f.run:Action(p, "ClockIn", {}), "clock-in requires opening an inspection")
	check(f:act("OpenClock"), "timeclock inspection opens from physical station")
	local old = f.run:Snapshot(p).Focus.Id
	check(not f.run:Action(p, "ClockIn", { FocusId = "forged" }), "foreign timeclock session cannot stamp")
	f.near[p] = "Counter"
	f:advance(0.2)
	check(not f.run:Snapshot(p).Focus, "walking away closes server inspection")
	f.near[p] = "Timeclock"
	f:act("OpenClock")
	check(not f.run:Action(p, "ClockIn", { FocusId = old }), "old clock-in click cannot stamp a later visit")
	local current = f.run:Snapshot(p).Focus.Id
	check(
		f.run:Action(p, "ClockIn", { FocusId = current })
			and f.run:Snapshot(p).NeedsRules
			and not f.run:Snapshot(p).Focus,
		"stamp transitions from close-up to directive exactly once"
	)
end

-- Complete each physical repair path with owned tools and puzzle inputs.
do
	local f = fixture(1)
	f.gearMode.Explicit = true
	f:start()
	local p = f.p[1]
	local issued, failScrewdriver = {}, true
	local give = f.run.d.giveGear
	f.run.d.giveGear = function(player, id)
		if id == "Screwdriver" and failScrewdriver then
			return false
		end
		issued[id] = (issued[id] or 0) + 1
		return give(player, id)
	end
	f.near[p] = "Counter"
	check(
		not f:act("PickupTool", p, { Tool = "Tester" }) and next(issued) == nil,
		"kit cannot be collected from a distant station"
	)
	f.near[p], f.seated[p] = "Tools", true
	check(not f:act("PickupTool", p, { Tool = "Tester" }) and next(issued) == nil, "kit pickup requires standing")
	f.seated[p] = false
	check(
		not f:act("PickupTool", p, { Tool = "Tester" }) and f.run.players[p].Kit.Tester,
		"failed partial kit grant preserves the tool already issued"
	)
	failScrewdriver = false
	check(
		f:act("PickupTool", p, { Tool = "Tester" })
			and issued.Tester == 1
			and issued.Screwdriver == 1
			and issued.Cartridge == 1,
		"retry grants only missing kit tools"
	)
	check(
		f:act("PickupTool", p, { Tool = "Cartridge" }) and issued.Cartridge == 1,
		"duplicate requests cannot duplicate a complete kit"
	)
	f.gear[p].Tester = nil
	f.run.stations.Bench.order.Step = "Diagnose"
	check(f.run:Snapshot(p).Target == "Tools", "lost equipment directs player to the same kit")
	check(
		f:act("PickupTool", p, { Tool = "Tester" }) and issued.Tester == 2 and issued.Screwdriver == 1,
		"lost gear recovers without reissuing retained tools"
	)
	check(
		not f:act("PickupTool", p, { Tool = "BrassKey" }) and not issued.BrassKey,
		"repair kit never grants the secret key"
	)
end

for _, fault in ipairs({ "Battery", "Speaker", "Keypad" }) do
	local f = fixture(2)
	f.explicitWorkshop, f.manualPuzzles, f.gearMode.Explicit = true, true, true
	f:start()
	local p, other = f.p[1], f.p[2]
	f.run.stations.Bench.order.Fault = fault
	local function act(action, station, extra)
		f.near[p] = station
		f:advance(0.6)
		return f:act(action, p, extra)
	end
	check(act("TakeOrder", "Counter"), "interactive journey accepts " .. fault .. " phone")
	check(f.run:Snapshot(p).RequiredTool == "Tester", "first task directs staff to collect tester")
	check(
		act("PickupTool", "Tools", { Tool = "Tester" })
			and f.run.players[p].Kit.Tester
			and f.run.players[p].Kit.Screwdriver
			and f.run.players[p].Kit.Cartridge,
		"one pickup supplies the complete reusable repair kit"
	)
	check(act("Sit", "Bench") and act("Diagnose", "Bench"), "tester opens diagnostic puzzle")
	local work = f.run.stations.Bench.work
	f:advance(f.c.WorkSeconds)
	check(
		f.run.stations.Bench.work == work and f.run.stations.Bench.order.Step == "Diagnose",
		"waiting never solves the diagnostic puzzle"
	)
	check(
		not f.run:Snapshot(other).Work.Puzzle and f.run:Snapshot(p).Work.Puzzle,
		"only operator receives interactive controls"
	)
	f:advance(0.6)
	local payload = { WorkId = work.Id, OrderId = work.OrderId, PuzzleRevision = 0, Move = work.Puzzle.Answer % 3 + 1 }
	check(not f.run:Action(other, "PuzzleInput", payload), "teammate cannot submit another operator's puzzle")
	check(
		f.run:Action(p, "PuzzleInput", payload) and f.run.stations.Bench.order.Step == "Diagnose",
		"incorrect diagnosis gives feedback without completing"
	)
	f:advance(0.6)
	check(not f.run:Action(p, "PuzzleInput", payload), "duplicate input revision is rejected")
	f:solve()
	check(f.run.stations.Bench.order.Step == "Collect", "correct diagnosis unlocks matching replacement")
	f:act("Stand")
	check(act("Collect", "Part_" .. fault) and f.parts[p], "physical replacement pickup is immediate")
	check(act("DepositPart", "Bench"), "replacement is delivered before repair")
	check(act("PickupTool", "Tools", { Tool = "Screwdriver" }), "repeated kit pickup is safe")
	check(act("Sit", "Bench") and act("Repair", "Bench"), "part-specific puzzle starts with proper kit")
	check(
		f.run:Snapshot(p).Work.Interactive
			and f.run:Snapshot(p).Work.Puzzle.Kind
				== ({ Battery = "BatteryFit", Speaker = "Wires", Keypad = "Buttons" })[fault],
		"fault selects distinct interactive repair"
	)
	f:solve()
	check(
		f.run.stations.Bench.order.Step == "Secure" and f.run.stock[fault] == 3,
		"solved puzzle and fitting consume one replacement"
	)
	check(act("Secure", "Bench"), "start casing puzzle with screwdriver")
	f:solve()
	f:act("Stand")
	check(act("PickupTool", "Tools", { Tool = "Cartridge" }), "kit can be revisited without duplicating equipment")
	check(act("Sit", "Bench") and act("Install", "Bench"), "cartridge opens verification code")
	f:solve()
	check(act("Test", "Bench"), "tester opens final function puzzle")
	f:solve()
	f:act("Stand")
	f:pickup()
	check(
		act("Return", "Counter") and f.run.phase == "Night",
		"full interactive " .. fault .. " training reaches playable night"
	)
end

do
	local f = fixture()
	f.manualPuzzles = true
	f:start()
	f:act("TakeOrder")
	f:advance(0.6)
	f:act("Diagnose")
	local work = f.run.stations.Bench.work
	f:advance(f.c.PuzzleTimeout)
	check(
		not f.run.stations.Bench.work and f.run.stations.Bench.order.Step == "Diagnose",
		"abandoned puzzle times out without advancement"
	)
	f:act("Diagnose")
	check(f.run.stations.Bench.work.Id ~= work.Id, "reopening a puzzle gets a fresh task identity")
	f:act("Stand")
	check(
		not f.run.stations.Bench.work and f.run.stations.Bench.order.Step == "Diagnose",
		"standing cancels interactive work immediately"
	)
end

do
	local f = fixture()
	f.gearMode.Explicit = true
	f:start()
	local p = f.p[1]
	f.near[p] = "Secret_Locker"
	check(not f:act("Discover", p, { Secret = "Locker" }), "archive drawer requires the actual brass key")
	f.near[p] = "Tool_BrassKey"
	check(f:act("PickupTool", p, { Tool = "BrassKey" }), "small brass key can be collected independently of jobs")
	for _, id in ipairs({ "Timecard", "Tape", "Locker" }) do
		f.near[p] = "Secret_" .. id
		f:advance(1.1)
		check(f:act("Discover", p, { Secret = id }), "inspect hidden keepsake " .. id)
	end
	check(
		f.run:Snapshot(p).SecretsFound == 3 and f.evidence[p] == "shop_night_archive",
		"optional exploration unlocks existing evidence progress"
	)
	f:advance(1.1)
	f:act("Discover", p, { Secret = "Locker" })
	check(f.run:Snapshot(p).SecretsFound == 3 and f.run.revenue == 0, "rereading keepsakes cannot duplicate rewards")
	f.run.night = 5
	f.run:Finish("Dawn")
	check(
		f.records[p][1].Ending == "prototype_night_archivist",
		"all three discoveries contribute an earned alternate epilogue"
	)
	f:act("Replay")
	f.run:Tick()
	check(not next(f.gear) and f.run:Snapshot(p).SecretsFound == 0, "replay clears physical kit and run discoveries")
end

do
	local h = Harness.Environment()
	require("./PrototypeAssets").Install(h)
	local puzzles = h:load("src/GServer/Repair/RepairPuzzles.luau")
	for _, fault in ipairs({ "Battery", "Speaker", "Keypad" }) do
		local puzzle = puzzles.New("Repair", fault, 3)
		local wrongMove = puzzle.Placed and (10 + (table.find(puzzle.Slots, 1) % 3 + 1)) or 7
		local ok, solved = puzzles.Input(puzzle, wrongMove, 0)
		check(ok and not solved and puzzle.Progress == 0, "incorrect " .. fault .. " connection never completes")
		check(not puzzles.Input(puzzle, "1", puzzle.Revision), "puzzle rejects nonnumeric controls")
	end
	local f = fixture()
	f:start()
	f:act("TakeOrder")
	f:advance(0.6)
	f:act("Diagnose")
	f.gearMode.Explicit = true
	f:advance(0.25)
	check(
		not f.run.stations.Bench.work and f.run:Snapshot(f.p[1]).RequiredTool == "Tester",
		"lost kit cancels work and guides replacement pickup"
	)
	check(f.run.stations.Bench.order.Step == "Diagnose", "lost tool never grants puzzle completion")
end

do
	local h = Harness.Environment()
	require("./PrototypeAssets").Install(h)
	local Director = h:load("src/GServer/Horror/EventDirector.luau")
	local config = h:load("src/GServer/Session/GameConfig.luau").Director
	local signatures, hadScare = {}, false
	for seed = 1, 32 do
		local value, rolls = seed, 0
		local function random(low, high)
			rolls += 1
			value = (value * 48271) % 2147483647
			return low + value % (high - low + 1)
		end
		local director = Director.new(config, random)
		local before = rolls
		local calm = true
		for t = 0, config.CalmSeconds - 0.25, 0.25 do
			if director:Next(t, 90, false) then
				calm = false
			end
		end
		check(calm, "calm window has no director events")
		check(rolls == before, "calm quarter-second ticks make zero extra random rolls")
		local busyUntil, previous, lastByKind, count, scares, sequence = 0, nil, {}, 0, 0, {}
		for t = config.CalmSeconds, 359, 0.25 do
			local event = director:Next(t, seed % 4 * 25, t < busyUntil)
			if event then
				count += 1
				check(count ~= 1 or event.Minor and not event.Scare, "first interruption is a harmless false alarm")
				check(not previous or previous ~= event.Kind, "director avoids immediate repeated event types")
				check(
					not lastByKind[event.Kind] or t - lastByKind[event.Kind] >= config.KindCooldown,
					"event-specific cooldown prevents repeat farming"
				)
				check(event.Kind ~= "Visitor" or t >= config.LethalAfter, "lethal visitor cannot appear early")
				check(t >= busyUntil, "director never overlaps disturbances")
				if event.Scare then
					scares += 1
					hadScare = true
				end
				busyUntil, previous, lastByKind[event.Kind] = t + event.Duration + 6, event.Kind, t
				table.insert(sequence, event.Kind .. "@" .. t)
			end
		end
		check(count <= config.MaxEvents and scares <= config.MaxScares, "night event and scare budgets stay bounded")
		signatures[table.concat(sequence, ",")] = true
	end
	local variety = 0
	for _ in pairs(signatures) do
		variety += 1
	end
	check(variety >= 20 and hadScare, "seeded nights vary event kinds/times and include optional scares")
end

do
	local f = fixture()
	f.c.Director.Enabled = true
	f:start()
	f:repair()
	local p = f.p[1]
	f:advance(89)
	check(
		not f.run.event and not f.run:_scare(p, "Signal"),
		"production calm gate covers direct radio/damage scare routes"
	)
	f:advance(17)
	check(f.run.event and f.run.event.Minor, "production director replaces fixed 55-second blackout")
	local hp = f.run.players[p].HP
	local duration = f.run.event.EndsAt - f.h.time
	f:advance(duration)
	check(f.run.players[p].HP == hp, "false alarms do not damage staff when they expire")
	f.run:_planScare("Signal", 2)
	check(
		string.find(f.debugMessages[#f.debugMessages], "COMING") and not f.run:Snapshot(p).Scare,
		"debug announcement precedes hit without replicating future schedule"
	)
	local count = #f.debugMessages
	f:advance(1)
	check(
		#f.debugMessages == count and not f.run:Snapshot(p).Scare,
		"waiting for a scare does not spam logs or snapshots"
	)
	f:advance(1.1)
	check(
		f.run:Snapshot(p).Scare and string.find(f.debugMessages[#f.debugMessages], "DISPATCHED"),
		"scheduled hit is dispatched once"
	)
	local id = f.run:Snapshot(p).Scare.Id
	f.run:_planScare("Visitor", 2)
	check(not f.run.pendingScare, "personal cooldown excludes already-scared targets")
	f:advance(21)
	f.run:_planScare("Visitor", 2)
	f.run:_endDisturbance()
	f:advance(3)
	check(f.run:Snapshot(p).Scare.Id == id and not f.run.pendingScare, "ending a disturbance cancels its pending scare")
	f.run:_planScare("Visitor", 2)
	f.run:Finish("Dawn")
	check(not f.run.pendingScare, "results discard pending scare targets")
end

do
	local h = Harness.Environment()
	require("./PrototypeAssets").Install(h)
	local risk = h:load("src/GServer/Horror/OutdoorRisk.luau")
	local config = h:load("src/GServer/Session/GameConfig.luau").OutsideRisk
	local rolls, exposure = 0, {}
	local function miss()
		rolls += 1
		return 100
	end
	check(
		risk.Step(exposure, 0, true, true, config, miss) == "Outside",
		"outdoor exposure starts without an attack roll"
	)
	for i = 1, 47 do
		risk.Step(exposure, i * 0.25, true, true, config, miss)
	end
	check(rolls == 0, "outdoor grace never samples danger")
	risk.Step(exposure, 12, true, true, config, miss)
	for i = 49, 79 do
		risk.Step(exposure, i * 0.25, true, true, config, miss)
	end
	check(rolls == 1, "outdoor risk samples once per eight-second decision")
	check(
		risk.Chance(config, 12) < risk.Chance(config, 40) and risk.Chance(config, 10000) == config.MaxChance,
		"longer outdoor exposure raises attack chance to a bounded maximum"
	)
	local function hit()
		return 1
	end
	check(
		risk.Step(exposure, 20, true, true, config, hit) == "Warning" and exposure.ThreatEndsAt == 27,
		"successful risk roll grants a full seven-second escape window"
	)
	check(
		risk.Step(exposure, 26.99, false, true, config, hit) == "Escaped" and not exposure.ThreatEndsAt,
		"reaching the shop before the deadline prevents the outdoor attack"
	)
	risk.Step(exposure, 27, true, true, config, hit)
	risk.Step(exposure, 40, true, true, config, hit)
	check(not exposure.ThreatEndsAt, "stepping back outside cannot bypass the escape cooldown")
	risk.Step(exposure, 60, true, true, config, hit)
	check(exposure.ThreatEndsAt ~= nil, "outdoor risk resumes after the cooldown")
	check(
		risk.Step(exposure, 61, nil, true, config, hit) == "Inside" and not exposure.ThreatEndsAt,
		"missing character geometry cancels danger without pretending an escape was observed"
	)
end

do
	local f = fixture(2)
	f:start()
	f:repair()
	f.c.Events = {}
	local p, teammate = f.p[1], f.p[2]
	f:advance(100)
	f.run.event = { Kind = "Visitor" }
	check(not f.run:_scare(p, "Visitor"), "visitor cannot injure staff already inside the marked shelter")
	f.run.event = nil
	f.seated[p] = true
	f.run.stations.Bench.work = { Player = p }
	check(f.run:_scare(p, "Signal"), "night signal queues a server-owned injury")
	local cue = f.run:Snapshot(p).Scare
	check(
		cue.Damage == 25
			and not cue.Fatal
			and f.health[p] == 100
			and f.run.stations.Bench.work == nil
			and not f.seated[p],
		"attack announces damage and releases repair before its impact"
	)
	check(
		not f.run:Snapshot(teammate).Scare and not f.run:Snapshot(p).ScareImpact,
		"private pending damage and another player's scare are not exposed"
	)
	f:advance(0.3)
	check(f.health[p] == 100, "face has time to appear before the server impact")
	f:advance(0.31)
	check(
		f.health[p] == 75 and f.health[teammate] == 100 and f.run:Snapshot(p).Injury.Damage == 25,
		"scare really injures its target without damaging a teammate"
	)
	f:advance(1)
	check(f.health[p] == 75 and not f.run.players[p].ScareImpact, "repeated ticks never apply a scare twice")
	f:advance(21)
	f.run:Damage(p, 60, "test injury")
	f:advance(21)
	check(f.run:_scare(p, "Signal") and f.run:Snapshot(p).Scare.Fatal, "low-health signal correctly predicts death")
	f:advance(0.61)
	check(
		not f.run.players[p].Alive and f.run.players[teammate].Alive and #f.records[p] == 1,
		"fatal scare settles one death while teammates keep playing"
	)
	f:advance(1)
	check(#f.records[p] == 1, "fatal scare cannot duplicate death rewards")
end

do
	local f = fixture(4)
	f:start()
	f:repair()
	f.c.Events = {}
	local p, q = f.p[1], f.p[2]
	f.run.d.random = function(low)
		return low
	end
	f.outside[p] = true
	f:advance(89)
	check(not f.run.players[p].Outside and not f.run:Snapshot(p).Scare, "outside spawning and calm opening stay safe")
	f:advance(1)
	f:advance(12)
	local threat = f.run:Snapshot(p).Outside
	check(
		threat and threat.ThreatEndsAt == f.h.time + 7 and f.run:Snapshot(p).Target == "StaffDoor",
		"outdoor exposure targets the door with an actionable escape deadline"
	)
	check(not f.run:Snapshot(q).Outside and not f.run:Snapshot(q).Scare, "indoor teammates inherit no outdoor threat")
	f.outside[p] = false
	f:advance(6)
	check(
		not f.run:Snapshot(p).Outside and f.health[p] == 100 and not f.run.players[p].ScareImpact,
		"entering the shop cancels the impending attack without injury"
	)
	f.outside[p] = true
	f:advance(31)
	f:advance(12)
	f:advance(7)
	check(f.run:Snapshot(p).Scare and f.health[p] == 100, "ignoring early footsteps dispatches a real attack")
	f:advance(0.61)
	check(
		f.health[p] == 65 and f.run.players[p].Alive,
		"early outdoor attack injures instead of instantly killing full health"
	)
	f.outside[p] = false
	f:advance(31)
	f.outside[q] = true
	f:advance(1)
	f:advance(12)
	f:advance(7)
	f:advance(0.61)
	check(
		not f.run.players[q].Alive and f.run.players[p].Alive and f.health[f.p[3]] == 100,
		"late outdoor attack is fatal only to the staff member who ignored the warning"
	)
	check(string.find(f.run:Snapshot(q).DeathReason, "outside", 1, true), "death explains the ignored outdoor warning")
	-- Results/replay cancel any attack that has not reached its impact timestamp.
	f.run.players[p].NextScare = nil
	check(f.run:_scare(p, "Signal"), "surviving staff can receive a later threat")
	f.run:Finish("Dawn")
	local hp = f.health[p]
	f:advance(1)
	check(
		f.health[p] == hp and not f.run.players[p].ScareImpact and not f.run.players[p].Outside,
		"results discard delayed injuries and outdoor exposure"
	)
end

do
	local f = fixture(2)
	f:start()
	f:repair()
	f.c.Events = {}
	local p = f.p[1]
	f:advance(100)
	check(f.run:_scare(p, "Signal"), "disconnect fixture has a dispatched attack")
	f.run:Remove(p)
	f:advance(1)
	check(
		not f.records[p] and f.health[p] == 100,
		"departure before impact cannot invent a death or mutate departed health"
	)
	local q = f.p[2]
	f.h.time = f.run.nightAt + f.c.NightSeconds - 0.2
	check(not f.run:_scare(q, "Signal"), "a new scare cannot promise an impact after dawn")
end

-- Real rule transitions across 1-4 players, including chapter settlement and ready gates.
for count = 1, 4 do
	for _, mode in ipairs({ "Story", "Endless" }) do
		local f = fixture(count)
		f.session.Mode = mode
		f:start()
		f:repair()
		local outcomeIds = {}
		f.run.decisions = { "Hide" }
		f.run.players[f.p[1]].Secrets.Timecard = true
		local nights = mode == "Story" and 5 or 6
		for night = 1, nights do
			check(
				f.run.night == night and f.run.phase == "Night",
				mode .. " correct active night for " .. count .. " players"
			)
			f.h.time = f.run.nightAt + f.c.NightSeconds
			f.run:Tick()
			check(
				f.run.phase == "Results" and f.run.nightsCleared == night,
				string.format(
					"dawn increments run score once: %s players=%d night=%d phase=%s cleared=%s",
					mode,
					count,
					night,
					f.run.phase,
					tostring(f.run.nightsCleared)
				)
			)
			f.run:Tick()
			check(f.run.nightsCleared == night, "repeated result ticks cannot duplicate night score")
			for _, player in ipairs(f.p) do
				local record = f.records[player][night]
				check(
					record and record.Shift == night and record.Survived and not outcomeIds[record.Id],
					"each player gets one unique earned outcome per night"
				)
				outcomeIds[record.Id] = true
				check(
					(record.Ending ~= nil) == (mode == "Story" and night == 5),
					"only final Story survival awards an ending"
				)
			end
			if mode == "Story" and night == 5 then
				check(not f.run:CanContinue(), "Story concludes at chapter five")
				check(
					f.records[f.p[1]][5].Ending == "prototype_civilian_protector",
					"earlier decisions determine the final Story ending"
				)
			else
				check(f.run:CanContinue(), "surviving run offers the next night")
			end
			if night < nights then
				local oldId = f.run.id
				for i, player in ipairs(f.p) do
					check(f:act("Replay", player), "eligible survivor can ready")
					f.run:Tick()
					if i < count then
						check(f.run.id == oldId, "partial ready cannot move the whole party")
					end
				end
				check(
					f.run.id ~= oldId and f.run.night == night + 1,
					"unanimous ready advances with a fresh action identity"
				)
				f.h.env.Color3 = require("@lune/roblox").Color3
				local adapter = f.h:load("src/GServer/Session/GameService.luau")
				check(
					adapter.Request({ run = f.run }, f.p[1], "PrototypeAction", { RunId = oldId, Action = "Replay" }).Code
						== "ShiftChanged",
					"old night requests cannot mutate the next night"
				)
				check(
					f.run.decisions[1] == "Hide" and f.run.players[f.p[1]].Secrets.Timecard,
					"decisions and discoveries persist between nights"
				)
				for _, player in ipairs(f.p) do
					f:act("ClockIn", player)
					f:act("ReadRules", player)
				end
				f.run:Tick()
				check(
					not f.run.stations.Bench.order and f.run.phase == "Night",
					"later nights start without repeating training"
				)
			end
		end
	end
end

do
	local f = fixture(4)
	f.session.Mode = "Endless"
	f:start()
	f:repair()
	f.run:Damage(f.p[1], 100, "test death")
	f.run:Damage(f.p[2], 25, "test injury")
	f.run:Finish("Dawn")
	check(not f:act("Replay", f.p[1]), "dead staff cannot vote to continue Endless")
	for i = 2, 4 do
		f:act("Replay", f.p[i])
	end
	f.run:Tick()
	check(
		f.run.night == 2 and not f.run.players[f.p[1]].Alive and f.run.players[f.p[2]].HP == 75,
		"continuation preserves death and injury"
	)
	check(#f.records[f.p[1]] == 1, "dead spectators never receive repeated death awards")
	for i = 2, 4 do
		f:act("ClockIn", f.p[i])
		f:act("ReadRules", f.p[i])
	end
	f.run:Tick()
	check(f.run.phase == "Night", "dead spectators do not block the next briefing")
	f.run:Damage(f.p[2], 100, "test")
	f.run:Damage(f.p[3], 100, "test")
	f.run:Damage(f.p[4], 100, "test")
	check(f.run.reason == "AllDead" and not f.run:CanContinue(), "Endless ends when nobody survives")
	for _, player in ipairs(f.p) do
		f:act("Replay", player)
	end
	f.run:Tick()
	check(
		f.run.night == 1 and f.run.nightsCleared == 0 and #f.run:_living() == 4,
		"new run resets score and revives all four staff"
	)
end

do
	local f = fixture(2)
	f:start()
	f:repair()
	f.run:Finish("Dawn")
	f.run.players[f.p[2]].Settled = false
	f.run.d.outcome = function()
		return false
	end
	f:act("Replay", f.p[1])
	check(not f:act("Replay", f.p[2]), "unrecorded outcome cannot ready for a new night")
	f.run:Tick()
	check(f.run.night == 1 and f.run.phase == "Results", "outcome failure blocks continuation without losing progress")
end

do
	local h = Harness.Environment()
	require("./PrototypeAssets").Install(h)
	local catalog = h:load("src/GServer/Customers/CustomerCatalog.luau")
	local puzzles = h:load("src/GServer/Repair/RepairPuzzles.luau")
	local modes = h:load("src/GServer/Session/ModeRules.luau")
	local kinds = {}
	for _, chapter in ipairs({ "nina", "jonas", "silas" }) do
		local deck = catalog.Deck(function(low)
			return low
		end, "Story", chapter)
		local seen = {}
		for _, index in ipairs(deck) do
			local customer = catalog.Customers[index]
			check(
				not seen[index] and (not customer.Evidence or customer.Id == chapter),
				"chapter deck has no repeats or future story evidence"
			)
			seen[index] = true
		end
	end
	for i, requirement in ipairs(catalog.Requirements) do
		local job = catalog.Job(catalog.Customers[2], function(low, high)
			return math.min(i, high)
		end, false, 100)
		check(
			job.Contacts >= 2 and job.Contacts <= 3 and job.Patience >= 120 and job.SequenceLength <= 6,
			"service requirements fit the physical template and preserve solo reaction time"
		)
		local puzzle = puzzles.New("Install", "Speaker", i * 919, job.SequenceLength)
		check(
			puzzle.Kind == "Dials" or #puzzle.Sequence == job.SequenceLength,
			"service profile selects playable dial or code requirements"
		)
		kinds[puzzle.Kind .. table.concat(puzzle.Sequence or puzzle.Targets, ",")] = true
	end
	local count = 0
	for _ in pairs(kinds) do
		count += 1
	end
	check(count >= 10, "verification labels vary independently instead of repeating six patterns")
	local config = h:load("src/GServer/Session/GameConfig.luau").Director
	local late = modes.Director(config, "Endless", 100)
	check(
		late.MaxEvents > config.MaxEvents
			and late.CalmSeconds == config.CalmSeconds
			and late.MaxScares == config.MaxScares,
		"Endless pressure increases with a bounded calm opening and scare cap"
	)
end

for count = 1, 4 do
	local f = fixture(count)
	f:start()
	f:repair()
	f.c.Events = {}
	f.explicitWorkshop = true
	local function actor(slot)
		return f.p[(slot - 1) % count + 1]
	end
	f.run:_newOrder(false)
	f:advance(f.c.ArrivalSeconds)
	local before = {}
	for _, p in ipairs(f.p) do
		before[p] = f.run.players[p].Repairs
	end
	check(f:act("TakeOrder", actor(1)), "party intake accepts one phone")
	f:advance(0.6)
	check(f:act("Sit", actor(2)), "repair operator reserves the real seat")
	if count > 1 then
		check(not f:act("Sit", actor(1)), "second teammate cannot occupy the same bench")
	end
	f:advance(0.6)
	check(f:act("Diagnose", actor(2)), "operator starts diagnosis")
	for _, p in ipairs(f.p) do
		check(
			(f.run:Snapshot(p).Work.Puzzle ~= nil) == (p == actor(2)),
			"puzzle controls replicate only to their operator"
		)
	end
	f:solve()
	f:act("Stand", actor(2))
	check(f:act("Collect", actor(3)), "another staff member can fetch the replacement")
	f:advance(0.6)
	check(f:act("DepositPart", actor(3)), "delivery hands replacement to the shared bench")
	f:advance(0.6)
	check(f:act("Sit", actor(4)), "another operator can continue the phone")
	f:advance(0.6)
	check(f:act("Repair", actor(4)), "replacement puzzle accepts new seated operator")
	f:solve()
	f:advance(0.6)
	check(f:act("Secure", actor(4)), "next operator starts reassembly")
	f:solve()
	check(f.run.stations.Bench.order.Contacts == 4, "cooperative operator secures all four screws")
	f:advance(0.6)
	check(f:act("Install", actor(4)), "software requirements follow physical repair")
	f:solve()
	if f.run.stations.Bench.order.Step == "Evidence" then
		for _, p in ipairs(f.p) do
			f:act("Vote", p, { OrderId = f.run.stations.Bench.order.Id, Choice = "Report" })
		end
	end
	f:advance(0.6)
	check(f:act("Test", actor(4)), "final inspection can be completed cooperatively")
	f:solve()
	f:act("Stand", actor(4))
	f:pickup(actor(1))
	check(f:act("Return", actor(1)), "intake staff returns completed phone")
	for _, p in ipairs(f.p) do
		check(f.run.players[p].Repairs == before[p] + 1, "each contributor earns one repair credit")
	end
end

-- Every new task has a bounded solution and rejects premature/stale input.
do
	local h = Harness.Environment()
	require("./PrototypeAssets").Install(h)
	local rules = h:load("src/GServer/Repair/RepairPuzzles.luau")
	for seed = 1, 24 do
		for _, fault in ipairs({ "Battery", "Speaker", "Keypad" }) do
			local probe = rules.New("Diagnose", fault, seed, 4, 100)
			check(
				not rules.Input(probe, probe.Answer + 3, 0, 100),
				"diagnosis requires all probe readings before choosing a part"
			)
			check(
				rules.Snapshot(probe).Answer == nil and rules.Snapshot(probe).Readings[1] == "PRESS TO CHECK",
				"unmeasured readings and diagnosis answer stay private"
			)
			for i = 1, 3 do
				check(rules.Input(probe, i, probe.Revision, 100), "probe acquires a reading")
			end
			local ok, solved = rules.Input(probe, probe.Answer + 3, probe.Revision, 100)
			check(ok and solved, "measured diagnosis accepts the correct component")
			local puzzle = rules.New("Repair", fault, seed, 4, 100)
			check(
				not rules.Input(puzzle, 99, 0, 100) and puzzle.Revision == 0,
				"out-of-range repair control cannot mutate task"
			)
			if puzzle.Placed then
				local move = 10 + table.find(puzzle.Slots, 1)
				check(rules.Input(puzzle, move, 0, 100), "matching item fits its socket")
				check(not rules.Input(puzzle, move, 0, 100), "replayed drag revision is rejected")
				check(
					not rules.Input(puzzle, move, puzzle.Revision, 100) and puzzle.Progress == 1,
					"same part cannot fill multiple slots"
				)
				for item = 2, #puzzle.Slots do
					ok, solved = rules.Input(puzzle, item * 10 + table.find(puzzle.Slots, item), puzzle.Revision, 100)
				end
			else
				check(rules.Snapshot(puzzle).Targets == nil, "circuit solution angles stay server-only")
				for i, target in ipairs(puzzle.Targets) do
					for _ = 1, (target - puzzle.Rotations[i]) % 4 do
						check(rules.Input(puzzle, i, puzzle.Revision, 100), "circuit tile rotates one quarter turn")
					end
				end
				ok, solved = rules.Input(puzzle, 7, puzzle.Revision, 100)
			end
			check(ok and solved, "repair geometry has a reachable solution")
			check(not rules.Input(puzzle, 1, puzzle.Revision, 100), "completed repair cannot award twice")
		end
		local memory = rules.New("Test", "Battery", seed, 6, 100)
		check(not rules.Input(memory, memory.Sequence[1], 0, 100), "memory cannot be answered during demonstration")
		local _, solved = rules.Input(memory, memory.Sequence[1] % 6 + 1, 0, memory.RevealUntil)
		check(not solved and memory.Progress == 0, "wrong memory input restarts input progress")
		check(
			rules.Input(memory, 7, memory.Revision, 110) and memory.RevealAt == 110.8,
			"replay starts a fresh server-timed demonstration"
		)
		for _, move in ipairs(memory.Sequence) do
			_, solved = rules.Input(memory, move, memory.Revision, memory.RevealUntil)
		end
		check(solved, "memory completes only after correct repeated inputs")
	end
end

do
	local h = Harness.Environment()
	require("./PrototypeAssets").Install(h)
	local bench = h:load("src/GServer/Repair/BenchTasks.luau")
	local rules = h:load("src/GServer/Repair/RepairPuzzles.luau")
	local kinds = {
		"Clean",
		"Debris",
		"Broken",
		"Screen",
		"SIM",
		"Fuse",
		"Charger",
		"Sort",
		"Assembly",
		"Screws",
		"Buttons",
		"PhoneNumber",
		"Waves",
		"Meter",
		"Stamp",
		"Speaker",
	}
	for seed = 1, 24 do
		for _, kind in ipairs(kinds) do
			local p, now = bench.New(kind, seed, 100), 100
			check(not rules.Input(p, 0, p.Revision, now), "out-of-range bench control rejected")
			check(not rules.Input(p, 1, -1, now), "stale bench revision rejected")
			local solved = false
			for _ = 1, 100 do
				if p.RevealUntil then
					now = math.max(now, p.RevealUntil)
				end
				now += 0.3
				local move = benchMove(p, now) or p.Sequence[p.Progress + 1]
				local revision = p.Revision
				local ok
				ok, solved = rules.Input(p, move, revision, now)
				check(ok and p.Revision > revision, "accepted task input advances revision: " .. kind)
				check(not rules.Input(p, move, revision, now), "replayed input cannot progress task: " .. kind)
				if solved then
					break
				end
			end
			check(solved, "task has a reachable solution: " .. kind)
			check(not rules.Input(p, 1, p.Revision, now), "solved task rejects more moves")
		end
	end
	local sim = bench.New("SIM", 1, 0)
	local _, done = rules.Input(sim, 11, 0, 0)
	check(not done, "wrong SIM orientation cannot fit")
	local assembly = bench.New("Assembly", 2, 0)
	local _, early = rules.Input(assembly, 30 + table.find(assembly.Slots, 3), 0, 0)
	check(not early and assembly.Progress == 0, "cover cannot fit before board and battery")
	local stamp = bench.New("Stamp", 2, 0)
	local _, passed = rules.Input(stamp, 1, 0, 0)
	check(not passed, "PASS stamp cannot approve a failing test")
	local meter = bench.New("Meter", 2, 0)
	rules.Input(meter, 2, meter.Revision, 0)
	rules.Input(meter, 2, meter.Revision, 0)
	rules.Input(meter, 2, meter.Revision, 0)
	local _, instant = rules.Input(meter, 7, meter.Revision, 0)
	check(not instant and meter.Good == 0, "rapid meter clicks cannot fabricate elapsed time")
	local speaker = bench.New("Speaker", 2, 0)
	check(not rules.Input(speaker, speaker.Sequence[1], 0, 0), "speaker answers wait for demonstration")
	local secure = rules.New("Secure", "Battery", 1, 4, 0, true)
	local snapshot = rules.Snapshot(secure)
	check(snapshot.Pending == nil and snapshot.Seed == nil, "future task plan stays server-only")
	for i = 1, 3 do
		local revision = secure.Revision
		local ok, completed = rules.Input(secure, i * 10 + table.find(secure.Slots, i), revision, i)
		check(ok and not completed, "assembly alone cannot finish securing")
		check(not rules.Input(secure, 11, revision, i), "previous stage input rejected across transition")
	end
	check(secure.Kind == "Screws" and secure.TaskIndex == 2, "assembly transitions to screws under the same work ID")
	for screw = 1, 4 do
		for turn = 1, 3 do
			local ok, complete = rules.Input(secure, screw, secure.Revision, 4 + screw + turn)
			check(
				ok and complete == (screw == 4 and turn == 3),
				"all four screws require three turns before installation"
			)
		end
	end
end

do
	local f = fixture(1)
	f.run.d.appearance = function()
		return "npc_selected"
	end
	f:start()
	local player = f.p[1]
	local firstLine = f.run:Snapshot(player).Dialogue
	check(
		firstLine
			and firstLine.Speaker == f.run.stations.Bench.order.Customer
			and firstLine.Text == f.run.stations.Bench.order.Complaint,
		"customer arrival publishes current spoken complaint"
	)
	check(
		firstLine.AppearanceId == "npc_selected" and f.run:Snapshot(player).Order.AppearanceId == firstLine.AppearanceId,
		"server keeps selected customer appearance on order and spoken lines"
	)
	check(f.run:Snapshot(player).Dialogue.Id == firstLine.Id, "speech has stable identity between snapshots")
	f.h.time = firstLine.ExpiresAt + 1
	check(not f.run:Snapshot(player).Dialogue, "server omits expired speech")
	f.run.stations.Bench.order.Step = "Test"
	f.near[player] = "Bench"
	local physicalStation = "OtherSeat"
	f.run.d.seated = function(_, station)
		return not station or station == physicalStation
	end
	check(not f:act("Test"), "unrelated seat cannot authorize final testing")
	physicalStation = "Bench"
	f:advance(0.6)
	check(f:act("Test") and f.run.stations.Bench.work.Station == "Bench", "final testing uses the same repair station")
	check(f.run:Snapshot(player).Target == "Bench", "final-test objective stays at the repair bench")
	physicalStation = "OtherSeat"
	f:advance(0.2)
	check(not f.run.stations.Bench.work, "leaving the correct test seat cancels unfinished test")
end

print(string.format("PASS: %d playable prototype and outcome checks.", total))
