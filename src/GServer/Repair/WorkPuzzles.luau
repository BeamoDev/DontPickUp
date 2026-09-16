-- Pure interaction rules. Inputs carry a revision so delayed clicks cannot solve later steps.
local Puzzles = {}
local Tasks = require(script.Parent.RepairTasks)
local Bench = require(script.Parent.BenchTasks)
Puzzles.Gear = {
	Diagnose = "Tester",
	Repair = "Screwdriver",
	Install = "Cartridge",
	Test = "Tester",
	Secure = "Screwdriver",
}
local function sequence(kind, title, hint, values, labels)
	return {
		Kind = kind,
		Title = title,
		Hint = hint,
		Sequence = values,
		Labels = labels,
		Progress = 0,
		Revision = 0,
	}
end
local function digits(seed, count, choices, salt)
	local values = {}
	local value = (seed + salt) % 2147483646 + 1
	for i = 1, count do
		value = value * 48271 % 2147483647
		values[i] = value % choices + 1
	end
	return values
end
local function basic(action, fault, serial, length, now)
	local seed = serial or 1
	local taskPuzzle = Tasks.New(action, fault, seed, length, now)
	if taskPuzzle then
		return taskPuzzle
	end
	if action == "Install" then
		return sequence(
			"Install",
			"ADD THE PHONE PROGRAM",
			"Press these numbers from left to right.",
			digits(seed, length or 4, 6, 73)
		)
	elseif action == "Restock" then
		return sequence(
			"Restock",
			"UNPACK THE PARTS",
			"Choose the parts in the order shown below.",
			digits(seed, length or 3, 3, 97),
			{ "BATTERY", "SPEAKER", "KEYPAD" }
		)
	end
	error("Unsupported work action: " .. tostring(action))
end
function Puzzles.IsEasy(tutorial, night, seed)
	-- Familiar jobs remain common after training; a retry keeps the same difficulty.
	return tutorial == true or night <= 1 or seed % 3 ~= 0
end

function Puzzles.New(action, fault, serial, length, now, expanded, easy)
	local seed = serial or 1
	local puzzle, pending = nil, {}
	if easy then
		expanded = false
	end
	if action == "Secure" then
		puzzle, pending = Bench.New("Assembly", seed, now), { "Screws" }
	elseif easy and (action == "Test" or (action == "Repair" and fault == "Keypad")) then
		puzzle = Bench.New("Buttons", seed, now)
		puzzle.Sequence = digits(seed, 3, 6, 127)
		puzzle.Title = action == "Test" and "CHECK THE PHONE BUTTONS" or "CHECK THE NEW BUTTONS"
	elseif easy and action == "Install" then
		puzzle = sequence(
			"Install",
			"ADD THE PHONE PROGRAM",
			"Press these numbers from left to right.",
			digits(seed, 3, 6, 73)
		)
	elseif expanded and action == "Restock" then
		puzzle = Bench.New("Sort", seed, now)
	elseif expanded and action == "Install" and seed % 4 ~= 0 then
		puzzle = Bench.New(({ "Waves", "PhoneNumber", "Buttons" })[seed % 4], seed, now)
	elseif expanded and action == "Test" and seed % 2 == 1 then
		puzzle = Bench.New("Speaker", seed, now)
	else
		puzzle = basic(action, fault, seed, length, now)
	end
	if expanded then
		if action == "Diagnose" then
			pending = { ({ "Clean", "Debris", "Broken" })[seed % 3 + 1] }
		elseif action == "Repair" then
			pending = { ({ "Screen", "SIM", "Fuse", "Charger" })[seed % 4 + 1] }
		elseif action == "Test" then
			pending = seed % 3 == 0 and { "Meter", "Stamp" } or { "Stamp" }
		end
	end
	puzzle.Pending, puzzle.Seed = pending, seed
	puzzle.TaskIndex, puzzle.TaskCount = 1, #pending + 1
	return puzzle
end
function Puzzles.Input(puzzle, move, revision, now)
	local ok, solved, code
	if Bench.Is(puzzle) then
		ok, solved, code = Bench.Input(puzzle, move, revision, now)
	elseif Tasks.Is(puzzle) then
		ok, solved, code = Tasks.Input(puzzle, move, revision, now)
	else
		ok, solved, code = Puzzles.SequenceInput(puzzle, move, revision)
	end
	if ok and solved and puzzle.Pending and #puzzle.Pending > 0 then
		local pending, seed = puzzle.Pending, puzzle.Seed
		local index, count, nextRevision = puzzle.TaskIndex + 1, puzzle.TaskCount, puzzle.Revision
		local nextPuzzle = Bench.New(table.remove(pending, 1), seed, now)
		table.clear(puzzle)
		for key, value in pairs(nextPuzzle) do
			puzzle[key] = value
		end
		puzzle.Pending, puzzle.Seed, puzzle.Revision = pending, seed, nextRevision
		puzzle.TaskIndex, puzzle.TaskCount = index, count
		return true, false
	end
	return ok, solved, code
end
function Puzzles.SequenceInput(puzzle, move, revision)
	if revision ~= puzzle.Revision then
		return false, false, "PuzzleChanged"
	end
	if type(move) ~= "number" or move % 1 ~= 0 or move < 1 or move > 6 then
		return false, false, "InvalidInput"
	end
	local solved, wrong = false, false
	if puzzle.Labels and move > #puzzle.Labels then
		return false, false, "InvalidInput"
	end
	if move == puzzle.Sequence[puzzle.Progress + 1] then
		puzzle.Progress += 1
		solved = puzzle.Progress == #puzzle.Sequence
	else
		puzzle.Progress, wrong = 0, true
	end
	puzzle.Revision += 1
	puzzle.Feedback = wrong and "Try again from the first item on the list."
		or solved and "DONE!"
		or "Good! Keep going."
	return true, solved
end
function Puzzles.Snapshot(puzzle)
	local result = {}
	for key, value in pairs(puzzle) do
		if
			key ~= "Answer"
			and key ~= "Solved"
			and key ~= "Pending"
			and key ~= "Seed"
			and not (puzzle.Kind == "Circuit" and key == "Targets")
		then
			result[key] = type(value) == "table" and table.clone(value) or value
		end
	end
	if puzzle.Kind == "Probes" then
		result.Hint = puzzle.Progress < 3 and "Check each part. Press the buttons marked CHECK."
			or "One part is BROKEN. Choose REPLACE for that part."
		for i in ipairs(result.Readings) do
			if not puzzle.Tested[i] then
				result.Readings[i] = "PRESS TO CHECK"
			end
		end
	elseif puzzle.Kind == "Screen" then
		result.Hint = puzzle.Phase == 1 and "Move the cracked screen to the waste tray."
			or puzzle.Phase == 2 and "Move the new screen into the phone."
			or "Press each of the four clips to hold the screen in place."
	elseif puzzle.Kind == "Assembly" then
		result.Hint = "Next: move the "
			.. ({ "BOARD", "BATTERY", "COVER" })[math.min(puzzle.Progress + 1, 3)]
			.. " to its matching space."
	elseif puzzle.Kind == "Fuse" then
		result.Hint = puzzle.Phase == 1 and "Move the broken fuse to the waste tray."
			or "Move the fuse with number " .. puzzle.Rating .. " into the matching space."
	elseif puzzle.Kind == "Stamp" then
		result.Hint = puzzle.Retest and "Press FIX LOOSE WIRE. Then check the results again."
			or puzzle.Failed and "The wire is loose. Press FIX IT FIRST."
			or "Everything works! Press PHONE IS READY."
	end
	return result
end
return Puzzles
