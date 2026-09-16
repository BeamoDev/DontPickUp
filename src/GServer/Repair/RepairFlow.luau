-- Methods operate on the owning shift; no module-global gameplay state.
local Methods = {}
local Stations = require(script.Parent.RepairStations)
local Catalog = require(script.Parent.Parent.Customers.CustomerCatalog)
local Puzzles = require(script.Parent.WorkPuzzles)
local Conversations = require(script.Parent.Parent.Customers.Conversations)
local Modes = require(script.Parent.Parent.Shifts.ModeRules)
local Definitions = require(script.Parent.Parent.Shifts.ShiftDefinitions)
local Pickup = require(script.Parent.Parent.Customers.PickupService)
local WORK = Definitions.WORK
local BENCHES = Definitions.BENCHES
function Methods:_newOrder(tutorial, lane)
	lane = lane or self.stations.Bench
	self.serial += 1
	local index = self.deck and self.deck[(self.serial - 1) % #self.deck + 1]
		or (self.serial - 1) % #self.c.Customers + 1
	local source = self.c.Customers[index]
	-- A story phone appears early each chapter; ordinary jobs surround the clue.
	local storyId = Modes.Customer(self.d.mode(), self.night)
	if not tutorial and self.serial == 3 and storyId then
		for _, customer in ipairs(self.c.Customers) do
			if customer.Id == storyId then
				source = customer
				break
			end
		end
	end
	local job = Catalog.Job(source, self.d.random or math.random, tutorial, self.night)
	lane.order = {
		Id = tostring(self.serial),
		Ticket = Pickup.Issue(self),
		StationId = lane.Id,
		Customer = source.Name,
		Fault = job.Fault,
		Complaint = job.Complaint,
		Line = source.Line,
		Sensitive = source.Evidence ~= nil and not tutorial,
		Evidence = source.Evidence,
		CustomerId = source.Id,
		Kind = source.Kind,
		Device = job.Device,
		Fee = job.Fee,
		Patience = job.Patience,
		Requirement = job.Requirement,
		RequiredContacts = 4,
		SequenceLength = job.SequenceLength,
		Coat = source.Coat,
		Step = "Arriving",
		Contacts = 0,
		Contributors = {},
		ArrivesAt = self.d.clock() + self.c.ArrivalSeconds,
		Tutorial = tutorial,
		PuzzleSeed = tutorial and 1 or (self.d.random or math.random)(1, 1000000),
	}
	self:_publish()
end

function Methods:_resolveVote(lane)
	lane = lane or Stations.Voting(self)
	if not lane then
		return
	end
	local order = lane.order
	if not order or order.Step ~= "Evidence" or order.PausedAt then
		return
	end
	if Stations.Voting(self) ~= lane then
		return
	end
	if not order.VoteEndsAt then
		Stations.BeginVote(self, lane)
		self:_publish()
		return
	end
	local tally, living = { Report = 0, Hide = 0, Investigate = 0 }, self:_living()
	for _, player in ipairs(living) do
		local vote = order.Votes[player]
		if vote then
			tally[vote] += 1
		end
	end
	local choice, highest = "Report", tally.Report
	for _, option in ipairs({ "Hide", "Investigate" }) do
		if tally[option] > highest then
			choice, highest = option, tally[option]
		end
	end
	if highest <= #living / 2 and self.d.clock() < order.VoteEndsAt then
		return
	end
	-- Ties at timeout use Report, then Hide, then Investigate; no votes means Report.
	table.insert(self.decisions, choice)
	if choice == "Report" then
		self.suspicion = math.max(0, self.suspicion - 15)
		self:_notice(
			order.VotePurpose == "Software" and "Team chose to install. Connect the cartridge to finish the job."
				or "Report filed. The customer's name has been added to a government list."
		)
	elseif choice == "Hide" then
		self.suspicion = math.min(100, self.suspicion + 20)
		self:_notice(
			order.VotePurpose == "Software"
					and "Team chose to skip CIVIC WATCH. The Ministry will notice the missing update."
				or "The message is hidden. The customer may be safe, but the records no longer match."
		)
	else
		self.suspicion = math.min(100, self.suspicion + 30)
		self:_notice("Team chose to look closer. Open the customer phone to read the recovered record.")
		for _, player in ipairs(living) do
			if order.Evidence and order.Phone and order.Phone.Discovered then
				self.d.evidence(player, order.Evidence.Id)
			end
		end
	end
	order.Step, order.Votes = "Test", nil
	if order.Phone then
		local phone = order.Phone
		phone.DecisionResolved, phone.RequestSkip = true, false
		if order.VotePurpose == "Software" then
			phone.SkipApproved = choice ~= "Report"
			if choice ~= "Report" then
				self.ruleBreaks = (self.ruleBreaks or 0) + 1
			end
		end
		if choice == "Investigate" or (not phone.Installed and not phone.SkipApproved) then
			phone.Page = choice == "Investigate" and "Archive" or "Program"
			phone.Revision += 1
			order.Step = "Install"
		end
	end
	self.voteOrderId = nil
	local nextVote = Stations.Voting(self)
	if nextVote then
		Stations.BeginVote(self, nextVote)
	end
	self:_publish()
end

function Methods:_completeWork(work, lane)
	local order = lane.order
	if work.Action == "Restock" then
		self.stock[work.Fault] = math.min(8, self.stock[work.Fault] + 2)
		self:_notice("Replacement parts restocked.")
		return
	end
	if not order or order.Id ~= work.OrderId or order.Step ~= work.Action then
		return
	end
	local member = self.players[work.Player]
	if work.Action == "Collect" then
		local record = { RunId = self.id, OrderId = order.Id, Fault = order.Fault, StationId = lane.Id }
		if not self.d.givePart(work.Player, record) then
			self:_notice("Could not hand over the part. Return to its shelf and try again.")
			return
		end
		member.CarriedPart, order.PartHolder = record, work.Player
		self.stock[order.Fault] -= 1
	end
	order.Contributors[work.Player] = true
	member.Actions += 1
	if work.Action == "Repair" then
		order.PartDelivered = false
	elseif work.Action == "Test" then
		order.ExpiresAt = nil -- Finished phones wait safely for their collection call.
		Stations.Stand(self, lane)
		self:_notice("Phone ready! Dial ticket " .. order.Ticket .. " on the FAX PHONE.")
	elseif work.Action == "Secure" then
		order.Contacts = 4
	end
	if
		work.Action == "Install"
		and order.Phone
		and (order.Phone.RequestSkip or (order.Phone.Discovered and not order.Phone.DecisionResolved))
	then
		order.VotePurpose = order.Phone.RequestSkip and "Software" or "Evidence"
		local activeVote = Stations.Voting(self)
		order.Step, order.Votes, order.VoteEndsAt = "Evidence", {}, nil
		if not activeVote then
			Stations.BeginVote(self, lane)
		end
		self:_converse(Conversations.Phone(work.Player))
		self:_notice(
			order.VotePurpose == "Software" and "Skip the government program? Decide together."
				or "A private message was opened. Decide together."
		)
	else
		order.Step = WORK[work.Action]
	end
end

function Methods:_recoverPart(player)
	local member = self.players[player]
	local record = member and member.CarriedPart
	self.d.clearPart(player)
	if not record then
		return
	end
	member.CarriedPart = nil
	local lane = Stations.ForOrder(self, record.OrderId)
	local order = lane and lane.order
	if order and record.RunId == self.id and record.OrderId == order.Id and order.PartHolder == player then
		self.stock[record.Fault] = math.min(8, self.stock[record.Fault] + 1)
		order.PartHolder, order.Step = nil, "Collect"
		self:_notice("The carried replacement was returned to its shelf. Collect it again.")
	end
end

function Methods:_clearParts(onlyLane)
	for player, member in pairs(self.players) do
		if
			not onlyLane
			or member.CarriedPart and onlyLane.order and member.CarriedPart.OrderId == onlyLane.order.Id
		then
			self:_recoverPart(player)
		end
	end
	for _, lane in pairs(self.stations) do
		if (not onlyLane or onlyLane == lane) and lane.order and lane.order.PartDelivered then
			self.stock[lane.order.Fault] = math.min(8, self.stock[lane.order.Fault] + 1)
			lane.order.PartDelivered = false
		end
	end
end

function Methods:_tickRepair(lane, now)
	if lane.work then
		local work = lane.work
		local member = self.players[work.Player]
		if
			not member
			or not member.Alive
			or not self.d.ready(work.Player)
			or not self.d.near(work.Player, work.Station)
			or (BENCHES[work.Station] and not self.d.seated(work.Player, work.Station))
			or (Puzzles.Gear[work.Action] and not self.d.hasGear(work.Player, Puzzles.Gear[work.Action]))
			or self.event ~= nil
			or (self.event and self.event.Kind == "Blackout" and (work.Action == "Install" or work.Action == "Test"))
		then
			lane.work = nil
			if member then
				member.PersonalNotice, member.PersonalNoticeUntil =
					"Task stopped. Return to your station to try again.", now + 5
			end
			self:_publish()
		elseif now >= work.EndsAt then
			lane.work = nil
			if work.Puzzle then
				self:_notice("Task closed. Use the station to try again.")
			else
				self:_completeWork(work, lane)
			end
			self:_publish()
		end
	end
	local order = lane.order
	if order then
		if order.Step == "Arriving" and not order.PausedAt and now >= order.ArrivesAt then
			order.Step = "Waiting"
			self:_say(order.Customer, order.Complaint)
			order.ExpiresAt = not order.Tutorial and now + order.Patience or nil
			self:_publish()
		elseif order.Step == "PickupArriving" and not order.PausedAt and now >= order.PickupAt then
			order.Step = "Return"
			self:_notice(order.Customer .. " is back. Return phone " .. order.Ticket .. " at the counter.")
			self:_publish()
		elseif order.Step == "Evidence" then
			self:_resolveVote(lane)
		end
		if
			order.ExpiresAt
			and not order.PausedAt
			and now >= order.ExpiresAt
			and not (order.Step == "Evidence" and not order.VoteEndsAt)
		then
			self.missed += 1
			self.suspicion = math.min(100, self.suspicion + 12)
			self:_notice(order.Customer .. " left without their repair. Suspicion increased.")
			self:_clearParts(lane)
			Stations.Stand(self, lane)
			lane.order, lane.work, lane.nextOrder = nil, nil, now + self.c.BetweenCustomers
		end
	elseif
		self.phase == "Night"
		and not self.event
		and not self.resumeAt
		and lane.nextOrder
		and now >= lane.nextOrder
	then
		self:_newOrder(false, lane)
	end
end

return Methods
