-- Pure, server-owned prototype rules. World, profiles and networking are adapters.
local Shift = {}
local Catalog = require(script.Parent.CustomerCatalog)
local Endings = require(script.Parent.EndingRules)
local Puzzles = require(script.Parent.WorkPuzzles)
local Secrets = require(script.Parent.ShopSecrets)
local Director = require(script.Parent.EventDirector)
local Modes = require(script.Parent.ModeRules)
Shift.__index = Shift
local WORK =
	{ Diagnose = "Collect", Collect = "Repair", Repair = "Secure", Install = "Test", Test = "Return" }
local STATIONS = {
	TakeOrder = "Counter",
	Diagnose = "Bench",
	Collect = "Stock",
	Repair = "Bench",
	Install = "Bench",
	Test = "Bench",
	Return = "Counter",
	Restock = "Stock",
	RestorePower = "Fuse",
	Silence = "Phone",
	Answer = "Phone",
	Records = "Records",
	Sit = "Bench",
	DepositPart = "Bench",
	Secure = "Bench",
	PuzzleInput = "Bench",
}
local OPTIONAL =
	{ ToggleDoor = "StaffDoor", TuneRadio = "Radio", InspectRecords = "Records", ToggleLamp = "DeskLamp" }
local BULLETINS = {
	"CITY RADIO: The last tram leaves at six. All night staff must carry identification.",
	"SERVICE BAND: Deliveries to Ward Seven have been redirected. Do not record this message.",
	"DEAD AIR: ...we can see the repair shop...",
}
local OBJECTIVES = {
	Arriving = "A customer is approaching the service window.",
	Waiting = "Go to INTAKE and accept the customer's phone.",
	Diagnose = "Sit at the REPAIR BENCH and diagnose the phone.",
	Collect = "Stand up and collect the marked part from the PARTS ROOM.",
	Repair = "Carry the replacement to the bench, place it down, then sit to fit it.",
	Secure = "Tighten the required highlighted contacts before installing the package.",
	Install = "Install the government software at REPAIR BENCH.",
	Evidence = "Read the recovered message. Your team must choose what to do.",
	Test = "Test the repaired phone at REPAIR BENCH.",
	Return = "Go to INTAKE and return the phone to its customer.",
}

function Shift.new(deps, config)
	return setmetatable({
		d = deps,
		c = config,
		players = {},
		phase = "Waiting",
		serial = 0,
		revision = 0,
		stock = { Battery = 4, Speaker = 4, Keypad = 4 },
		repaired = 0,
		missed = 0,
		revenue = 0,
		suspicion = 0,
		decisions = {},
		nextSettle = 0,
		closing = false,
		night = 1,
		nightsCleared = 0,
	}, Shift)
end

function Shift:Add(player)
	if self.players[player] then
		return
	end
	local late = self.phase == "Night" or self.phase == "Results" or self.night > 1
	self.players[player] = {
		Alive = not late,
		HP = late and 0 or 100,
		Acknowledged = false,
		ClockedIn = false,
		Repairs = 0,
		Actions = 0,
		Spectator = late,
		Kit = {},
		Secrets = {},
	}
	self:_publish()
end

function Shift:_publish()
	self.revision += 1
	if self.d.changed then
		self.d.changed()
	end
end

function Shift:_notice(message)
	self.notice, self.noticeUntil = message, self.d.clock() + 9
	self:_publish()
end

function Shift:_living()
	local list = {}
	for player, member in pairs(self.players) do
		if member.Alive and self.d.present(player) then
			table.insert(list, player)
		end
	end
	return list
end

