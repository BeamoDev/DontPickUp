local Records = require(script.Parent.ShopSecrets)
local Lore = {}
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
	member.PersonalNotice, member.PersonalNoticeUntil = "Found: " .. record.Title, now + 4
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
