local Harness = require("./Harness")
local benchMove = require("./BenchDriver")
return function(count, check)
	local h = Harness.Environment()
	local c = h:load("src/GServer/Shifts/PrototypeConfig.luau")
	c.Director.Enabled = false -- Existing fixtures deliberately exercise the fixed scenario schedule.
	local players, records, saves, health, tutorial, evidence, nearby = {}, {}, {}, {}, {}, {}, {}
	local session = { State = "Ready", Ready = true }
	local debugMessages = {}
	local outside = {}
	local seated, parts = {}, {}
	local gear, gearMode = {}, { Explicit = false }
	local run = h:load("src/GServer/Shifts/ShiftService.luau").new({
		debug = function(message)
			table.insert(debugMessages, message)
		end,
		clock = function()
			return h.time
		end,
		id = function()
			h.serial += 1
			return "prototype_" .. h.serial
		end,
		present = function(p)
			return p.Parent == h.players
		end,
		ready = function()
			return true
		end,
		near = function(p, station)
			return nearby[p] == nil or nearby[p] == station
		end,
		outside = function(p)
			return outside[p] == true
		end,
		seated = function(p)
			return seated[p] == true
		end,
		sit = function(p)
			for other, value in pairs(seated) do
				if other ~= p and value then
					return false, "BenchOccupied"
				end
			end
			seated[p] = true
			return true
		end,
		stand = function(p)
			seated[p] = false
		end,
		givePart = function(p, record)
			parts[p] = record
			return true
		end,
		hasPart = function(p, record)
			return parts[p] == record
		end,
		clearPart = function(p)
			parts[p] = nil
		end,
		hasGear = function(p, id)
			return not gearMode.Explicit or gear[p] and gear[p][id] == true
		end,
		giveGear = function(p, id)
			gear[p] = gear[p] or {}
			gear[p][id] = true
			return true
		end,
		clearGear = function(p)
			gear[p] = nil
		end,
		sessionReady = function()
			return session.Ready
		end,
		sessionState = function()
			return session.State
		end,
		mode = function()
			return session.Mode or "Story"
		end,
		reset = function(p)
			health[p] = 100
		end,
		health = function(p, hp)
			health[p] = hp
		end,
		outcome = function(p, outcome)
			records[p] = records[p] or {}
			table.insert(records[p], outcome)
			return true
		end,
		persist = function(p)
			saves[p] = (saves[p] or 0) + 1
		end,
		saveStatus = function()
			return "Saved"
		end,
		tutorial = function(p)
			tutorial[p] = true
		end,
		evidence = function(p, id)
			evidence[p] = id
			return true
		end,
	}, c)
	for i = 1, count or 1 do
		players[i] = h:player(i)
		run:Add(players[i])
	end
	local f = {
		h = h,
		run = run,
		c = c,
		p = players,
		records = records,
		saves = saves,
		health = health,
		tutorial = tutorial,
		evidence = evidence,
		near = nearby,
		session = session,
		seated = seated,
		parts = parts,
		gear = gear,
		gearMode = gearMode,
		debugMessages = debugMessages,
		outside = outside,
	}
	function f:advance(seconds)
		h.time += seconds
		run:Tick()
		-- Existing shift scenarios use a deterministic input driver, never timer completion.
		if
			seconds == c.WorkSeconds
			and not self.manualPuzzles
			and run.stations.Bench.work
			and run.stations.Bench.work.Puzzle
		then
			self:solve()
		end
	end
	function f:solve(player)
		local lane = run.stations[run.players[player or players[1]].StationId]
		local work = lane.work
		local attempts = 0
		while lane.work == work and work.Puzzle do
			attempts += 1
			assert(attempts < 100, "puzzle driver must terminate")
			local puzzle = work.Puzzle
			local move = puzzle.Answer or puzzle.Sequence and puzzle.Sequence[puzzle.Progress + 1] or 4
			if puzzle.Kind == "Probes" then
				move = puzzle.Progress < 3 and table.find(puzzle.Tested, false) or puzzle.Answer + 3
			elseif puzzle.Placed then
				local item = table.find(puzzle.Placed, false)
				move = item * 10 + table.find(puzzle.Slots, item)
			elseif puzzle.Kind == "Circuit" then
				move = 7
				for i, rotation in ipairs(puzzle.Rotations) do
					if rotation ~= puzzle.Targets[i] then
						move = i
						break
					end
				end
			elseif puzzle.Kind == "Dials" then
				move = 7
				for i, value in ipairs(puzzle.Values) do
					if value ~= puzzle.Targets[i] then
						move = i
						break
					end
				end
			elseif puzzle.Kind == "Memory" or puzzle.Kind == "Speaker" then
				h.time = math.max(h.time, puzzle.RevealUntil)
			elseif puzzle.Cells then
				for i, value in ipairs(puzzle.Cells) do
					if value ~= puzzle.Targets[i] then
						move = i
						break
					end
				end
			end
			move = benchMove(puzzle, h.time + 0.6) or move
			h.time += 0.6
			run:Tick()
			if lane.work ~= work then
				break
			end
			assert(run:Action(work.Player, "PuzzleInput", {
				OrderId = work.OrderId,
				WorkId = work.Id,
				Move = move,
				PuzzleRevision = puzzle.Revision,
			}))
		end
		h.time += c.FittingSeconds + 0.6
		run:Tick()
	end
	function f:act(action, player, extra)
		local actor = player or players[1]
		local lane = run.stations[run.players[actor].StationId]
		if action == "ClockIn" and not extra then
			run:Action(actor, "OpenClock", {})
			extra = { FocusId = run.players[actor].Focus and run.players[actor].Focus.Id }
		end
		-- Legacy rule scenarios assume the avatar is already at its station.
		-- Explicit workshop scenarios below disable this setup and exercise every action.
		if not self.explicitWorkshop then
			if action == "Collect" or action == "Restock" then
				seated[actor] = false
			end
			if table.find({ "Diagnose", "Repair", "Secure", "Install", "Test" }, action) then
				seated[actor] = true
			end
			if action == "Repair" and run.players[actor].CarriedPart then
				run.players[actor].CarriedPart, parts[actor] = nil, nil
				lane.order.PartHolder, lane.order.PartDelivered = nil, true
			end
		end
		local payload = extra
			or {
				OrderId = lane.order and lane.order.Id,
				EventId = run.event and run.event.Id,
				Contact = lane.order and (lane.order.Contacts or 0) + 1,
			}
		return run:Action(actor, action, payload)
	end
	function f:start()
		run:Tick()
		self:advance(3)
		for _, p in ipairs(players) do
			self:act("ClockIn", p)
			self:act("ReadRules", p)
		end
		self:advance(c.ArrivalSeconds)
	end
	function f:repair()
		check(self:act("TakeOrder"), "accept customer")
		for _, action in ipairs({ "Diagnose", "Collect", "Repair", "Install" }) do
			if action == "Install" then
				self:advance(0.6)
				check(self:act("Secure"), "start reassembly before installation")
				self:solve()
			end
			self:advance(0.6)
			check(self:act(action), "start " .. action)
			self:advance(c.WorkSeconds)
		end
		if run.stations.Bench.order.Step == "Evidence" then
			for _, p in ipairs(players) do
				self:act("Vote", p, { OrderId = run.stations.Bench.order.Id, Choice = "Report" })
			end
		end
		self:advance(0.6)
		check(self:act("Test"), "start final test")
		self:advance(c.WorkSeconds)
		check(self:act("Return"), "return repair")
	end
	return f
end