function Shift:_newOrder(tutorial)
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
	self.order = {
		Id = tostring(self.serial),
		Customer = source.Name,
		Fault = job.Fault,
		Complaint = job.Complaint,
		Line = source.Line,
		Sensitive = source.Evidence ~= nil and not tutorial,
		Evidence = source.Evidence,
		CustomerId = source.Id,
		Device = job.Device,
		Fee = job.Fee,
		Patience = job.Patience,
		Requirement = job.Requirement,
		RequiredContacts = job.Contacts,
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

function Shift:_start(continuing)
	self:_clearParts()
	self.night = continuing and self.night + 1 or 1
	self.nightsCleared = continuing and self.nightsCleared or 0
	self.directorConfig = Modes.Director(self.c.Director, self.d.mode(), self.night)
	self.deck =
		Catalog.Deck(self.d.random or math.random, self.d.mode(), Modes.Customer(self.d.mode(), self.night))
	self.resumeAt = nil
	self.director, self.pendingScare = nil, nil
	self.doorOpen, self.lampOn, self.radioChannel = false, true, 0
	self.answered = continuing and self.answered or 0
	self.optionalCooldowns = {}
	self.id = self.d.id()
	self.phase, self.reason, self.endedAt = "Tutorial", nil, nil
	self.startedAt, self.nightAt, self.eventIndex, self.event = self.d.clock(), nil, 1, nil
	self.serial, self.repaired, self.missed, self.revenue = 0, 0, 0, 0
	self.suspicion = continuing and self.suspicion or 0
	self.order, self.work, self.nextOrder = nil, nil, nil
	self.decisions = continuing and self.decisions or {}
	self.stock = { Battery = 4, Speaker = 4, Keypad = 4 }
	for player, member in pairs(self.players) do
		local alive = not continuing or member.Alive
		member.Alive, member.HP, member.Acknowledged, member.Spectator =
			alive, alive and (continuing and member.HP or 100) or 0, false, not alive
		member.Repairs, member.Actions, member.Settled, member.Replay = 0, 0, not alive, false
		if alive then
			member.Outcome = nil
		end
		if alive then
			member.DeathReason, member.Ending = nil, nil
		end
		member.NextAction = nil
		member.Seated = false
		member.ClockedIn, member.Scare, member.PersonalNotice = false, nil, nil
		member.RadioScared, member.NextScare = false, nil
		member.Kit, member.Secrets, member.Focus = {}, continuing and member.Secrets or {}, nil
		member.NextDiscovery = nil
		self.d.clearGear(player)
		self.d.stand(player)
		if alive then
			self.d.reset(player)
			self.d.health(player, member.HP)
		end
	end
	self:_notice("Night staff: enter through the side door and clock in before starting work.")
	self:_publish()
end

function Shift:_settle(player, member)
	if not member.Outcome or member.Settled then
		return
	end
	if self.d.mode() == "Story" and (member.Outcome == "Died" or self.night >= Modes.StoryNights) then
		member.Ending = member.Ending or Endings.Resolve(self, member)
	end
	local ok = self.d.outcome(player, {
		Id = self.id .. "_" .. tostring(player.UserId),
		Survived = member.Outcome == "Survived",
		Shift = math.min(self.night, 9999),
		CasesSolved = member.Repairs,
		Ending = member.Ending and member.Ending.Id,
	})
	if ok then
		member.Settled = true
		self:_publish()
		self.d.persist(player)
	end
end

function Shift:Finish(reason)
	if self.phase == "Results" or self.phase == "Waiting" then
		return
	end
	self:_clearParts()
	for player in pairs(self.players) do
		self.d.stand(player)
	end
	self.phase, self.reason, self.endedAt = "Results", reason, self.d.clock()
	self.pendingScare = nil
	self.work, self.event, self.order = nil, nil, nil
	if reason == "Dawn" then
		self.nightsCleared += 1
	end
	for player, member in pairs(self.players) do
		if member.Alive and not member.Spectator and reason == "Dawn" then
			member.Outcome = "Survived"
		end
		self:_settle(player, member)
	end
	self:_publish()
end

function Shift:Damage(player, amount, reason)
	local member = self.players[player]
	if not member or not member.Alive or (self.phase ~= "Night" and self.phase ~= "Tutorial") then
		return
	end
	member.HP = math.max(0, member.HP - amount)
	if amount > 0 then
		self:_scare(player, "Visitor")
	end
	if member.HP == 0 then
		self:_recoverPart(player)
		self.d.stand(player)
		member.Alive, member.Outcome, member.DeathReason = false, "Died", reason
		member.Focus = nil
		self.d.clearGear(player)
		if self.work and self.work.Player == player then
			self.work = nil
		end
		self:_settle(player, member)
	end
	self.d.health(player, member.HP)
	if #self:_living() == 0 then
		self:Finish("AllDead")
	else
		self:_publish()
	end
end

function Shift:Remove(player)
	self.d.clearGear(player)
	self:_recoverPart(player)
	self.d.stand(player)
	local member = self.players[player]
	if member then
		self:_settle(player, member)
	end
	self.players[player] = nil
	if self.work and self.work.Player == player then
		self.work = nil
	end
	if self.order then
		self.order.Contributors[player] = nil
	end
	if (self.phase == "Night" or self.phase == "Tutorial") and #self:_living() == 0 then
		self:Finish("Interrupted")
	end
	self:_publish()
end

function Shift:_resolveVote()
	local order = self.order
	if not order or order.Step ~= "Evidence" or order.PausedAt then
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
		self:_notice("Report filed. The customer's name has been added to a government list.")
	elseif choice == "Hide" then
		self.suspicion = math.min(100, self.suspicion + 20)
		self:_notice("The message is hidden. The customer may be safe, but the records no longer match.")
	else
		self.suspicion = math.min(100, self.suspicion + 30)
		self:_notice(
			"Recovered: " .. (order.Evidence and order.Evidence.Discovery or "Ward 7 is still occupied.")
		)
		for _, player in ipairs(living) do
			self.d.evidence(player, order.Evidence and order.Evidence.Id or "prototype_ward7")
		end
	end
	order.Step, order.Votes = "Test", nil
	self:_publish()
end

function Shift:_completeWork(work)
	local order = self.order
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
		local record = { RunId = self.id, OrderId = order.Id, Fault = order.Fault }
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
	end
	if work.Action == "Install" and order.Sensitive then
		order.Step, order.Votes, order.VoteEndsAt = "Evidence", {}, self.d.clock() + self.c.VoteSeconds
		self:_notice("A deleted message appeared during installation. Decide together.")
	else
		order.Step = WORK[work.Action]
	end
end

function Shift:Action(player, action, payload)
	payload = payload or {}
	local member = self.players[player]
	if self.closing or not member or not self.d.present(player) then
		return false, "NotAdmitted"
	end
	if action == "CloseFocus" then
		if member.Focus and payload.FocusId == member.Focus.Id then
			member.Focus = nil
			self:_publish()
		end
		return true
	end
	-- Standing never waits for work, action cooldowns, or profile availability.
	if action == "Stand" then
		self.d.stand(player)
		member.Seated = false
		if self.work and self.work.Player == player and self.work.Station == "Bench" then
			self.work = nil
		end
		self:_publish()
		return true
	end
	if action == "Replay" then
		if
			self.phase ~= "Results"
			or not self.d.sessionReady()
			or (member.Outcome and not member.Settled)
		then
			return false, "NotReady"
		end
		if self:CanContinue() and not member.Alive then
			return false, "ShiftClosed"
		end
		member.Replay = not member.Replay
		self:_publish()
		return true
	end
	if not member.Alive or (self.phase ~= "Tutorial" and self.phase ~= "Night") then
		return false, "ShiftClosed"
	end
	if self.phase == "Night" and self.d.clock() >= self.nightAt + self.c.NightSeconds then
		self:Finish("Dawn")
		return false, "ShiftClosed"
	end
	if not self.d.ready(player) then
		return false, "DataNotReady"
	end
	if OPTIONAL[action] then
		return self:_optional(player, action)
	end
	if action == "OpenClock" then
		if member.ClockedIn then
			return false, "AlreadyClockedIn"
		end
		if not self.d.near(player, "Timeclock") then
			return false, "MoveCloser"
		end
		if not member.Focus then
			self.focusSerial = (self.focusSerial or 0) + 1
			member.Focus = {
				Id = self.id .. "_clock_" .. self.focusSerial,
				Station = "Timeclock",
				EndsAt = self.d.clock() + 30,
			}
			self:_publish()
		end
		return true
	end
	if action == "ClockIn" then
		if not self.d.near(player, "Timeclock") then
			return false, "MoveCloser"
		end
		if not member.ClockedIn then
			if
				not member.Focus
				or payload.FocusId ~= member.Focus.Id
				or self.d.clock() >= member.Focus.EndsAt
			then
				return false, "FocusChanged"
			end
			member.ClockedIn = true
			member.Focus = nil
			self:_publish()
		end
		return true
	end
	if not member.ClockedIn then
		return false, "ClockInFirst"
	end
	if action == "PickupTool" then
		local id = payload.Tool
		if not table.find({ "Tester", "Screwdriver", "Cartridge", "BrassKey" }, id) then
			return false, "InvalidInput"
		end
		if self.d.seated(player) or not self.d.near(player, "Tool_" .. id) then
			return false, "MoveCloser"
		end
		if self.d.hasGear(player, id) then
			return true
		end
		if not self.d.giveGear(player, id) then
			return false, "NotReady"
		end
		member.Kit[id] = true
		self:_notice("Collected " .. id .. ". Keep it in your kit for this shift.")
		return true
	end
	if action == "Discover" then
		local clue = Secrets[payload.Secret]
		if not clue or not self.d.near(player, "Secret_" .. payload.Secret) then
			return false, "MoveCloser"
		end
		if clue.Key and not self.d.hasGear(player, clue.Key) then
			return false, "KeyRequired"
		end
		if self.d.clock() < (member.NextDiscovery or 0) then
			return false, "PleaseWait"
		end
		member.NextDiscovery = self.d.clock() + 1
		if not member.Secrets[payload.Secret] then
			if not self.d.evidence(player, clue.Evidence) then
				return false, "DataNotReady"
			end
			member.Secrets[payload.Secret] = true
		end
		member.PersonalNotice, member.PersonalNoticeUntil =
			clue.Title .. ": " .. clue.Text, self.d.clock() + 18
		self:_publish()
		return true
	end
	if action == "ReadRules" then
		member.Acknowledged = true
		local all = true
		for _, other in ipairs(self:_living()) do
			if not self.players[other].Acknowledged then
				all = false
			end
		end
		if all and not self.order and self.phase == "Tutorial" and self.night == 1 then
			self:_newOrder(true)
		end
		self:_publish()
		return true
	end
	if not member.Acknowledged then
		return false, "ReadRules"
	end
	local order = self.order
	if
		order
		and not order.PausedAt
		and order.ExpiresAt
		and self.d.clock() >= order.ExpiresAt
		and (
			action == "Vote"
			or action == "TakeOrder"
			or action == "Return"
			or action == "Secure"
			or WORK[action]
		)
	then
		return false, "OrderChanged"
	end
	if action == "Vote" then
		if self.event or (order and order.PausedAt) then
			return false, "DisturbanceActive"
		end
		if not order or order.Step ~= "Evidence" or payload.OrderId ~= order.Id then
			return false, "OrderChanged"
		end
		if payload.Choice ~= "Report" and payload.Choice ~= "Hide" and payload.Choice ~= "Investigate" then
			return false, "InvalidChoice"
		end
		if self.d.clock() >= order.VoteEndsAt then
			return false, "VoteClosed"
		end
		order.Votes[player] = payload.Choice
		self:_resolveVote()
		self:_publish()
		return true
	end
	local station = STATIONS[action]
	if action == "PuzzleInput" and self.work then
		station = self.work.Station
	end
	if action == "Collect" then
		if not order or (payload.Part and payload.Part ~= order.Fault) then
			return false, "WrongPart"
		end
		station = "Part_" .. order.Fault
	end
	if not station or not self.d.near(player, station) then
		return false, "MoveCloser"
	end
	if self.d.clock() < (member.NextAction or 0) then
		return false, "PleaseWait"
	end
	member.NextAction = self.d.clock() + (action == "PuzzleInput" and 0.12 or 0.5)
	if action == "PuzzleInput" then
		local work = self.work
		if
			not work
			or not work.Puzzle
			or work.Player ~= player
			or payload.WorkId ~= work.Id
			or payload.OrderId ~= work.OrderId
			or self.d.clock() >= work.EndsAt
		then
			return false, "PuzzleChanged"
		end
		if self.event then
			return false, "DisturbanceActive"
		end
		if work.Station == "Bench" and not self.d.seated(player) then
			return false, "SitFirst"
		end
		local gear = Puzzles.Gear[work.Action]
		if gear and not self.d.hasGear(player, gear) then
			return false, "MissingTool"
		end
		if order and order.ExpiresAt and not order.PausedAt and self.d.clock() >= order.ExpiresAt then
			return false, "OrderChanged"
		end
		local ok, solved, code = Puzzles.Input(work.Puzzle, payload.Move, payload.PuzzleRevision)
		if not ok then
			return false, code
		end
		if solved then
			if work.Action == "Repair" then
				work.Puzzle, work.StartedAt, work.EndsAt =
					nil, self.d.clock(), self.d.clock() + self.c.FittingSeconds
			else
				self.work = nil
				self:_completeWork(work)
			end
		end
		self:_publish()
		return true
	end
	if action == "RestorePower" or action == "Silence" or action == "Answer" or action == "Records" then
		local event = self.event
		local expected = action == "RestorePower" and "Blackout"
			or action == "Records" and "Inspection"
			or "Call"
		if
			not event
			or event.Kind ~= expected
			or payload.EventId ~= event.Id
			or self.d.clock() >= event.EndsAt
		then
			return false, "EventChanged"
		end
		if action == "Answer" then
			self.answered = (self.answered or 0) + 1
			self:_notice("It said your name. You were told not to pick up.")
			self:Damage(player, 40, "Answered the disconnected phone")
		elseif action == "Records" then
			self:_notice("The inspector accepts the repair log and leaves.")
			self.suspicion = math.max(0, self.suspicion - 10)
		else
			self:_notice(
				action == "Silence" and "The line goes quiet." or "Power restored. Something moved outside."
			)
		end
		self:_endDisturbance()
		member.Actions += 1
		self:_publish()
		return true
	end
	if self.event then
		return false, "DisturbanceActive"
	end
	if (action == "Collect" or action == "Restock") and self.d.seated(player) then
		return false, "StandFirst"
	end
	if action == "Sit" then
		if
			not order
			or payload.OrderId ~= order.Id
			or order.Step == "Arriving"
			or order.Step == "Waiting"
			or order.Step == "Return"
		then
			return false, "WrongStep"
		end
		local ok, code = self.d.sit(player)
		if ok and self.d.seated(player) and not member.Seated then
			member.Seated, member.SeatVisit = true, (member.SeatVisit or 0) + 1
		end
		self:_publish()
		return ok, code
	end
	if action == "DepositPart" then
		local carried = member.CarriedPart
		if
			not order
			or payload.OrderId ~= order.Id
			or order.Step ~= "Repair"
			or not carried
			or carried.OrderId ~= order.Id
			or carried.RunId ~= self.id
			or not self.d.hasPart(player, carried)
		then
			return false, "MissingPart"
		end
		self.d.clearPart(player)
		member.CarriedPart, order.PartHolder, order.PartDelivered = nil, nil, true
		order.Contributors[player] = true
		self:_notice("Replacement placed at the bench. Sit down to fit it.")
		return true
	end
	if self.work then
		return false, "WorkInProgress"
	end
	if action == "Secure" then
		if not order or payload.OrderId ~= order.Id or order.Step ~= "Secure" then
			return false, "WrongStep"
		end
		if not self.d.seated(player) then
			return false, "SitFirst"
		end
		if not self.d.hasGear(player, "Screwdriver") then
			return false, "MissingTool"
		end
		if payload.Contact ~= (order.Contacts or 0) + 1 then
			return false, "OrderChanged"
		end
		local required = order.RequiredContacts or self.c.SecureContacts
		order.Contacts = math.min(required, (order.Contacts or 0) + 1)
		order.Contributors[player] = true
		if order.Contacts == required then
			order.Step = "Install"
		end
		self:_publish()
		return true
	end
	if action == "Restock" then
		local fault = order and order.Fault or "Battery"
		if not order then
			for _, candidate in ipairs({ "Speaker", "Keypad" }) do
				if self.stock[candidate] < self.stock[fault] then
					fault = candidate
				end
			end
		end
		if self.stock[fault] >= 8 then
			return false, "StockFull"
		end
		self.work = {
			Action = action,
			StartedAt = self.d.clock(),
			Fault = fault,
			Player = player,
			Station = station,
			EndsAt = self.d.clock() + self.c.WorkSeconds,
		}
	elseif not order or payload.OrderId ~= order.Id then
		return false, "OrderChanged"
	elseif action == "TakeOrder" and order.Step == "Waiting" then
		order.Step = "Diagnose"
		order.Contributors[player] = true
	elseif action == "Return" and order.Step == "Return" then
		self.repaired += 1
		self.revenue += order.Fee or 45
		order.Contributors[player] = true
		for contributor in pairs(order.Contributors) do
			local other = self.players[contributor]
			if other and other.Alive then
				other.Repairs += 1
			end
		end
		self:_notice(order.Customer .. ": " .. order.Line)
		self:_clearParts()
		for participant in pairs(self.players) do
			self.d.stand(participant)
		end
		self.order, self.nextOrder = nil, self.d.clock() + self.c.BetweenCustomers
		if self.phase == "Tutorial" then
			self.phase, self.nightAt = "Night", self.d.clock()
			if self.c.Director.Enabled then
				self.director = Director.new(self.directorConfig, self.d.random or math.random)
			end
			for _, participant in ipairs(self:_living()) do
				if self.players[participant].Acknowledged then
					self.d.tutorial(participant)
				end
			end
			self:_notice("Training complete. Midnight. Keep the shop running until 6 AM.")
		end
	elseif WORK[action] and order.Step == action then
		local gear = Puzzles.Gear[action]
		if gear and not self.d.hasGear(player, gear) then
			return false, "MissingTool"
		end
		if station == "Bench" and not self.d.seated(player) then
			return false, "SitFirst"
		end
		if action == "Repair" and not order.PartDelivered then
			return false, "MissingPart"
		end
		if self.event and self.event.Kind == "Blackout" and (action == "Install" or action == "Test") then
			return false, "NoPower"
		end
		if action == "Collect" and self.stock[order.Fault] <= 0 then
			return false, "OutOfStock"
		end
		if action == "Collect" and member.CarriedPart then
			return false, "AlreadyCarrying"
		end
		self.work = {
			Action = action,
			StartedAt = self.d.clock(),
			Player = player,
			Station = station,
			OrderId = order.Id,
			EndsAt = self.d.clock() + self.c.WorkSeconds,
		}
	else
		return false, "WrongStep"
	end
	if self.work then
		if action == "Collect" then
			local collected = self.work
			self.work = nil
			self:_completeWork(collected)
		else
			self.workSerial = (self.workSerial or 0) + 1
			self.work.Id = self.id .. "_work_" .. self.workSerial
			self.work.Puzzle = Puzzles.New(
				action,
				order and order.Fault,
				order and order.PuzzleSeed or (self.d.random or math.random)(1, 1000000),
				order and order.SequenceLength
			)
			self.work.EndsAt = self.d.clock() + self.c.PuzzleTimeout
		end
	end
	self:_publish()
	return true
end

function Shift:_scare(player, kind, announced)
	local member, now = self.players[player], self.d.clock()
	if
		self.phase ~= "Night"
		or not member
		or not member.Alive
		or not self.d.present(player)
		or (self.c.Director.Enabled and now - self.nightAt < self.c.Director.CalmSeconds)
		or now < (member.NextScare or 0)
	then
		return false
	end
	member.NextScare = now + 20
	self.scareSerial = (self.scareSerial or 0) + 1
	local random = self.d.random or math.random
	member.Scare = {
		Id = self.id .. "_scare_" .. self.scareSerial,
		Kind = kind,
		At = now + 0.25,
		Variant = random(1, 3),
	}
	if self.d.debug and not announced then
		self.d.debug("COMING kind=" .. kind .. " player=" .. player.Name .. " in=0.25s")
	end
	self:_publish()
	return true
end

function Shift:_planScare(kind, delay)
	local eligible = {}
	for _, player in ipairs(self:_living()) do
		if self.d.clock() >= (self.players[player].NextScare or 0) then
			table.insert(eligible, player)
		end
	end
	if #eligible == 0 then
		return
	end
	local player = eligible[(self.d.random or math.random)(1, #eligible)]
	self.pendingScare = { Player = player, Kind = kind, At = self.d.clock() + delay }
	if self.d.debug then
		self.d.debug(string.format("COMING kind=%s player=%s in=%.2fs", kind, player.Name, delay + 0.25))
	end
end

function Shift:_optional(player, action)
	local member, now = self.players[player], self.d.clock()
	if action ~= "ToggleDoor" and not member.ClockedIn then
		return false, "ClockInFirst"
	end
	if not self.d.near(player, OPTIONAL[action]) then
		return false, "MoveCloser"
	end
	self.optionalCooldowns = self.optionalCooldowns or {}
	if now < (self.optionalCooldowns[action] or 0) then
		return false, "PleaseWait"
	end
	self.optionalCooldowns[action] = now + (action == "TuneRadio" and 3 or 1)
	local text
	if action == "ToggleDoor" then
		self.doorOpen = not self.doorOpen
	elseif action == "ToggleLamp" then
		self.lampOn = not self.lampOn
	elseif action == "TuneRadio" then
		self.radioChannel = (self.radioChannel or 0) % #BULLETINS + 1
		text = BULLETINS[self.radioChannel]
		if
			self.radioChannel == 3
			and self.c.Director.Enabled
			and (self.phase ~= "Night" or self.d.clock() - self.nightAt < self.c.Director.CalmSeconds)
		then
			text = "SERVICE BAND: No broadcast scheduled. The frequency is quiet."
		end
		if self.phase == "Night" and self.radioChannel == 3 and not member.RadioScared then
			member.RadioScared = self:_scare(player, "Signal") or false
		end
	elseif action == "InspectRecords" then
		text = string.format(
			"SHIFT LOG: %d repairs returned. %d missed. Suspicion %d%%. Decisions: %s",
			self.repaired,
			self.missed,
			self.suspicion,
			#self.decisions > 0 and table.concat(self.decisions, ", ") or "None"
		)
	end
	if text then
		member.PersonalNotice, member.PersonalNoticeUntil = text, now + 8
	end
	self:_publish()
	return true
end

function Shift:_recoverPart(player)
	local member = self.players[player]
	local record = member and member.CarriedPart
	self.d.clearPart(player)
	if not record then
		return
	end
	member.CarriedPart = nil
	local order = self.order
	if order and record.RunId == self.id and record.OrderId == order.Id and order.PartHolder == player then
		self.stock[record.Fault] = math.min(8, self.stock[record.Fault] + 1)
		order.PartHolder, order.Step = nil, "Collect"
		self:_notice("The carried replacement was returned to its shelf. Collect it again.")
	end
end

function Shift:_clearParts()
	for player in pairs(self.players) do
		self:_recoverPart(player)
	end
	if self.order and self.order.PartDelivered then
		self.stock[self.order.Fault] = math.min(8, self.stock[self.order.Fault] + 1)
		self.order.PartDelivered = false
	end
end

function Shift:_endDisturbance()
	if self.pendingScare and self.d.debug then
		self.d.debug("CANCELLED: disturbance ended before the scare")
	end
	self.pendingScare = nil
	self.event = nil
	self.resumeAt = self.d.clock() + self.c.AfterDisturbanceSeconds
	self:_publish()
end

function Shift:_tickDisturbance(now)
	local elapsed = now - self.nightAt
	if now >= self.nightAt + self.c.NightSeconds then
		self:Finish("Dawn")
		return
	end
	if self.event and now >= self.event.EndsAt then
		local event = self.event
		self:_endDisturbance()
		for _, player in ipairs(event.Minor and {} or self:_living()) do
			local damage = event.Kind == "Visitor" and (self.d.near(player, "Shelter") and 0 or 100)
				or event.Kind == "Inspection" and (self.suspicion >= 50 and 100 or 35)
				or 30
			self:Damage(
				player,
				damage,
				event.Kind == "Visitor" and "The visitor found you outside shelter"
					or "Ignored " .. event.Kind
			)
		end
		self:_notice("The disturbance passes. Service resumes shortly.")
	end
	if self.phase ~= "Night" then
		return
	end
	if self.pendingScare and now >= self.pendingScare.At then
		local cue = self.pendingScare
		self.pendingScare = nil
		local fired = self:_scare(cue.Player, cue.Kind, true)
		if self.d.debug then
			self.d.debug(
				fired and "DISPATCHED: scheduled scare" or "CANCELLED: target unavailable or cooling down"
			)
		end
	end
	if self.resumeAt and now >= self.resumeAt and not self.event then
		local order = self.order
		if order and order.PausedAt then
			local paused = now - order.PausedAt
			if order.ExpiresAt then
				order.ExpiresAt += paused
			end
			if order.VoteEndsAt then
				order.VoteEndsAt += paused
			end
			if order.Step == "Arriving" then
				order.ArrivesAt = now + self.c.ArrivalSeconds
			end
			order.PausedAt = nil
		end
		self.resumeAt = nil
		self:_publish()
	end
	local scheduled = self.c.Events[self.eventIndex]
	if self.director then
		scheduled = self.director:Next(elapsed, self.suspicion, self.event ~= nil or self.resumeAt ~= nil)
	end
	if not self.event and not self.resumeAt and scheduled and elapsed >= scheduled.At then
		self.event = {
			Id = tostring(self.eventIndex),
			Kind = scheduled.Kind,
			Warning = scheduled.Warning,
			EndsAt = now + scheduled.Duration,
			StartedAt = now,
			Minor = scheduled.Minor == true,
		}
		self.eventIndex += 1
		if self.order then
			self.order.PausedAt = now
		end
		self.work = nil
		for player in pairs(self.players) do
			self.d.stand(player)
		end
		self:_notice(scheduled.Warning)
		if scheduled.Scare then
			self:_planScare(scheduled.Scare, scheduled.ScareDelay)
		end
	end
end

function Shift:CanReturn(player)
	local member = self.players[player]
	return (self.phase == "Results" and member ~= nil and (not member.Outcome or member.Settled))
		or (
			self.phase == "Waiting"
			and self.d.sessionState() ~= "WaitingForParty"
			and not self.d.sessionReady()
		)
end

function Shift:CanContinue()
	return self.phase == "Results" and Modes.Continue(self.d.mode(), self.night, self.reason, #self:_living())
end

function Shift:Tick()
	if self.closing then
		return
	end
	local now = self.d.clock()
	for player, member in pairs(self.players) do
		if
			member.Focus
			and (
				now >= member.Focus.EndsAt
				or not member.Alive
				or not self.d.near(player, member.Focus.Station)
			)
		then
			member.Focus = nil
			self:_publish()
		end
		for id in pairs(member.Kit) do
			if not self.d.hasGear(player, id) then
				member.Kit[id] = nil
				self:_publish()
			end
		end
		local seated = self.d.seated(player)
		if
			seated
			and (
				not member.Alive
				or not member.Acknowledged
				or self.event
				or not self.order
				or self.order.Step == "Waiting"
				or self.order.Step == "Arriving"
				or self.order.Step == "Return"
			)
		then
			self.d.stand(player)
			seated = false
		end
		if member.Seated ~= seated then
			member.Seated = seated
			if seated then
				member.SeatVisit = (member.SeatVisit or 0) + 1
			end
			self:_publish()
		end
		if member.CarriedPart and not self.d.hasPart(player, member.CarriedPart) then
			self:_recoverPart(player)
		end
	end
	if self.phase == "Waiting" then
		if self.d.sessionReady() and next(self.players) then
			self.startAfter = self.startAfter or now + 3
			if now >= self.startAfter then
				self:_start()
			end
		else
			self.startAfter = nil
		end
		return
	end
	if self.phase == "Results" then
		local continuing = self:CanContinue()
		local replay = next(self.players) ~= nil and self.d.sessionReady()
		for _, member in pairs(self.players) do
			if
				((not continuing or member.Alive) and not member.Replay)
				or (member.Outcome and not member.Settled)
			then
				replay = false
			end
		end
		if replay then
			self:_start(continuing)
			return
		end
	elseif self.d.sessionState() == "Interrupted" or self.d.sessionState() == "Incomplete" then
		self:Finish("Interrupted")
		return
	end
	if now >= self.nextSettle then
		self.nextSettle = now + 5
		for player, member in pairs(self.players) do
			self:_settle(player, member)
		end
	end
	if self.phase == "Results" then
		return
	end
	-- Resolve hazards before work and customer arrivals on this tick.
	if self.phase == "Night" then
		self:_tickDisturbance(now)
		if self.phase == "Results" then
			return
		end
	end
	if self.phase == "Tutorial" and not self.order then
		local living = self:_living()
		local allRead = #living > 0
		for _, player in ipairs(living) do
			if not self.players[player].Acknowledged then
				allRead = false
			end
		end
		if allRead then
			if self.night == 1 then
				self:_newOrder(true)
			else
				self.phase, self.nightAt, self.nextOrder = "Night", now, now + self.c.BetweenCustomers
				-- Keep ordinary customers before the chapter's evidence phone.
				self.serial = 1
				if self.c.Director.Enabled then
					self.director = Director.new(self.directorConfig, self.d.random or math.random)
				end
				self:_publish()
			end
		end
	end
	if self.work then
		local work = self.work
		local member = self.players[work.Player]
		if
			not member
			or not member.Alive
			or not self.d.ready(work.Player)
			or not self.d.near(work.Player, work.Station)
			or (work.Station == "Bench" and not self.d.seated(work.Player))
			or (Puzzles.Gear[work.Action] and not self.d.hasGear(work.Player, Puzzles.Gear[work.Action]))
			or self.event ~= nil
			or (
				self.event
				and self.event.Kind == "Blackout"
				and (work.Action == "Install" or work.Action == "Test")
			)
		then
			self.work = nil
			self:_notice("Work paused. Check power and stay beside the station until the task finishes.")
		elseif now >= work.EndsAt then
			self.work = nil
			if work.Puzzle then
				self:_notice("Task closed. Use the station to try again.")
			else
				self:_completeWork(work)
			end
			self:_publish()
		end
	end
	local order = self.order
	if order then
		if order.Step == "Arriving" and not order.PausedAt and now >= order.ArrivesAt then
			order.Step = "Waiting"
			order.ExpiresAt = not order.Tutorial and now + order.Patience or nil
			self:_publish()
		elseif order.Step == "Evidence" then
			self:_resolveVote()
		end
		if order.ExpiresAt and not order.PausedAt and now >= order.ExpiresAt then
			self.missed += 1
			self.suspicion = math.min(100, self.suspicion + 12)
			self:_notice(order.Customer .. " left without their repair. Suspicion increased.")
			self:_clearParts()
			for player in pairs(self.players) do
				self.d.stand(player)
			end
			self.order, self.work, self.nextOrder = nil, nil, now + self.c.BetweenCustomers
		end
	elseif
		self.phase == "Night"
		and not self.event
		and not self.resumeAt
		and self.nextOrder
		and now >= self.nextOrder
	then
		self:_newOrder(false)
	end
end

function Shift:Snapshot(player)
	local member = self.players[player]
	local order, event = self.order, self.event
	local elapsed = self.nightAt
			and math.clamp((self.endedAt or self.d.clock()) - self.nightAt, 0, self.c.NightSeconds)
		or 0
	local snapshot = {
		Revision = self.revision,
		RunId = self.id,
		Phase = self.phase,
		Reason = self.reason,
		Mode = self.d.mode(),
		Night = self.night,
		NightsCleared = self.nightsCleared or 0,
		StoryNights = Modes.StoryNights,
		Intro = self.id and Modes.Intro(self.d.mode(), self.night) or nil,
		ContinueRun = self:CanContinue(),
		ClockHour = self.phase == "Tutorial" and 22 or elapsed / self.c.NightSeconds * 6,
		NightEndsAt = self.nightAt and self.nightAt + self.c.NightSeconds,
		NightStartedAt = self.nightAt,
		NightDuration = self.c.NightSeconds,
		TimeFrozenAt = self.endedAt,
		Rules = Modes.Directive(self.c.Rules, self.d.mode(), self.night),
		Tutorial = self.phase == "Tutorial",
		NeedsClockIn = member
			and member.Alive
			and not member.ClockedIn
			and (self.phase == "Tutorial" or self.phase == "Night"),
		DoorOpen = self.doorOpen == true,
		Focus = member and member.Focus and table.clone(member.Focus),
		Kit = member and table.clone(member.Kit) or {},
		SecretsFound = member and (function()
			local n = 0
			for _ in pairs(member.Secrets) do
				n += 1
			end
			return n
		end)() or 0,
		Ending = member and member.Ending and table.clone(member.Ending) or nil,
		Scare = member and member.Scare and table.clone(member.Scare) or nil,
		NeedsRules = member
			and member.Alive
			and member.ClockedIn
			and not member.Acknowledged
			and (self.phase == "Tutorial" or self.phase == "Night"),
		Alive = member and member.Alive or false,
		Seated = member and self.d.seated(player) or false,
		SeatVisit = member and member.SeatVisit or 0,
		CarriedPart = member and member.CarriedPart and member.CarriedPart.Fault or nil,
		ArrivalsPaused = self.event ~= nil or self.resumeAt ~= nil,
		HP = member and member.HP or 0,
		PersonalRepairs = member and member.Repairs or 0,
		Outcome = member and member.Outcome,
		DeathReason = member and member.DeathReason,
		Spectator = member and member.Spectator,
		SaveStatus = member
				and member.Outcome
				and (member.Settled and self.d.saveStatus(player) or "Waiting to record progress")
			or nil,
		Repaired = self.repaired,
		Missed = self.missed,
		Revenue = self.revenue,
		Suspicion = self.suspicion,
		Stock = table.clone(self.stock),
		CanReturn = self:CanReturn(player),
		CanReplay = self.phase == "Results"
			and self.d.sessionReady()
			and (not self:CanContinue() or member and member.Alive == true),
		Roster = {},
		Decisions = table.clone(self.decisions),
		Notice = self.noticeUntil and self.d.clock() < self.noticeUntil and self.notice or nil,
		NoticeUntil = self.noticeUntil,
		Objective = self.phase == "Waiting" and "Waiting for your party and saved data..."
			or "Next customer soon. Tune the radio, read the shift log, or restock in the PARTS ROOM.",
		SessionState = self.d.sessionState(),
		Replay = member and member.Replay or false,
	}
	for other, info in pairs(self.players) do
		table.insert(snapshot.Roster, {
			UserId = other.UserId,
			Name = other.DisplayName,
			Alive = info.Alive,
			HP = info.HP,
			Repairs = info.Repairs,
			Replay = info.Replay,
			Acknowledged = info.Acknowledged,
		})
	end
	table.sort(snapshot.Roster, function(a, b)
		return a.UserId < b.UserId
	end)
	if order then
		snapshot.Order = {
			Id = order.Id,
			Customer = order.Customer,
			Complaint = order.Complaint,
			Device = order.Device,
			Fee = order.Fee,
			PartDelivered = order.PartDelivered == true,
			Contacts = order.Contacts or 0,
			RequiredContacts = order.RequiredContacts or self.c.SecureContacts,
			Requirement = order.Requirement,
			PartCarrier = order.PartHolder and order.PartHolder.DisplayName or nil,
			Paused = order.PausedAt ~= nil,
			PatienceRemaining = order.PausedAt and order.ExpiresAt and math.max(
				0,
				order.ExpiresAt - order.PausedAt
			) or nil,
			Step = order.Step,
			Fault = order.Step ~= "Waiting"
					and order.Step ~= "Arriving"
					and order.Step ~= "Diagnose"
					and order.Fault
				or nil,
			ExpiresAt = order.ExpiresAt,
		}
		snapshot.Objective = OBJECTIVES[order.Step]
		snapshot.Target = (order.Step == "Waiting" or order.Step == "Arriving") and "Counter"
			or order.Step == "Collect" and (self.stock[order.Fault] > 0 and "Part_" .. order.Fault or "Stock")
			or order.Step == "Return" and "Counter"
			or "Bench"
		if order.Step == "Evidence" then
			snapshot.Vote = {
				OrderId = order.Id,
				EndsAt = order.VoteEndsAt,
				Choice = order.Votes[player],
				Message = order.Evidence and order.Evidence.Message
					or "DELETED MESSAGE: 'Ward 7 is not empty.'",
				Report = 0,
				Hide = 0,
				Investigate = 0,
			}
			for _, living in ipairs(self:_living()) do
				local choice = order.Votes[living]
				if choice then
					snapshot.Vote[choice] += 1
				end
			end
		end
	end
	if not order and self.phase == "Tutorial" then
		snapshot.Objective = "Read the directive. Wait for every staff member to acknowledge it."
	end
	if self.work then
		snapshot.Work = {
			Action = self.work.Action,
			Name = self.work.Player.DisplayName,
			UserId = self.work.Player.UserId,
			Station = self.work.Station,
			StartedAt = self.work.StartedAt,
			EndsAt = self.work.EndsAt,
			Id = self.work.Id,
			OrderId = self.work.OrderId,
			Interactive = self.work.Puzzle ~= nil,
			Puzzle = self.work.Player == player and self.work.Puzzle and Puzzles.Snapshot(self.work.Puzzle)
				or nil,
		}
	end
	if event then
		snapshot.Event = table.clone(event)
	end
	if member and order and not self.work and not event then
		local required = Puzzles.Gear[order.Step]
		if required and not self.d.hasGear(player, required) then
			snapshot.RequiredTool = required
			snapshot.Target = "Tool_" .. required
			snapshot.Objective = "Collect your "
				.. required
				.. " before this repair step. Stand up to fetch it."
		end
	end
	if snapshot.NeedsClockIn then
		snapshot.Objective = "Enter through the STAFF DOOR, then use the TIMECLOCK to start your shift."
		snapshot.Target = (self.doorOpen or self.d.near(player, "Timeclock")) and "Timeclock" or "StaffDoor"
	end
	if member and member.PersonalNoticeUntil and self.d.clock() < member.PersonalNoticeUntil then
		snapshot.Notice, snapshot.NoticeUntil = member.PersonalNotice, member.PersonalNoticeUntil
	end
	return snapshot
end

return Shift
