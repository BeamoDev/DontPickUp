-- Additional short, server-owned bench tasks. All moves are discrete controls, never completion claims.
local Tasks = {}
local definitions = {
	Clean = { "CLEAN THE PHONE", "Scrub each dirty patch twice. Clear all six patches." },
	Debris = { "REMOVE THE TRASH", "Move the coin, fluff and paper clip to the waste tray." },
	Broken = { "REMOVE THE BROKEN PART", "Choose the part marked BROKEN. Leave the working parts alone." },
	Screen = {
		"REPLACE THE CRACKED SCREEN",
		"Remove the cracked screen, fit the new one, then press all four clips.",
	},
	SIM = { "PUT IN THE CARD", "Turn the card so its cut-out edge matches the slot. Then move it into the slot." },
	Fuse = { "REPLACE THE FUSE", "Remove the broken fuse. Match the number on the new fuse to the space." },
	Charger = { "CONNECT THE TEST CHARGER", "Move the plug to the hole with the same shape." },
	Sort = { "SORT THE PARTS", "Move each part to the tray with the same name." },
	Assembly = {
		"PUT THE PHONE BACK TOGETHER",
		"Put in the BOARD first, then the BATTERY, then the COVER.",
	},
	Screws = { "TIGHTEN FOUR SCREWS", "Turn each screw three times. Do all four screws." },
	Buttons = { "CHECK THE BUTTONS", "Press these numbers from left to right." },
	PhoneNumber = { "TYPE THE PHONE NUMBER", "Press these numbers from left to right. START OVER clears your answer." },
	Waves = {
		"MATCH THE TWO LINES",
		"Make the colored line match the white line. Use BUMPS and SLIDE, then CHECK.",
	},
	Meter = { "KEEP THE BAR IN THE MIDDLE", "Use LEFT and RIGHT to keep the bar in the green area. Then press CHECK." },
	Stamp = { "IS THE PHONE READY?", "Check the results. Fix anything broken before marking the phone ready." },
	Speaker = {
		"TEST THE SPEAKER",
		"Watch the numbers light up. Press them in the same order. Sound is just a hint.",
	},
}
function Tasks.Is(p)
	return definitions[p.Kind] ~= nil
end
local function rolls(seed, count, maximum)
	local result = {}
	for i = 1, count do
		seed = (seed * 48271 + 17) % 2147483647
		result[i] = seed % maximum + 1
	end
	return result
end
function Tasks.New(kind, seed, now)
	local def = definitions[kind]
	assert(def, "Unknown bench task")
	local p = { Kind = kind, Title = def[1], Hint = def[2], Revision = 0, Progress = 0 }
	now = now or 0
	if kind == "Clean" then
		p.Dirt = { 2, 2, 2, 2, 2, 2 }
	elseif kind == "Screws" then
		p.Turns = { 0, 0, 0, 0 }
	elseif kind == "Debris" then
		p.Removed = { false, false, false }
	elseif kind == "Broken" then
		p.Bad = seed % 6 + 1
	elseif kind == "Screen" then
		p.Phase, p.Clips = 1, { false, false, false, false }
	elseif kind == "SIM" then
		p.Notch, p.Rotation = seed % 4, (seed + 1) % 4
	elseif kind == "Fuse" then
		p.Phase, p.Rating = 1, seed % 3 + 1
	elseif kind == "Charger" then
		p.Port = seed % 3 + 1
	elseif kind == "Sort" or kind == "Assembly" then
		p.Slots, p.Placed = { 1, 2, 3 }, { false, false, false }
		for i = 3, 2, -1 do
			local j = (seed + i) % i + 1
			p.Slots[i], p.Slots[j] = p.Slots[j], p.Slots[i]
		end
	elseif kind == "Buttons" or kind == "PhoneNumber" or kind == "Speaker" then
		p.Sequence =
			rolls(seed, kind == "PhoneNumber" and 7 or 4, kind == "PhoneNumber" and 10 or kind == "Speaker" and 3 or 6)
		if kind == "Speaker" then
			p.RevealAt, p.RevealUntil = now + 0.8, now + 0.8 + #p.Sequence * 0.7 + 0.7
		end
	elseif kind == "Waves" then
		p.Targets = { seed % 3 + 1, seed % 8 }
		p.Values = { p.Targets[1] % 3 + 1, (p.Targets[2] + 3) % 8 }
	elseif kind == "Meter" then
		p.Value, p.At, p.Good, p.Drift = 0.15, now, 0, 0.09
	elseif kind == "Stamp" then
		p.Failed, p.Retest = seed % 2 == 0, false
	end
	return p
