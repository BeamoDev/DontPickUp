local Harness = require("./Harness")
local createFixture = require("./ShiftFixture")
local total = 0
local function check(value, message)
	assert(value, message)
	total += 1
end
local function fixture(count)
	return createFixture(count, check)
end

-- Early phones teach visible matching/copying; later shifts retain easy jobs.
do
	local h = Harness.Environment()
	local puzzles = h:load("src/GServer/Prototype/Repair/WorkPuzzles.luau")
	local laterEasy = 0
	for seed = 1, 30 do
		check(puzzles.IsEasy(false, 1, seed), "all first-night phones use easy tasks")
		check(puzzles.IsEasy(true, 3, seed), "training stays easy regardless of night")
		laterEasy += puzzles.IsEasy(false, 3, seed) and 1 or 0
		for _, action in ipairs({ "Repair", "Install", "Test" }) do
			local p = puzzles.New(action, "Keypad", seed, 6, 100, true, true)
			check(p.Sequence and #p.Sequence == 3 and p.TaskCount == 1, "easy job has one short visible sequence")
			check(
				p.Kind ~= "Memory" and p.Kind ~= "Speaker" and p.Kind ~= "Circuit",
				"easy job requires no hidden sequence or circuit knowledge"
			)
			local ok, solved = puzzles.Input(p, p.Sequence[1] % 6 + 1, p.Revision, 100)
			check(ok and not solved and p.Progress == 0, "wrong number cannot finish an easy task")
			for i = 1, 3 do
				local revision = p.Revision
				ok, solved = puzzles.Input(p, p.Sequence[i], revision, 100)
				check(ok and solved == (i == 3), "only the full correct sequence completes the task")
				check(not puzzles.Input(p, p.Sequence[i], revision, 100), "easy task still rejects stale input")
			end
		end
	end
	check(laterEasy == 20, "two out of three later seeds keep familiar easy tasks")
	for _, fault in ipairs({ "Battery", "Speaker", "Keypad" }) do
		local p = puzzles.New("Diagnose", fault, 1, 3, 100, false, true)
		check(puzzles.Snapshot(p).Readings[1] == "PRESS TO CHECK", "unchecked parts do not reveal the fault")
		for i = 1, 3 do
			puzzles.Input(p, i, p.Revision, 100)
		end
		local snapshot = puzzles.Snapshot(p)
		check(
			snapshot.Answer == nil and snapshot.Hint:find("REPLACE"),
			"diagnosis explains what to do without exposing answer IDs"
		)
		for i, name in ipairs({ "Battery", "Speaker", "Keypad" }) do
			check(
				snapshot.Readings[i] == (name == fault and "BROKEN" or "WORKING"),
				"every diagnosis result uses plain words"
			)
		end
	end
	-- Stamp itself is also used after the harder tests.
	local bench = h:load("src/GServer/Prototype/Repair/BenchTasks.luau")
	local stamp = bench.New("Stamp", 2, 100)
	check(puzzles.Snapshot(stamp).Hint:find("FIX IT FIRST"), "loose wire explains the required action")
	check(not select(2, puzzles.Input(stamp, 1, stamp.Revision, 100)), "cannot mark broken phone ready")
	puzzles.Input(stamp, 2, stamp.Revision, 100)
	check(puzzles.Snapshot(stamp).Hint:find("FIX LOOSE WIRE"), "retest explains the next button")
	puzzles.Input(stamp, 3, stamp.Revision, 100)
	check(puzzles.Snapshot(stamp).Hint:find("PHONE IS READY"), "repaired wire changes the instruction")
	check(select(2, puzzles.Input(stamp, 1, stamp.Revision, 100)), "repaired phone can be marked ready")
end

-- Two staff complete independent phones, then survive and settle the shared night.
do
	local f = fixture(2)
	f.c.Events, f.c.OutsideRisk.Enabled = {}, false
	f:start()
	check(not f:act("SelectStation", f.p[2], { Station = "Bench2" }), "second bench waits for simple training")
	f:repair()
	local p, q = f.p[1], f.p[2]
	check(f:act("SelectStation", q, { Station = "Bench2" }), "nearby worker selects second bench")
	f:advance(f.c.BetweenCustomers + f.c.ArrivalSeconds)
	f:advance(f.c.ArrivalSeconds)
	local a, b = f.run.stations.Bench, f.run.stations.Bench2
	check(a.order and b.order and a.order.Id ~= b.order.Id, "both benches own unique live orders")
	check(f.run:Snapshot(q).PhoneName == "RepairPhone2", "second worker receives correct physical phone")
	check(f:act("TakeOrder", p) and f:act("TakeOrder", q), "both customers accepted independently")
	f:advance(0.6)
	check(f:act("Diagnose", p) and f:act("Diagnose", q), "parallel diagnostics reserve separate work")
	local aw, bw = a.work, b.work
	check(aw.Id ~= bw.Id and aw.Station == "Bench" and bw.Station == "Bench2", "work IDs and stations isolated")
	f:advance(0.6)
	check(
		not f:act(
			"PuzzleInput",
			q,
			{ OrderId = aw.OrderId, WorkId = aw.Id, Move = 1, PuzzleRevision = aw.Puzzle.Revision }
		),
		"other bench work cannot be solved by supplying its IDs"
	)
	local revision = bw.Puzzle.Revision
	f:solve(p)
	check(
		b.work == bw and bw.Puzzle.Revision == revision and b.order.Step == "Diagnose",
		"solving first phone leaves second unchanged"
	)
	f:solve(q)
	for _, actor in ipairs({ p, q }) do
		local lane = f.run.stations[f.run.players[actor].StationId]
		f:advance(0.6)
		check(f:act("Collect", actor), "worker reserves own replacement")
		check(
			not f:act("SelectStation", actor, { Station = actor == p and "Bench2" or "Bench" }),
			"cannot move a carried part to another order"
		)
		for _, action in ipairs({ "Repair", "Secure", "Install" }) do
			f:advance(0.6)
			check(f:act(action, actor), "start independent " .. action)
			f:solve(actor)
		end
		if lane.order.Step == "Evidence" then
			local id = lane.order.Id
			check(
				f.run:Snapshot(p).Vote.OrderId == id and f.run:Snapshot(q).Vote.OrderId == id,
				"evidence vote reaches both stations"
			)
			for _, voter in ipairs({ p, q }) do
				check(f:act("Vote", voter, { OrderId = id, Choice = "Hide" }), "cross-station team vote")
			end
		end
		f:advance(0.6)
		check(f:act("Test", actor), "final test belongs to original bench")
		f:solve(actor)
		f:pickup(actor)
		check(f:act("Return", actor), "independent phone returns and pays once")
	end
	check(f.run.repaired == 3, "training plus two independent repairs counted once")
	local revenue = f.run.revenue
	check(not f:act("Return", q) and f.run.revenue == revenue, "duplicate return grants nothing")
	f.h.time = f.run.nightAt + f.c.NightSeconds
	f.run:Tick()
	check(
		f.run.phase == "Results" and f.records[p][1].Survived and f.records[q][1].Survived,
		"full shared shift settles both players"
	)
	check(not a.work and not b.work and not a.order and not b.order, "dawn clears every station")
end

-- Injury and shared interruption have intentionally different scopes.
do
	local f = fixture(2)
	f.c.Events, f.c.OutsideRisk.Enabled = {}, false
	f:start()
	f:repair()
	local p, q = f.p[1], f.p[2]
	f:act("SelectStation", q, { Station = "Bench2" })
	f:advance(10)
	f:advance(4)
	f:act("TakeOrder", p)
	f:act("TakeOrder", q)
	f:advance(0.6)
	f:act("Diagnose", p)
	f:act("Diagnose", q)
	local b = f.run.stations.Bench2
	local second = b.work
	f.run:Damage(p, 25, "test injury", true)
	check(not f.run.stations.Bench.work and b.work == second, "injury cancels only victim work")
	f.c.Events = { { At = 0, Kind = "Blackout", Duration = 10, Warning = "Lights out" } }
	f.run:Tick()
	local a = f.run.stations.Bench
	check(
		not b.work and a.order.PausedAt and b.order.PausedAt,
		"shared hazard cancels both works and pauses both patience clocks"
	)
	local expiryA, expiryB = a.order.ExpiresAt, b.order.ExpiresAt
	f:advance(2)
	f:act("RestorePower", q, { EventId = f.run.event.Id })
	f:advance(f.c.AfterDisturbanceSeconds)
	check(
		a.order.ExpiresAt == expiryA + 8 and b.order.ExpiresAt == expiryB + 8,
		"both patience clocks resume exactly once"
	)
	check(not a.order.PausedAt and not b.order.PausedAt, "all stations recover from hazard")
end

-- Inspection is personal, server-scoped and optional; existing archive IDs remain valid.
do
	local f = fixture(2)
	f:start()
	local a, b = f.run.stations.Bench, f.run.stations.Bench2
	a.order.Step, a.order.Sensitive = "Install", true
	a.order.Phone = { Discovered = true, Installed = true, Revision = 1 }
	b.order = {
		Id = "other",
		Step = "Install",
		Sensitive = true,
		Contributors = {},
		ExpiresAt = f.h.time + 1,
		Phone = { Discovered = true, Installed = true, Revision = 1 },
	}
	f.run:_completeWork({ Action = "Install", OrderId = a.order.Id, Player = f.p[1] }, a)
	f.run:_completeWork({ Action = "Install", OrderId = b.order.Id, Player = f.p[2] }, b)
	check(a.order.VoteEndsAt and not b.order.VoteEndsAt, "second evidence ballot queues without an invisible timeout")
	check(
		not f:act("Vote", f.p[2], { OrderId = b.order.Id, Choice = "Investigate" }),
		"cannot vote on an undisplayed ballot"
	)
	f:advance(f.c.VoteSeconds)
	check(
		a.order.Step == "Test" and b.order.Step == "Evidence" and b.order.VoteEndsAt == f.h.time + f.c.VoteSeconds,
		"queued ballot gets a full response window after first resolves"
	)
	check(f.run:Snapshot(f.p[1]).Vote.OrderId == b.order.Id, "both staff see the next shared ballot")
	check(b.order.ExpiresAt > b.order.VoteEndsAt, "customer does not expire while waiting for an unseen team choice")
end

-- Direct interaction cannot bypass the existing run/order/event and distance checks.
do
	local f = fixture()
	f:start()
	f.h.env.Color3 = require("@lune/roblox").Color3
	local Adapter = f.h:load("src/GServer/Prototype/Services/GamePrototype.luau")
	local world = {
		direct = { Secret_DeskNote = true },
		ActionFor = function()
			return "Discover"
		end,
	}
	local adapter = setmetatable({ run = f.run, world = world }, Adapter)
	local request =
		{ RunId = f.run.id, Action = "Interact", Station = "Secret_DeskNote", OrderId = f.run.stations.Bench.order.Id }
	f.near[f.p[1]] = "Counter"
	check(not adapter:Request(f.p[1], "PrototypeAction", request).Ok, "direct request still requires actual proximity")
	f.near[f.p[1]] = "Secret_DeskNote"
	request.OrderId = "stale"
	check(
		adapter:Request(f.p[1], "PrototypeAction", request).Code == "InteractionChanged",
		"late click cannot apply to a later phone"
	)
	request.OrderId = f.run.stations.Bench.order.Id
	request.EventId = "old"
	check(
		adapter:Request(f.p[1], "PrototypeAction", request).Code == "InteractionChanged",
		"late click cannot cross hazard state"
	)
	request.EventId = nil
	check(adapter:Request(f.p[1], "PrototypeAction", request).Ok, "valid direct note request reaches server reader")
	request.Station = "Invented"
	check(
		adapter:Request(f.p[1], "PrototypeAction", request).Code == "InvalidInput",
		"unknown world identifiers rejected"
	)
end

do
	local f = fixture(2)
	f:start()
	local p, q = f.p[1], f.p[2]
	check(not f.run:Snapshot(p).Inspection, "undiscovered records are not replicated")
	f.near[p] = "Counter"
	check(not f:act("Discover", p, { Secret = "DeskNote" }), "remote cannot inspect distant note")
	f.near[p] = "Secret_DeskNote"
	check(f:act("Discover", p, { Secret = "DeskNote" }), "nearby note opens reader")
	local item = f.run:Snapshot(p).Inspection
	check(
		item.Text:find("Employee 07", 1, true) and not f.run:Snapshot(q).Inspection,
		"only inspecting player receives connected lore"
	)
	check(
		f.evidence[p] == "shop_desk_note" and f.run.revenue == 0,
		"record unlocks evidence without repair or money rewards"
	)
	check(
		f:act("CloseInspection", p, { InspectionId = "old" }) and f.run.players[p].Inspection,
		"stale close cannot close a new reader"
	)
	f:act("CloseInspection", p, { InspectionId = item.Id })
	check(not f.run.players[p].Inspection, "current close releases inspection")
	f:advance(1.1)
	check(f:act("Discover", p, { Secret = "DeskNote" }), "records can be reread")
	f.near[p] = "Counter"
	f:advance(0.25)
	check(not f.run.players[p].Inspection, "walking away closes inspection")
	f.near[p] = "Secret_DeskNote"
	f:advance(1)
	f:act("Discover", p, { Secret = "DeskNote" })
	f:advance(91)
	check(not f.run.players[p].Inspection, "inspection expires without a client close")
	f.gearMode.Explicit = true
	f.near[p] = "Secret_Locker"
	check(not f:act("Discover", p, { Secret = "Locker" }), "archive drawer still requires actual brass key")
end

do
	local h = Harness.Environment()
	local Conversations = h:load("src/GServer/Prototype/Customers/Conversations.luau")
	local Dialogue = h:load("src/GServer/Prototype/Services/DialogueService.luau")
	local player = h:player(1)
	local normal =
		Conversations.Intake({ Id = "1", Kind = "Normal", Customer = "Customer", Complaint = "It is broken." }, player)
	local odd = Conversations.Intake(
		{ Id = "1", Kind = "Unusual", Customer = "Visitor", Complaint = "It is whispering." },
		player
	)
	local official = Conversations.Intake({ CustomerId = "reed", Customer = "Officer Reed" }, player)
	check(
		#normal == 3 and normal[2].UserId == player.UserId and normal[3].Text ~= odd[3].Text,
		"normal/funny and unusual conversations differ; player lines are authored"
	)
	check(
		official[1].Speaker == "Officer Reed" and official[3].Text:find("report"),
		"government exchange has distinct personality"
	)
	local channel = Dialogue.new()
	channel:Start("night1", normal, h.time)
	local first = channel.Current
	check(not channel:Tick(h.time + 1) and channel.Current == first, "unchanged dialogue does not restart")
	check(
		channel:Tick(first.ExpiresAt) and channel.Current.UserId == player.UserId,
		"server advances customer to employee line"
	)
	check(channel.Current.Id ~= first.Id, "each subtitle line has a unique identity")
	channel:Clear()
	check(not channel.Current and #channel.Pending == 0, "new run clears queued conversations")
end

-- Request serialization, correct shared-vote ID, and queued close after an in-flight reply.
do
	local h = Harness.Environment()
	local Requests = h:load("src/GShared/Prototype/Networking/Requests.luau")
	local state = { RunId = "run", Order = { Id = "second" }, Vote = { OrderId = "first" } }
	local _, payload = Requests.Payload(state, "Vote", "Hide")
	check(payload.OrderId == "first", "vote request uses shared vote order rather than own repair")
	local _, signalPayload = Requests.Payload(state, "Signal", "Inside")
	check(signalPayload.Signal == "Inside" and signalPayload.Choice == nil, "preset signal sends only its allowlisted key")
	local _, restock = Requests.Payload(state, "PuzzleInput", { WorkId = "crate", Move = 11, PuzzleRevision = 0 })
	check(restock.OrderId == nil, "restock inputs never inherit active customer order")
	local calls = {}
	local request = Requests.new({
		state = function()
			return state
		end,
		clock = function()
			return h.time
		end,
		spawn = h.env.task.spawn,
		busy = function() end,
		error = function() end,
		apply = function() end,
		remote = function()
			return {
				InvokeServer = function(_, action, data)
					table.insert(calls, { action, data })
					return { Ok = true }
				end,
			}
		end,
	})
	request:Send("GetPrototype")
	request:Send("CloseInspection", { InspectionId = "visit1" })
	check(
		#calls == 0 and request.deferred.Payload.InspectionId == "visit1",
		"close queues behind current call without overlap"
	)
	h:drain()
	check(
		#calls == 2 and calls[2][2].InspectionId == "visit1" and not request.pending,
		"queued close retains original visit"
	)
	request:Send("GetPrototype")
	request:Send("CloseInspection", { InspectionId = "old" })
	state = { RunId = "new" }
	h:drain()
	check(#calls == 3, "old run deferred input is discarded")
	request:Destroy()
	request:Send("GetPrototype")
	h:drain()
	check(#calls == 3, "destroyed request layer cannot dispatch")
end

-- Input adapters: mouse, tap vs drag, multi-touch, gamepad, blocking and cleanup.
do
	local Roblox = require("@lune/roblox")
	local h = Harness.Environment()
	for _, key in ipairs({ "Color3", "Vector2", "Vector3", "UDim2", "Enum" }) do
		h.env[key] = Roblox[key]
	end
	h.env.RaycastParams = {
		new = function()
			return {}
		end,
	}
	local function signal()
		local listeners = {}
		return {
			Connect = function(_, callback)
				local connection = { Connected = true }
				function connection:Disconnect()
					self.Connected = false
				end
				table.insert(listeners, { connection, callback })
				return connection
			end,
			Fire = function(_, ...)
				for _, item in ipairs(listeners) do
					if item[1].Connected then
						item[2](...)
					end
				end
			end,
		}
	end
	local input = {
		InputBegan = signal(),
		InputEnded = signal(),
		WindowFocusReleased = signal(),
		GamepadEnabled = false,
		TouchEnabled = false,
	}
	local lastInput = Roblox.Enum.UserInputType.MouseMovement
	function input:GetLastInputType()
		return lastInput
	end
	function input:GetMouseLocation()
		return Roblox.Vector2.new(400, 200)
	end
	local player = h:player(1)
	player.Character = h.instance("Model")
	local root = h.instance("Part")
	root.Name, root.Position, root.Parent = "HumanoidRootPart", Roblox.Vector3.zero, player.Character
	local gui = h.instance("ScreenGui")
	local target = h.instance("Part")
	target.Position = Roblox.Vector3.new(0, 0, 3)
	target:SetAttribute("DPU_Direct", "Secret_DeskNote")
	target:SetAttribute("DPU_Enabled", true)
	target:SetAttribute("DPU_Label", "Read note")
	target:SetAttribute("DPU_Range", 5)
	local rays, sent = {}, {}
	local camera = { ViewportSize = Roblox.Vector2.new(800, 600) }
	function camera:ScreenPointToRay(x, y)
		table.insert(rays, { "screen", x, y })
		return { Origin = Roblox.Vector3.zero, Direction = Roblox.Vector3.zAxis }
	end
	function camera:ViewportPointToRay(x, y)
		table.insert(rays, { "viewport", x, y })
		return { Origin = Roblox.Vector3.zero, Direction = Roblox.Vector3.zAxis }
	end
	local world = {
		children = {},
		CurrentCamera = camera,
		Raycast = function()
			return { Instance = target }
		end,
	}
	local direct = h:load("src/GClient/Prototype/Interactions/WorldInteraction.luau").new(gui, {
		input = input,
		workspace = world,
		player = player,
		send = function(action, payload)
			table.insert(sent, { action, payload })
		end,
	})
	direct:Update({ Alive = true, Phase = "Night" }, false)
	check(
		direct.highlight.Enabled and direct.hint.Text:find("Read note"),
		"aimed interaction gives readable visual feedback"
	)
	local click = { UserInputType = Roblox.Enum.UserInputType.MouseButton1, Position = Roblox.Vector3.new(300, 200, 0) }
	input.InputBegan:Fire(click, false)
	input.InputEnded:Fire(click, false)
	check(
		#sent == 1 and sent[1][2].Station == "Secret_DeskNote" and rays[#rays][1] == "screen",
		"mouse sends station intent through request layer"
	)
	local finger = { UserInputType = Roblox.Enum.UserInputType.Touch, Position = Roblox.Vector3.new(220, 160, 0) }
	input.InputBegan:Fire(finger, false)
	input.InputEnded:Fire({ UserInputType = Roblox.Enum.UserInputType.Touch, Position = finger.Position }, false)
	check(#sent == 1, "second finger cannot release first finger interaction")
	input.InputEnded:Fire(finger, false)
	check(#sent == 2, "touch tap activates same interaction")
	input.InputBegan:Fire(finger, false)
	finger.Position += Roblox.Vector3.new(50, 0, 0)
	input.InputEnded:Fire(finger, false)
	check(#sent == 2, "camera drag does not tap a world object")
	lastInput, input.GamepadEnabled = Roblox.Enum.UserInputType.Gamepad1, true
	direct:Update({ Alive = true, Phase = "Night" }, false)
	input.InputEnded:Fire({ KeyCode = Roblox.Enum.KeyCode.ButtonR2 }, false)
	check(
		#sent == 3 and rays[#rays][1] == "viewport" and direct.hint.Text:find("RT"),
		"controller uses centre aim and trigger"
	)
	target.Position = Roblox.Vector3.new(0, 0, 50)
	input.InputEnded:Fire({ KeyCode = Roblox.Enum.KeyCode.ButtonR2 }, false)
	check(#sent == 3, "client rejects distant interaction before requesting")
	target.Position = Roblox.Vector3.new(0, 0, 3)
	direct:Update({ Alive = true, Phase = "Night", Inspection = {} }, false)
	input.InputEnded:Fire({ KeyCode = Roblox.Enum.KeyCode.ButtonR2 }, false)
	check(#sent == 3 and not direct.highlight.Enabled, "reader suppresses world input and highlight")
	direct:Destroy()
	input.InputEnded:Fire({ KeyCode = Roblox.Enum.KeyCode.ButtonR2 }, false)
	check(#sent == 3 and not direct.hint.Parent, "world input disconnects on teardown")
	local selection = { SelectedObject = nil }
	local reader = h:load("src/GShared/Prototype/UI/InspectionView.luau").new(gui, {
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
		Inspection = {
			Id = "visit",
			Title = "Old record",
			Format = "Note",
			Text = string.rep("A recorded voice remembers another shift. ", 15),
			ExpiresAt = h.time + 90,
		},
	}
	reader:Update(state, false)
	check(
		reader.panel.Visible
			and #reader.pages > 1
			and selection.SelectedObject == reader.close
			and not reader.text.RichText,
		"reader paginates text and selects controller close"
	)
	reader.next.Activated:Fire()
	check(reader.page == 2, "same Activated page controls support pointer touch and gamepad")
	input.InputBegan:Fire({ KeyCode = Roblox.Enum.KeyCode.ButtonB }, false)
	check(
		not reader.panel.Visible and sent[#sent][2].InspectionId == "visit",
		"controller close sends current inspection identity"
	)
	reader:Update(state, false)
	check(not reader.panel.Visible, "unanswered close cannot reopen dismissed document")
	state.Inspection.Id = "visit2"
	reader:Update(state, false)
	check(reader.panel.Visible, "fresh inspection opens independently of dismissed visit")
	state.Event = {}
	reader:Update(state, false)
	check(not reader.panel.Visible, "hazard releases reader")
	reader:Destroy()
	check(not reader.panel.Parent and selection.SelectedObject == nil, "reader cleanup restores GUI selection")

	-- Cursor policy must release real UI interactions without fighting station cameras.
	h.env.UDim = Roblox.UDim
	local needsPointer, menuOpen, textFocus = false, false, nil
	input.WindowFocused = signal()
	input.PreferredInput = Roblox.Enum.PreferredInput.KeyboardAndMouse
	input.MouseBehavior = Roblox.Enum.MouseBehavior.Default
	input.MouseIconEnabled = true
	function input:GetFocusedTextBox()
		return textFocus
	end
	player.CameraMode = Roblox.Enum.CameraMode.Classic
	player.CharacterAdded = signal()
	gui.Parent = h.instance("PlayerGui")
	local render = { callback = nil }
	function render:BindToRenderStep(name, priority, callback)
		self.name, self.priority, self.callback = name, priority, callback
	end
	function render:UnbindFromRenderStep(name)
		check(name == self.name, "cursor removes its own frame binding")
		self.callback = nil
	end
	local cursor = h:load("src/GClient/Interactions/FirstPersonCamera.luau").new(gui, player, input, {
		render = render,
		needsPointer = function()
			return needsPointer
		end,
		menuOpen = function()
			return menuOpen
		end,
	})
	check(
		cursor:IsLocked() and not input.MouseIconEnabled and cursor.dot.Visible,
		"normal play locks to center with only the dot visible"
	)
	check(
		cursor.overlay.IgnoreGuiInset and cursor.dot.Position == h.env.UDim2.fromScale(0.5, 0.5),
		"dot uses the full viewport center"
	)
	check(render.priority > Roblox.Enum.RenderPriority.Camera.Value, "cursor policy runs after native camera")
	check(cursor.dot.Size == Roblox.UDim2.fromOffset(6, 6), "cursor is 1.5 times its original size")
	cursor:SetHover(true, false)
	cursor:Step()
	local idleAlpha = cursor.dot.BackgroundTransparency
	h.time += 0.6
	cursor:Step()
	check(cursor.dot.BackgroundTransparency < idleAlpha, "valid hover smoothly brightens the dot")
	cursor:SetHover(true, true)
	cursor:Step()
	check(cursor.dot.BackgroundTransparency == 0.2, "reduced motion uses steady hover brightness")
	cursor:SetHover(false, false)
	cursor:Step()
	check(cursor.dot.BackgroundTransparency == 0.45, "leaving an item restores faint cursor")
	input.InputBegan:Fire({ KeyCode = Roblox.Enum.KeyCode.V }, false)
	check(
		not cursor:IsLocked() and cursor.toggle.Modal and input.MouseBehavior == Roblox.Enum.MouseBehavior.Default,
		"V frees the cursor"
	)
	check(cursor.dot.Position == h.env.UDim2.fromOffset(400, 200), "free dot follows screen mouse coordinates")
	cursor.toggle.Activated:Fire()
	check(cursor:IsLocked(), "small button relocks the cursor")
	needsPointer = true
	render.callback()
	input.InputBegan:Fire({ KeyCode = Roblox.Enum.KeyCode.V }, false)
	check(
		not cursor:IsLocked() and not cursor.toggle.Active,
		"task automatically frees cursor and cannot be manually trapped"
	)
	needsPointer = false
	render.callback()
	check(cursor:IsLocked(), "leaving task restores normal look controls")
	menuOpen = true
	render.callback()
	check(
		not cursor:IsLocked() and input.MouseIconEnabled and not cursor.dot.Visible,
		"Roblox menu gets native free cursor"
	)
	menuOpen, textFocus = false, {}
	render.callback()
	input.InputBegan:Fire({ KeyCode = Roblox.Enum.KeyCode.V }, false)
	check(not cursor.manualFree and not cursor:IsLocked(), "typing V in chat cannot toggle mouse mode")
	textFocus = nil
	input.WindowFocusReleased:Fire()
	check(not cursor:IsLocked() and not cursor.dot.Visible, "alt-tab releases mouse and hides dot")
	input.WindowFocused:Fire()
	check(cursor:IsLocked(), "returning focus restores center lock")
	input.PreferredInput = Roblox.Enum.PreferredInput.Touch
	render.callback()
	check(
		not cursor.dot.Visible and not cursor.toggle.Modal and not cursor:IsLocked(),
		"touch camera is not forced into mouse policy"
	)
	input.PreferredInput = Roblox.Enum.PreferredInput.KeyboardAndMouse
	render.callback()
	cursor:Toggle()
	player.CharacterAdded:Fire()
	check(cursor:IsLocked() and not cursor.manualFree, "respawn starts with centered camera controls")
	local centered = h:load("src/GClient/Prototype/Interactions/WorldInteraction.luau").new(gui, {
		input = input,
		workspace = world,
		player = player,
		locked = function()
			return cursor:IsLocked()
		end,
		send = function() end,
	})
	centered:Pick(Roblox.Vector2.new(30, 40))
	check(
		rays[#rays][1] == "viewport" and rays[#rays][2] == 400 and rays[#rays][3] == 300,
		"locked interactions aim through dot regardless of old pointer position"
	)
	cursor:Toggle()
	centered:Pick(Roblox.Vector2.new(30, 40))
	check(rays[#rays][1] == "screen" and rays[#rays][2] == 30, "free cursor keeps pointer targeting")
	target:SetAttribute("DPU_Direct", "Part_Battery")
	local pickup =
		{ Alive = true, Phase = "Night", Order = { Step = "Collect", Fault = "Battery" }, Stock = { Battery = 1 } }
	centered:Update(pickup, false)
	check(centered.hovered, "available matching part can pulse")
	pickup.Order.Fault = "Speaker"
	centered:Update(pickup, false)
	check(not centered.hovered, "another bench's enabled part cannot pulse as a valid pickup")
	pickup.Order.Fault, pickup.CarriedPart = "Battery", "Battery"
	centered:Update(pickup, false)
	check(not centered.hovered, "hands already carrying a part cannot promise another pickup")
	pickup.CarriedPart, pickup.Stock.Battery = nil, 0
	centered:Update(pickup, false)
	check(not centered.hovered, "empty shelf does not pulse")
	target:SetAttribute("DPU_Direct", "Tools")
	pickup.Kit = { Tester = true, Screwdriver = true, Cartridge = true }
	centered:Update(pickup, false)
	check(not centered.hovered, "complete kit does not advertise a new pickup")
	pickup.Kit.Tester = nil
	centered:Update(pickup, false)
	check(centered.hovered, "missing reusable tool allows pickup hover")
	centered:Update(pickup, true)
	check(not centered.hovered, "menus and pending requests clear hover feedback")
	centered:Destroy()
	cursor:Destroy()
	cursor:Destroy()
	check(
		not render.callback and not cursor.overlay.Parent and not cursor.toggle.Parent,
		"cleanup removes dot, toggle and frame callback"
	)
	check(
		player.CameraMode == Roblox.Enum.CameraMode.Classic
			and input.MouseIconEnabled
			and input.MouseBehavior == Roblox.Enum.MouseBehavior.Default,
		"cleanup restores original camera and input settings"
	)
end

print(string.format("PASS: %d design, dialogue, lore, station isolation and network checks.", total))
