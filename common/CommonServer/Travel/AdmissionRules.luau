-- Maintained in common/CommonServer/Travel/AdmissionRules.luau. Deploy with tools/SyncCommon.ps1.
local Rules = {}

function Rules.CanClaim(ticket, context)
	if type(ticket) == "table" and ticket.Mode ~= nil and ticket.Mode ~= "Story" and ticket.Mode ~= "Endless" then
		return false, "InvalidMode"
	end
	if
		type(ticket) ~= "table"
		or ticket.Version ~= 1
		or type(ticket.Expires) ~= "number"
		or ticket.Expires ~= ticket.Expires
		or ticket.Expires <= context.Now
		or type(ticket.Members) ~= "table"
	then
		return false, "Expired"
	end
	if
		context.SourcePlaceId ~= ticket.LobbyPlaceId
		or context.SourceGameId ~= context.GameId
		or ticket.GamePlaceId ~= context.PlaceId
		or ticket.PrivateServerId ~= context.PrivateServerId
		or context.PrivateServerId == ""
		or context.PrivateServerOwnerId ~= 0
	then
		return false, "WrongDestination"
	end
	local member = ticket.Members[tostring(context.UserId)]
	local count = 0
	for _, entry in pairs(ticket.Members) do
		if type(entry) ~= "table" then
			return false, "InvalidRoster"
		end
		count += 1
	end
	if count < 1 or count > 4 then
		return false, "InvalidRoster"
	end
	local data = ticket.GameData
	if
		data ~= nil
		and (
			type(data) ~= "table"
			or data.Version ~= 1
			or data.Mode ~= ticket.Mode
			or data.StartNight ~= 1
			or data.PartySize ~= count
		)
	then
		return false, "InvalidGameData"
	end
	if type(member) ~= "table" or member.Revoked then
		return false, "NotInvited"
	end
	if ticket.JobId and ticket.JobId ~= context.JobId then
		return false, "PartyServerMismatch"
	end
	if member.ClaimedJob and member.ClaimedJob ~= context.JobId then
		return false, "AlreadyClaimed"
	end
	return true
end

return Rules
