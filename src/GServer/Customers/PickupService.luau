-- Customer collection is independent of the disconnected shop-phone hazard.
local Pickup = {}
local Stations = require(script.Parent.Parent.Repair.RepairStations)
local Engagement = require(script.Parent.Parent.Services.EngagementService)

function Pickup.Issue(run)
	-- Server-lifetime sequence survives new nights/runs. Never collide with an active ticket.
	for _ = 1, 900000 do
		run.ticketSerial = (run.ticketSerial or 0) % 900000 + 1
		local ticket = tostring(99999 + run.ticketSerial)
		local used = false
		for _, lane in pairs(run.stations) do
			used = used or (lane.order ~= nil and lane.order.Ticket == ticket)
		end
		if not used then
			return ticket
		end
	end
	error("No customer tickets available")
end

function Pickup.Valid(run, player)
	local member = run.players[player]
	return member
		and member.Alive
		and member.ClockedIn
		and member.Acknowledged
		and (run.phase == "Tutorial" or run.phase == "Night")
		and not run.event
		and not run.d.seated(player)
		and run.d.near(player, "Fax")
end

function Pickup.Open(run, player)
	if not Pickup.Valid(run, player) then
		return false, "MoveCloser"
	end
	local member = run.players[player]
	if not member.Fax or run.d.clock() >= member.Fax.EndsAt then
		run.faxSerial = (run.faxSerial or 0) + 1
		member.Fax = { Id = run.id .. "_fax_" .. run.faxSerial, EndsAt = run.d.clock() + 90 }
	end
	member.Inspection, member.Focus = nil, nil
	run:_publish()
	return true
end

function Pickup.Dial(run, player, payload)
	local member, now = run.players[player], run.d.clock()
	if not Pickup.Valid(run, player) then
		return false, "MoveCloser"
	end
	if not member.Fax or member.Fax.Id ~= payload.FaxId or now >= member.Fax.EndsAt then
		return false, "FaxClosed"
	end
	if type(payload.Ticket) ~= "string" or not payload.Ticket:match("^%d%d%d%d%d%d$") then
		return false, "InvalidTicket"
	end
	for _, lane in pairs(run.stations) do
		local order = lane.order
		if order and order.Ticket == payload.Ticket then
			if order.Step == "PickupArriving" or order.Step == "Return" then
				member.Fax.Message = "Already called. "
					.. order.Customer
					.. " is "
					.. (order.Step == "Return" and "at the counter." or "on the way.")
				run:_publish()
				return true
			end
			if order.Step ~= "ReadyForPickup" or order.PausedAt then
				return false, "PhoneNotReady"
			end
			order.Step, order.PickupAt = "PickupArriving", now + run.c.ArrivalSeconds
			Engagement.Add(member, "FaxCalls")
			member.Fax.Message = "Called " .. order.Customer .. ". They are on the way!"
			run:_say(order.Customer, "My phone is ready? Thanks! I'll come pick it up.")
			run:_publish()
			return true
		end
	end
	return false, "TicketNotFound"
end

function Pickup.Tick(run, player, member)
	if member.Fax and (not Pickup.Valid(run, player) or run.d.clock() >= member.Fax.EndsAt) then
		member.Fax = nil
		run:_publish()
	end
end

function Pickup.Snapshot(run, member)
	if not member or not member.Fax then
		return nil
	end
	local result = table.clone(member.Fax)
	result.Tickets = {}
	for _, id in ipairs(Stations.Ids) do
		local order = run.stations[id].order
		if order and order.Step ~= "Arriving" and order.Step ~= "Waiting" then
			table.insert(result.Tickets, { Ticket = order.Ticket, Customer = order.Customer, Step = order.Step })
		end
	end
	return result
end

return Pickup
