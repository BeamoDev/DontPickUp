-- Discrete, authoritative task rules. Pointer movement never reaches the server.
local Tasks = {}
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("GShared", 30)
assert(Shared, "Sync src/GShared to ReplicatedStorage.GShared in the Game place")
local Public = require(Shared:WaitForChild("Repair", 30):WaitForChild("Definitions", 30))
local KINDS = Public.TaskKinds
local function numbers(seed, count, choices)
	local result, value = {}, seed % 2147483646 + 1
	for i = 1, count do
		value = value * 48271 % 2147483647
		result[i] = value % choices + 1
	end
	return result
end
local function base(kind, title, hint)
	return { Kind = kind, Title = title, Hint = hint, Revision = 0, Progress = 0 }
end
function Tasks.Is(puzzle)
	return KINDS[puzzle.Kind] == true
end
function Tasks.New(action, fault, seed, length, now)
	local puzzle
	if action == "Diagnose" then
		puzzle = base("Probes", "FIND THE BROKEN PART", "Check each part, then choose the one marked BROKEN.")
		puzzle.Answer = table.find({ "Battery", "Speaker", "Keypad" }, fault)
		puzzle.Tested = { false, false, false }
		puzzle.Readings = {
			fault == "Battery" and "BROKEN" or "WORKING",
			fault == "Speaker" and "BROKEN" or "WORKING",
			fault == "Keypad" and "BROKEN" or "WORKING",
		}
	elseif action == "Repair" and (fault == "Battery" or fault == "Speaker") then
		local wire = fault == "Speaker"
		puzzle = base(
			wire and "Wires" or "BatteryFit",
			wire and "RECONNECT THE WIRES" or "PUT IN THE BATTERIES",
			wire and "Match each wire to the same number. Drag it, or tap both ends."
				or "Match each battery to the same label. Drag it, or tap both spaces."
		)
		puzzle.Slots, puzzle.Placed = { 1, 2, 3 }, { false, false, false }
		if wire then
			table.insert(puzzle.Slots, 4)
			table.insert(puzzle.Placed, false)
		end
		local count = #puzzle.Slots
		local rolls = numbers(seed + 17, count - 1, 6)
		for i = count, 2, -1 do
			local other = rolls[count + 1 - i] % i + 1
			puzzle.Slots[i], puzzle.Slots[other] = puzzle.Slots[other], puzzle.Slots[i]
		end
	elseif action == "Repair" then
		puzzle = base(
			"Circuit",
			"JOIN THE BROKEN PATH",
			"Turn the pieces to join START to END. Follow the top row, then come back below."
		)
		puzzle.Rotations = numbers(seed + 31, 6, 4)
		puzzle.Targets, puzzle.Shapes =
			{ 1, 1, 2, 1, 1, 3 }, { "Straight", "Straight", "Corner", "Straight", "Straight", "Corner" }
		for i, target in ipairs(puzzle.Targets) do
			puzzle.Rotations[i] = (target + 1 + puzzle.Rotations[i] % 2 * 2) % 4
		end
	elseif action == "Install" and seed % 2 == 0 then
		puzzle = base("Dials", "MATCH THE NUMBERS", "Turn each dial to the number above it. Then press CHECK NUMBERS.")
		puzzle.Targets, puzzle.Values = numbers(seed + 73, 3, 5), {}
		for i, target in ipairs(puzzle.Targets) do
			puzzle.Values[i] = target % 5 + 1
		end
	elseif action == "Test" then
		puzzle = base(
			"Memory",
			"COPY THE FLASHING NUMBERS",
			"Watch the numbers light up. Press them in the same order. WATCH AGAIN can help."
		)
		puzzle.Sequence = numbers(seed + 127, math.clamp((length or 4) - 1, 3, 5), 6)
		puzzle.Count = #puzzle.Sequence
		puzzle.RevealAt = (now or 0) + 0.8
		puzzle.RevealUntil = puzzle.RevealAt + puzzle.Count * 0.7 + 0.7
	end
	return puzzle
end
function Tasks.Input(puzzle, move, revision, now)
	if revision ~= puzzle.Revision or puzzle.Solved then
		return false, false, "PuzzleChanged"
	end
	if type(move) ~= "number" or move % 1 ~= 0 or move < 1 or move > 99 then
		return false, false, "InvalidInput"
	end
	local solved, wrong = false, false
	if puzzle.Kind == "Probes" then
		if move <= 3 then
			if not puzzle.Tested[move] then
				puzzle.Tested[move] = true
				puzzle.Progress += 1
			end
		elseif move <= 6 and puzzle.Progress == 3 then
			solved, wrong = move - 3 == puzzle.Answer, move - 3 ~= puzzle.Answer
		else
			return false, false, "InvalidInput"
		end
	elseif puzzle.Kind == "Wires" or puzzle.Kind == "BatteryFit" then
		local item, slot = math.floor(move / 10), move % 10
		if item < 1 or item > #puzzle.Slots or slot < 1 or slot > #puzzle.Slots or puzzle.Placed[item] then
			return false, false, "InvalidInput"
		end
		if puzzle.Slots[slot] == item then
			puzzle.Placed[item] = true
			puzzle.Progress += 1
			solved = puzzle.Progress == #puzzle.Slots
		else
			wrong = true
		end
	elseif puzzle.Kind == "Circuit" then
		if move <= 6 then
			puzzle.Rotations[move] = (puzzle.Rotations[move] + 1) % 4
		elseif move == 7 then
			solved = true
			for i, target in ipairs(puzzle.Targets) do
				local modulus = puzzle.Shapes[i] == "Straight" and 2 or 4
				if puzzle.Rotations[i] % modulus ~= target % modulus then
					solved = false
				end
			end
			wrong = not solved
		else
			return false, false, "InvalidInput"
		end
	elseif puzzle.Kind == "Dials" then
		if move <= 6 then
			local index = (move - 1) % 3 + 1
			puzzle.Values[index] = (puzzle.Values[index] - 1 + (move <= 3 and 1 or -1)) % 5 + 1
		elseif move == 7 then
			solved = true
			for i, value in ipairs(puzzle.Values) do
				if value ~= puzzle.Targets[i] then
					solved = false
				end
			end
			wrong = not solved
		else
			return false, false, "InvalidInput"
		end
	elseif puzzle.Kind == "Memory" then
		if move == 7 then
			puzzle.Progress = 0
			puzzle.RevealAt = (now or 0) + 0.8
			puzzle.RevealUntil = puzzle.RevealAt + puzzle.Count * 0.7 + 0.7
		elseif move > 6 then
			return false, false, "InvalidInput"
		elseif (now or 0) < puzzle.RevealUntil then
			return false, false, "PleaseWait"
		elseif move == puzzle.Sequence[puzzle.Progress + 1] then
			puzzle.Progress += 1
			solved = puzzle.Progress == puzzle.Count
		else
			puzzle.Progress, wrong = 0, true
		end
	else
		return false, false, "InvalidInput"
	end
	puzzle.Revision += 1
	puzzle.Solved = solved
	puzzle.Feedback = wrong and "Not quite. Check the labels and try again."
		or solved and "DONE!"
		or "Good! Keep going."
	if wrong and puzzle.Kind == "Probes" then
		puzzle.Feedback = "That part works. Choose the one marked BROKEN."
	elseif wrong and puzzle.Kind == "Memory" then
		puzzle.Feedback = "Try from the first number. Press WATCH AGAIN if you need help."
	end
	return true, solved
end
return Tasks
