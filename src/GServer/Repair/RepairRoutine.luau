-- One authored Phone: open before diagnosing, exchange one fault, then reassemble.
local Routine = {}
local Bench = require(script.Parent.BenchTasks)
local Tasks = require(script.Parent.RepairTasks)
local function stage(p, name, now)
	local action, fault, rev, index = p.Routine, p.RoutineFault, p.Revision or 0, (p.TaskIndex or 0) + 1
	local nextPuzzle
	if name == "OpenScrews" or name == "CloseScrews" then
		nextPuzzle = Bench.New("Screws", 1, now)
		nextPuzzle.TurnsRequired = 1
		nextPuzzle.Title = name == "OpenScrews" and "REMOVE FOUR SCREWS" or "TIGHTEN FOUR SCREWS"
		nextPuzzle.Hint = "Turn each screw once."
	elseif name == "Probes" then
		nextPuzzle = Tasks.New("Diagnose", fault, 1, 4, now)
	elseif name == "Exchange" then
		nextPuzzle = Bench.New("Screen", 1, now)
		nextPuzzle.ExchangeOnly, nextPuzzle.Component = true, string.upper(fault)
		nextPuzzle.Phase = fault == "Battery" and 2 or 1
		nextPuzzle.Title, nextPuzzle.Hint = "REPLACE THE " .. string.upper(fault), "Fit the replacement from Storage."
	elseif name == "Test" then
		nextPuzzle = Bench.New("Stamp", 1, now)
		nextPuzzle.Failed, nextPuzzle.Title = false, "FINAL PHONE CHECK"
	else
		nextPuzzle = Bench.New("Screen", 1, now)
		local battery = name == "RemoveBattery" or name == "FitBattery"
		local remove = name == "RemoveBattery" or name == "RemoveCover"
		nextPuzzle.Phase = remove and 1 or 2
		nextPuzzle.Component = battery and "BATTERY" or "BACK COVER"
		nextPuzzle.Title = (remove and "REMOVE " or "INSTALL ") .. nextPuzzle.Component
		nextPuzzle.Hint = remove and "Move the part beside the phone." or "Move the part back into its socket."
	end
	table.clear(p)
	for k, v in pairs(nextPuzzle) do
		p[k] = v
	end
	p.Routine, p.RoutineFault, p.DeviceStage = action, fault, name
	p.Revision, p.TaskIndex = rev, index
	p.TaskCount = action == "Diagnose" and 4 or action == "Secure" and (fault == "Battery" and 2 or 3) or 1
end
function Routine.New(action, fault, seed, now)
	if not table.find({ "Diagnose", "Repair", "Secure", "Test" }, action) then
		return nil
	end
	local p = { Routine = action, RoutineFault = fault }
	stage(
		p,
		action == "Diagnose" and "OpenScrews"
			or action == "Repair" and "Exchange"
			or action == "Secure" and (fault == "Battery" and "FitCover" or "FitBattery")
			or "Test",
		now
	)
	return p
end
function Routine.Input(p, move, revision, now)
	local name = p.DeviceStage
	local nextStage = ({
		OpenScrews = "RemoveCover",
		RemoveCover = "RemoveBattery",
		RemoveBattery = "Probes",
		FitBattery = "FitCover",
		FitCover = "CloseScrews",
	})[name]
	local ok, solved, code
	if name == "RemoveCover" or name == "RemoveBattery" or name == "FitBattery" or name == "FitCover" then
		if revision ~= p.Revision then
			return false, false, "PuzzleChanged"
		end
		if move ~= 11 then
			return false, false, "InvalidInput"
		end
		p.Revision += 1
		ok, solved = true, true
	elseif name == "Probes" then
		ok, solved, code = Tasks.Input(p, move, revision, now)
	else
		ok, solved, code = Bench.Input(p, move, revision, now)
	end
	if ok and solved and nextStage then
		stage(p, nextStage, now)
		return true, false
	end
	return ok, solved, code
end
return Routine
