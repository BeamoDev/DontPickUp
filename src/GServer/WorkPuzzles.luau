-- Pure interaction rules. Inputs carry a revision so delayed clicks cannot solve later steps.
local Puzzles = {}
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
function Puzzles.New(action, fault, serial, length)
	local seed = serial or 1
	if action == "Diagnose" then
		return {
			Kind = "Diagnose",
			Title = "BENCH TESTER",
			Hint = "Read the three measurements. Select the failing component.",
			Labels = {
				fault == "Battery" and "BATTERY / 0.2 V / LOW" or "BATTERY / 3.7 V / OK",
				fault == "Speaker" and "SPEAKER / OPEN CIRCUIT" or "SPEAKER / 8 OHMS / OK",
				fault == "Keypad" and "KEYPAD / NO RESPONSE" or "KEYPAD / RESPONSE OK",
			},
			Answer = table.find({ "Battery", "Speaker", "Keypad" }, fault),
			Revision = 0,
			Progress = 0,
		}
	elseif action == "Repair" and fault ~= "Keypad" then
		local target = digits(seed, 3, fault == "Battery" and 2 or 3, 17)
		for i, value in ipairs(target) do
			target[i] = value - 1
		end
		local cells = {}
		for i, value in ipairs(target) do
			cells[i] = (value + 1) % (fault == "Battery" and 2 or 3)
		end
		return {
			Kind = fault,
			Title = fault == "Battery" and "ALIGN BATTERY CONTACTS" or "CONNECT SPEAKER WIRES",
			Hint = fault == "Battery"
					and "Flip each contact to match the polarity printed above it. Then check the connection."
				or "Cycle each wire to match its terminal color. Then check continuity.",
			Cells = cells,
			Targets = target,
			Revision = 0,
			Progress = 0,
		}
	elseif action == "Repair" then
		return sequence(
			"Keypad",
			"REBUILD KEYPAD",
			"Press the keys in the order printed on the test card.",
			digits(seed, length or 4, 6, 31)
		)
	elseif action == "Install" then
		return sequence(
			"Install",
			"VERIFY GOVERNMENT CARTRIDGE",
			"Enter the verification digits printed on the cartridge label.",
			digits(seed, length or 4, 6, 73)
		)
	elseif action == "Restock" then
		return sequence(
			"Restock",
			"SORT DELIVERY CRATE",
			"Pack the labels in the manifest order. Complete the manifest to restock.",
			digits(seed, length or 3, 3, 97),
			{ "BATTERY", "SPEAKER", "KEYPAD" }
		)
	end
	return sequence(
		"Test",
		"FINAL FUNCTION TEST",
		"Repeat the inspection sequence. A wrong input restarts the test.",
		digits(seed, length and math.max(3, length - 1) or 3, 6, 127)
	)
end
function Puzzles.Input(puzzle, move, revision)
	if revision ~= puzzle.Revision then
		return false, false, "PuzzleChanged"
	end
	if type(move) ~= "number" or move % 1 ~= 0 or move < 1 or move > 6 then
		return false, false, "InvalidInput"
	end
	local solved, wrong = false, false
	if puzzle.Kind == "Diagnose" then
		if move > 3 then
			return false, false, "InvalidInput"
		end
		solved, wrong = move == puzzle.Answer, move ~= puzzle.Answer
	elseif puzzle.Cells then
		if move <= 3 then
			puzzle.Cells[move] = (puzzle.Cells[move] + 1) % (puzzle.Kind == "Battery" and 2 or 3)
		elseif move == 4 then
			solved = true
			for i, target in ipairs(puzzle.Targets) do
				if puzzle.Cells[i] ~= target then
					solved = false
				end
			end
			wrong = not solved
		else
			return false, false, "InvalidInput"
		end
	else
		if puzzle.Labels and move > #puzzle.Labels then
			return false, false, "InvalidInput"
		end
		if move == puzzle.Sequence[puzzle.Progress + 1] then
			puzzle.Progress += 1
			solved = puzzle.Progress == #puzzle.Sequence
		else
			puzzle.Progress, wrong = 0, true
		end
	end
	puzzle.Revision += 1
	puzzle.Feedback = wrong and "Connection failed. Read the label and try again."
		or solved and "CHECK PASSED"
		or "Input accepted."
	return true, solved
end
function Puzzles.Snapshot(puzzle)
	local result = {}
	for key, value in pairs(puzzle) do
		if key ~= "Answer" then
			result[key] = type(value) == "table" and table.clone(value) or value
		end
	end
	return result
end
return Puzzles
