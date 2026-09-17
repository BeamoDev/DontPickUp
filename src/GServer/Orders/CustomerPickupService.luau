-- Customer collection is independent of the disconnected shop-phone hazard.
local Pickup = {}
local Stations = require(script.Parent.Parent.Repair.RepairStations)
local Policy = require(script.Parent.Parent.Story.GovernmentService)
local Records = require(script.Parent.Parent.Story.DeviceRecords)
local Engagement = require(script.Parent.Parent.Session.EmployeeService)

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
		and (run.phase == "Tutorial" or run.phase == "Night" or run.phase == "Closing")
		and not Policy.BlocksWork(run)
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
				member.Fax.CalledTicket, member.Fax.CallSerial = payload.Ticket, (member.Fax.CallSerial or 0) + 1
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
			member.Fax.CalledTicket, member.Fax.CallSerial = payload.Ticket, (member.Fax.CallSerial or 0) + 1
			Engagement.Add(member, "FaxCalls")
			member.Fax.Message = "Called " .. order.Customer .. ". They are on the way!"
			run:_say(order.Customer, "My phone is ready? Thanks! I'll come pick it up.", order.AppearanceId)
			run:_publish()
			return true
		end
	end
	if Policy.Enabled(run) then
		for _, lane in pairs(run.stations) do
			local p = lane.order and lane.order.Phone
			if p and p.Direction then
				local calls, violations = p.Calls, p.Violations
				local reply = Records.Dial(p, payload.Ticket)
				if reply then
					local newCalls, breaks = p.Calls - calls, p.Violations - violations
					run.phoneCalls, run.ruleBreaks = run.phoneCalls + newCalls, run.ruleBreaks + breaks
					run.suspicion = math.min(100, run.suspicion + breaks * 2)
					Engagement.Add(member, "Calls", newCalls)
					Engagement.Add(member, "RuleBreaks", breaks)
					member.Fax.CalledTicket, member.Fax.CallSerial = payload.Ticket, (member.Fax.CallSerial or 0) + 1
					member.Fax.Message = "CONNECTED / PRIVATE LINE"
					run.privateSerial = (run.privateSerial or 0) + 1
					member.PrivateDialogue = {
						Id = run.id .. "_private_" .. run.privateSerial,
						Speaker = "Telephone",
						Text = reply,
						StartedAt = now,
						ExpiresAt = now + 12,
					}
					run:_publish()
					return true
				end
			end
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
