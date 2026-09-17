-- Short Story arc conclusions. ShiftService gates resolution to death/final survival.
local Endings = {}
local function ending(id, title, summary)
	return { Id = "prototype_" .. id, Title = title, Summary = summary }
end
function Endings.Resolve(run, member)
	if member.Outcome == "Died" then
		return ending(
			"missing_employee",
			"MISSING EMPLOYEE",
			"Your timecard is still in the rack. Someone has crossed out your name."
		)
	end
	if member.Outcome ~= "Survived" then
		return nil
	end
	if (run.answered or 0) > 0 then
		return ending(
			"line_open",
			"THE LINE IS STILL OPEN",
			"You reached morning. At home, a disconnected phone begins to ring."
		)
	end
	if run.suspicion >= 50 then
		return ending(
			"under_observation",
			"UNDER OBSERVATION",
			"Your shift is over. The government car outside has not moved."
		)
	end
	local choices = {}
	if member.Secrets and member.Secrets.Timecard and member.Secrets.Tape and member.Secrets.Locker then
		return ending(
			"night_archivist",
			"THE NIGHT ARCHIVIST",
			"You leave with the missing employees' records. This time, their names will not disappear."
		)
	end
	for _, choice in ipairs(run.decisions) do
		choices[choice] = true
	end
	if choices.Investigate then
		return ending(
			"afterhours_witness",
			"AFTER-HOURS WITNESS",
			"The names in the phones belong to real people. You leave with a clue they wanted erased."
		)
	elseif choices.Hide then
		return ending(
			"civilian_protector",
			"CIVILIAN PROTECTOR",
			"One name is missing from the report. Somewhere in the city, someone gets another morning."
		)
	elseif choices.Report then
		return ending(
			"loyal_employee",
			"LOYAL EMPLOYEE",
			"Your report was accepted. The customer's number is no longer in service."
		)
	end
	return ending(
		"another_morning",
		"ANOTHER MORNING",
		"You kept your head down and finished the shift. Tomorrow's directive is already waiting."
	)
end
return Endings