end
function Tasks.Input(p, move, revision, now)
	if revision ~= p.Revision or p.Solved then
		return false, false, "PuzzleChanged"
	end
	if type(move) ~= "number" or move % 1 ~= 0 or move < 1 or move > 99 then
		return false, false, "InvalidInput"
	end
	now = now or 0
	local solved, wrong = false, false
	local item, slot = math.floor(move / 10), move % 10
	if p.Kind == "Clean" then
		if move > 6 or p.Dirt[move] == 0 then
			return false, false, "InvalidInput"
		end
		p.Dirt[move] -= 1
		p.Progress += 1
		solved = p.Progress == 12
	elseif p.Kind == "Screws" then
		if move > 4 or p.Turns[move] == 3 then
			return false, false, "InvalidInput"
		end
		p.Turns[move] += 1
		if p.Turns[move] == 3 then
			p.Progress += 1
		end
		solved = p.Progress == 4
	elseif p.Kind == "Debris" then
		if item < 1 or item > 3 or slot ~= 1 or p.Removed[item] then
			return false, false, "InvalidInput"
		end
		p.Removed[item], p.Progress = true, p.Progress + 1
		solved = p.Progress == 3
	elseif p.Kind == "Broken" then
		if move > 6 then
			return false, false, "InvalidInput"
		end
		solved, wrong = move == p.Bad, move ~= p.Bad
	elseif p.Kind == "Screen" then
		if p.Phase == 1 or p.Phase == 2 then
			if move ~= 11 then
				return false, false, "InvalidInput"
			end
			p.Phase += 1
		else
			if move > 4 or p.Clips[move] then
				return false, false, "InvalidInput"
			end
			p.Clips[move], p.Progress = true, p.Progress + 1
			solved = p.Progress == 4
		end
	elseif p.Kind == "SIM" then
		if move == 7 then
			p.Rotation = (p.Rotation + 1) % 4
		elseif move == 11 then
			solved, wrong = p.Rotation == p.Notch, p.Rotation ~= p.Notch
		else
			return false, false, "InvalidInput"
		end
	elseif p.Kind == "Fuse" then
		if p.Phase == 1 and move == 11 then
			p.Phase = 2
		elseif p.Phase == 2 and item >= 1 and item <= 3 and slot == 1 then
			solved, wrong = item == p.Rating, item ~= p.Rating
		else
			return false, false, "InvalidInput"
		end
	elseif p.Kind == "Charger" then
		if item < 1 or item > 3 or slot ~= 1 then
			return false, false, "InvalidInput"
		end
		solved, wrong = item == p.Port, item ~= p.Port
	elseif p.Kind == "Sort" or p.Kind == "Assembly" then
		if item < 1 or item > 3 or slot < 1 or slot > 3 or p.Placed[item] then
			return false, false, "InvalidInput"
		end
		if p.Slots[slot] == item and (p.Kind ~= "Assembly" or item == p.Progress + 1) then
			p.Placed[item], p.Progress = true, p.Progress + 1
			solved = p.Progress == 3
		else
			wrong = true
		end
	elseif p.Sequence then
		local speaker = p.Kind == "Speaker"
		if (speaker and move == 7) or (p.Kind == "PhoneNumber" and move == 11) then
			p.Progress = 0
			if speaker then
				p.RevealAt, p.RevealUntil = now + 0.8, now + 0.8 + #p.Sequence * 0.7 + 0.7
			end
		elseif move > (p.Kind == "PhoneNumber" and 10 or speaker and 3 or 6) then
			return false, false, "InvalidInput"
		elseif speaker and now < p.RevealUntil then
			return false, false, "PleaseWait"
		elseif move == p.Sequence[p.Progress + 1] then
			p.Progress += 1
			solved = p.Progress == #p.Sequence
		else
			p.Progress, wrong = 0, true
		end
	elseif p.Kind == "Waves" then
		if move <= 4 then
			local index = move <= 2 and 1 or 2
			local limit = index == 1 and 3 or 8
			local offset = index == 1 and 1 or 0
			p.Values[index] = (p.Values[index] - offset + (move % 2 == 0 and 1 or -1)) % limit + offset
		elseif move == 7 then
			solved = p.Values[1] == p.Targets[1] and p.Values[2] == p.Targets[2]
			wrong = not solved
		else
			return false, false, "InvalidInput"
		end
	elseif p.Kind == "Meter" then
		if move ~= 1 and move ~= 2 and move ~= 7 then
			return false, false, "InvalidInput"
		end
		-- Integrate on input using server time. No frame-rate messages or client-reported dwell time.
		local elapsed = math.clamp(now - p.At, 0, 5)
		local steps = math.max(1, math.ceil(elapsed / 0.05))
		for _ = 1, steps do
			p.Value = math.clamp(p.Value + p.Drift * elapsed / steps, 0, 1)
			p.Good = p.Value >= 0.35 and p.Value <= 0.65 and p.Good + elapsed / steps or 0
		end
		p.At = now
		if move == 7 then
			solved, wrong = p.Good >= 2.5, p.Good < 2.5
		else
			p.Value = math.clamp(p.Value + (move == 1 and -0.10 or 0.10), 0, 1)
			if p.Value < 0.35 or p.Value > 0.65 then
				p.Good = 0
			end
		end
	elseif p.Kind == "Stamp" then
		if p.Retest then
			if move ~= 3 then
				return false, false, "InvalidInput"
			end
			p.Retest, p.Failed = false, false
		elseif move == 1 or move == 2 then
			if p.Failed and move == 2 then
				p.Retest = true
			else
				solved = not p.Failed and move == 1
				wrong = not solved
			end
		else
			return false, false, "InvalidInput"
		end
	end
	p.Solved, p.Revision = solved, p.Revision + 1
	p.Feedback = solved and "DONE!" or wrong and "Not quite. Match the labels and try again." or "Keep going."
	if wrong and p.Sequence then
		p.Feedback = p.Kind == "Speaker" and "Try from the first number. WATCH AGAIN can help."
			or "Try again from the first number shown."
	elseif wrong and p.Kind == "Broken" then
		p.Feedback = "That part works. Choose the one marked BROKEN."
	elseif wrong and p.Kind == "Stamp" then
		p.Feedback = p.Failed and "Fix the loose wire first." or "Everything works. Press PHONE IS READY."
	end
	return true, solved
end
return Tasks
