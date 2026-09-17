-- Government policy and pacing are private, run-scoped decisions.
local Policy = {}
local directives = {
	"Install CIVIC WATCH on phones carrying a RED service sticker.",
	"Do not recover deleted customer records. Recovery leaves an access log.",
	"Do not call private contacts after curfew. Customer pickup calls are permitted.",
	"Install CIVIC WATCH on EVERY device, including unmarked phones.",
	"Report evidence of the Ministry archive. Do not keep a private copy.",
}
function Policy.Enabled(run)
	return run.c ~= nil and run.c.ShopDirection == true
end
function Policy.Current(night)
	local index = (night - 1) % #directives + 1
	return {
		Text = directives[index],
		RecoveryForbidden = index == 2,
		CallsForbidden = index == 3,
		AllUpdates = index == 4,
		ReportRequired = index == 5,
	}
end
function Policy.Start(run, continuing)
	if not Policy.Enabled(run) then
		return
	end
	run.government = continuing and run.government or { Trust = 0, Discrepancies = 0, Protected = 0 }
	run.policy = Policy.Current(run.night)
	run.caseIssued, run.nextIntakeAt = false, nil
	run.directorConfig.CalmSeconds = math.max(120, run.directorConfig.CalmSeconds)
	run.directorConfig.MaxEvents = math.min(3, run.directorConfig.MaxEvents)
	run.directorConfig.MaxScares = math.min(1, run.directorConfig.MaxScares)
	run.directorConfig.ScareChance = math.min(20, run.directorConfig.ScareChance)
	local bonus = continuing and run.government.Trust >= 2 and 1 or 0
	for fault in pairs(run.stock) do
		run.stock[fault] = 4 + bonus
	end
	-- Reliable service earns a quieter shift; no new event loop is introduced.
	if run.government.Trust >= 2 then
		run.directorConfig.IntervalMin += 12
		run.directorConfig.IntervalMax += 12
	end
end
function Policy.BlocksWork(run)
	local event = run.event
	if not event then
		return false
	end
	if not Policy.Enabled(run) then
		return true
	end
	return not event.Minor and not (event.Kind == "Inspection" and #run:_living() > 1)
end
function Policy.CanIntake(run)
	if not Policy.Enabled(run) then
		return true
	end
	if run.event or run.resumeAt or run.d.clock() < (run.nextIntakeAt or 0) then
		return false
	end
	local active = 0
	for _, lane in pairs(run.stations) do
		if lane.order then
			active += 1
		end
	end
	return active < math.min(2, #run:_living())
end
function Policy.Gap(run)
	if Policy.Enabled(run) and #run:_living() == 1 then
		return math.max(18, run.c.BetweenCustomers)
	end
	return run.c.BetweenCustomers
end
function Policy.Decide(run, order, choice)
	if not Policy.Enabled(run) or order.VotePurpose == "Software" then
		return
	end
	local state = run.government
	if choice == "Report" then
		state.Trust += 1
	else
		state.Discrepancies += 1
		if choice == "Hide" then
			state.Protected += 1
		end
		if run.policy.ReportRequired and order.VotePurpose ~= "Software" then
			run.ruleBreaks += 1
		end
	end
end
function Policy.Audit(run, order)
	if not Policy.Enabled(run) or order.Audited then
		return
	end
	order.Audited = true
	local phone = order.Phone
	if phone and phone.UpdateRequired then
		if phone.Installed then
			run.government.Trust += 1
		else
			run.government.Discrepancies += 1
			run.government.Trust = math.max(0, run.government.Trust - 1)
		end
	end
end
function Policy.Inspection(run)
	local state = run.government
	local bad = state.Discrepancies + (run.ruleBreaks or 0)
	if bad > 0 then
		run.suspicion = math.min(100, run.suspicion + math.min(25, bad * 5))
		return "Your service records do not match our access log. We will be checking this shop again."
	end
	run.suspicion = math.max(0, run.suspicion - 15)
	state.Trust += 1
	return "Your records are in order. Priority parts and power have been approved for your next shift."
end
function Policy.Whisper(run, player, speaker, text, appearance)
	local member = run.players[player]
	if not member then
		return
	end
	run.privateSerial = (run.privateSerial or 0) + 1
	member.PrivateDialogue = {
		Id = run.id .. "_private_" .. run.privateSerial,
		Speaker = speaker,
		Text = text,
		AppearanceId = appearance,
		StartedAt = run.d.clock(),
		ExpiresAt = run.d.clock() + 12,
	}
end
return Policy
