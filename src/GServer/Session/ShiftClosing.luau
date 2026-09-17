-- Dawn closes intake before settling the night. Existing accepted phones can
-- still be repaired, called for pickup and returned within the grace period.
local Methods = {}
function Methods:BeginClosing()
	if self.phase ~= "Night" then
		return
	end
	local now = self.d.clock()
	self.phase, self.closingEndsAt = "Closing", self.nightAt + self.c.NightSeconds + (self.c.ClosingSeconds or 0)
	self.event, self.pendingScare, self.resumeAt = nil, nil, nil
	for _, member in pairs(self.players) do
		member.Scare, member.ScareImpact, member.Outside = nil, nil, nil
	end
	for _, lane in pairs(self.stations) do
		lane.nextOrder = nil
		local order = lane.order
		if order then
			if order.Step == "Waiting" or order.Step == "Arriving" then
				-- Customers who have not handed over a phone leave at closing time.
				lane.order, lane.work = nil, nil
			else
				if order.PausedAt then
					if order.VoteEndsAt then
						order.VoteEndsAt += now - order.PausedAt
					end
					if order.Step == "PickupArriving" then
						order.PickupAt = now + self.c.ArrivalSeconds
					end
					order.PausedAt = nil
				end
				order.ExpiresAt = self.closingEndsAt
			end
		end
	end
	self:_notice("The shop is closing. Finish and return the phones already on the benches.")
	self:CheckClosing()
end
function Methods:CheckClosing()
	if self.phase ~= "Closing" then
		return
	end
	local pending = false
	for _, lane in pairs(self.stations) do
		pending = pending or lane.order ~= nil
	end
	if not pending or self.d.clock() >= self.closingEndsAt then
		if pending then
			for _, lane in pairs(self.stations) do
				if lane.order then
					self.missed += 1
				end
			end
		end
		self:Finish("Dawn")
	end
end
return Methods
