local Rules = {}

function Rules.CanClaim(ticket, context)
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
