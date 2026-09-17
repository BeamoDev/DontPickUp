local Records = require(script.Parent.LoreCatalog)
local Lore = {}
local Policy = require(script.Parent.GovernmentService)
function Lore.Open(run, player, id)
	local member, record = run.players[player], Records[id]
	if not record or not run.d.near(player, "Secret_" .. id) then
		return false, "MoveCloser"
	end
	if run.event or run.d.seated(player) then
		return false, "StandFirst"
	end
	if record.Key and not run.d.hasGear(player, record.Key) then
		return false, "KeyRequired"
	end
	local now = run.d.clock()
	if now < (member.NextDiscovery or 0) then
		return false, "PleaseWait"
	end
	member.NextDiscovery = now + 1
	if not member.Secrets[id] then
		if not run.d.evidence(player, record.Evidence) then
			return false, "DataNotReady"
		end
		member.Secrets[id] = true
	end
	run.inspectionSerial = (run.inspectionSerial or 0) + 1
	member.Focus = nil
	member.Inspection = {
		Id = run.id .. "_read_" .. run.inspectionSerial,
		RecordId = id,
		Title = record.Title,
		Text = record.Text,
		Format = record.Format or "Record",
		Station = "Secret_" .. id,
		ExpiresAt = now + 90,
	}
	if id == "Directive" and Policy.Enabled(run) then
		member.Inspection.Title = "MINISTRY DIRECTIVE / NIGHT " .. run.night
		member.Inspection.Text = run.policy.Text
	elseif id == "RepairLog" and Policy.Enabled(run) then
		member.Inspection.Title = "SHOP SERVICE RECORD"
		member.Inspection.Text = "Repairs returned: "
			.. run.repaired
			.. "\nLogged access violations: "
			.. run.ruleBreaks
			.. "\nUnmatched records: "
			.. run.government.Discrepancies
			.. "\nSupply priority: "
			.. (run.government.Trust >= 2 and "APPROVED FOR NEXT SHIFT" or "STANDARD")
	end
	member.PersonalNotice, member.PersonalNoticeUntil = "Found: " .. member.Inspection.Title, now + 4
	run:_publish()
	return true
end
function Lore.Tick(run, player, member)
	local item = member.Inspection
	if
		item
		and (
			not member.Alive
			or run.phase == "Results"
			or run.event
			or run.d.clock() >= item.ExpiresAt
			or not run.d.near(player, item.Station)
		)
	then
		member.Inspection = nil
		run:_publish()
	end
end
function Lore.Close(run, member, id)
	if member.Inspection and member.Inspection.Id == id then
		member.Inspection = nil
		run:_publish()
	end
	return true
end
return Lore
