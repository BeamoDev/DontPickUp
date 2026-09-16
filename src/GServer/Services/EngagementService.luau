-- Server-owned social summaries and fictional employee records.
-- This module uses only actions performed inside the current run. It never reads chat or external player data.
local Engagement = {}

Engagement.Signals = {
	Parts = "I'LL GET THE PART",
	Phone = "CHECK THE PHONE",
	Inside = "GET INSIDE",
	NoAnswer = "DO NOT ANSWER THAT",
	Ticket = "I HAVE THE TICKET",
	Why = "WHY DID YOU OPEN THAT?",
}

local function blankActivity()
	return {
		Repairs = 0,
		Parts = 0,
		Screws = 0,
		Records = 0,
		Calls = 0,
		Votes = 0,
		WarningsEscaped = 0,
		FaxCalls = 0,
		Signals = 0,
		RuleBreaks = 0,
	}
end

function Engagement.ResetMember(member, continuing)
	member.Activity = blankActivity()
	member.Signal = nil
	member.SignalUntil = nil
	member.Handbook = continuing and member.Handbook or {
		Customers = {},
		Anomalies = {},
		Stamps = {},
	}
end

function Engagement.Add(member, key, amount)
	if not member then
		return
	end
	member.Activity = member.Activity or blankActivity()
	member.Activity[key] = math.max(0, (member.Activity[key] or 0) + (amount or 1))
end

function Engagement.Unlock(member, section, id)
	if not member or type(id) ~= "string" then
		return false
	end
	member.Handbook = member.Handbook or { Customers = {}, Anomalies = {}, Stamps = {} }
	local collection = member.Handbook[section]
	if not collection or collection[id] then
		return false
	end
	collection[id] = true
	return true
end

local function count(map)
	local total = 0
	for _ in pairs(map or {}) do
		total += 1
	end
	return total
end

function Engagement.CollectionSnapshot(member)
	local handbook = member and member.Handbook or {}
	return {
		Customers = count(handbook.Customers),
		Anomalies = count(handbook.Anomalies),
		Stamps = count(handbook.Stamps),
	}
end

local function observedLines(member)
	local a = member.Activity or blankActivity()
	local lines = {}
	if a.Repairs > 0 then
		table.insert(lines, "CONTRIBUTED TO " .. a.Repairs .. " COMPLETED REPAIR" .. (a.Repairs == 1 and "" or "S"))
	end
	if a.Records > 0 then
		table.insert(lines, "OPENED " .. a.Records .. " PRIVATE RECORD" .. (a.Records == 1 and "" or "S"))
	end
	if a.Calls > 0 then
		table.insert(lines, "MADE " .. a.Calls .. " PRIVATE CALL" .. (a.Calls == 1 and "" or "S"))
	end
	if a.Parts > 0 then
		table.insert(lines, "DELIVERED " .. a.Parts .. " REPLACEMENT PART" .. (a.Parts == 1 and "" or "S"))
	end
	if a.Votes > 0 then
		table.insert(lines, "CAST " .. a.Votes .. " SEALED TEAM VOTE" .. (a.Votes == 1 and "" or "S"))
	end
	if #lines == 0 then
		table.insert(lines, "REMAINED QUIET DURING OBSERVATION")
	end
	return lines
end

function Engagement.Evaluation(player, member, night, suspicion, prediction)
	local a = member.Activity or blankActivity()
	local status = not member.Alive and "TRANSFERRED"
		or suspicion >= 50 and "UNDER REVIEW"
		or a.RuleBreaks > 0 and "OBSERVATION REQUIRED"
		or "ACCEPTABLE"
	local lines = observedLines(member)
	if prediction then
		table.insert(lines, prediction)
	end
	return {
		Employee = player.DisplayName,
		UserId = player.UserId,
		Night = night,
		Status = status,
		Observed = lines,
		Notice = "FICTIONAL FILE / IN-SHIFT ACTIONS ONLY",
	}
end

local awardDefinitions = {
	{ Key = "Screws", Title = "FASTEST SCREWER", Detail = "Tightened the most screws." },
	{ Key = "Records", Title = "DEFINITELY DID NOT SNOOP", Detail = "Opened the most private records." },
	{ Key = "Parts", Title = "STOCKROOM RESIDENT", Detail = "Delivered the most replacement parts." },
	{ Key = "WarningsEscaped", Title = "PROFESSIONAL COWARD", Detail = "Got back inside when it mattered." },
	{ Key = "FaxCalls", Title = "CUSTOMER SERVICE HERO", Detail = "Called the most customers back." },
	{ Key = "Calls", Title = "PHONE PRIVILEGES REVOKED", Detail = "Made the most private calls." },
	{ Key = "Repairs", Title = "MINISTRY PRODUCTIVITY STAR", Detail = "Contributed to the most finished repairs." },
}

function Engagement.Awards(players)
	local awards, used = {}, {}
	for _, definition in ipairs(awardDefinitions) do
		local winner, score
		for player, member in pairs(players) do
			local value = member.Activity and member.Activity[definition.Key] or 0
			if value > 0 and (not score or value > score or value == score and player.UserId < winner.UserId) then
				winner, score = player, value
			end
		end
		if winner and not used[winner] then
			used[winner] = true
			table.insert(awards, {
				UserId = winner.UserId,
				Name = winner.DisplayName,
				Title = definition.Title,
				Detail = definition.Detail,
				Score = score,
			})
			if #awards == 4 then
				break
			end
		end
	end
	return awards
end

function Engagement.Signal(run, player, key)
	local member = run.players[player]
	local text = Engagement.Signals[key]
	if not member or not text then
		return false, "InvalidSignal"
	end
	local now = run.d.clock()
	if now < (member.NextSignal or 0) then
		return false, "PleaseWait"
	end
	member.NextSignal = now + 2.5
	member.Signal = text
	member.SignalUntil = now + 4
	Engagement.Add(member, "Signals")
	run:_say(player.DisplayName, text)
	run:_publish()
	return true
end

function Engagement.BuildReports(run)
	local reports = {}
	for player, member in pairs(run.players) do
		local prediction
		if run.night >= 3 and (player.UserId + run.night) % 3 == 0 then
			prediction = "PREDICTION: WILL ANSWER A CALL THAT HAS NOT RUNG YET"
		end
		table.insert(reports, Engagement.Evaluation(player, member, run.night, run.suspicion, prediction))
	end
	table.sort(reports, function(a, b)
		return a.UserId < b.UserId
	end)
	return reports
end

function Engagement.PublicReports(reports)
	local public = {}
	for _, report in ipairs(reports or {}) do
		table.insert(public, {
			Employee = report.Employee,
			UserId = report.UserId,
			Status = report.Status,
			Notice = report.Notice,
		})
	end
	return public
end

return Engagement
