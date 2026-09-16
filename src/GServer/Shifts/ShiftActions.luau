-- Methods operate on the owning shift; no module-global gameplay state.
local Methods = {}
local Stations = require(script.Parent.Parent.Repair.RepairStations)
local Puzzles = require(script.Parent.Parent.Repair.WorkPuzzles)
local Lore = require(script.Parent.Parent.Lore.LoreService)
local Conversations = require(script.Parent.Parent.Customers.Conversations)
local Director = require(script.Parent.Parent.Anomalies.EventDirector)
local Definitions = require(script.Parent.Parent.Shifts.ShiftDefinitions)
local WORK = Definitions.WORK
local BENCHES = Definitions.BENCHES
local STATIONS = Definitions.STATIONS
local OPTIONAL = Definitions.OPTIONAL
local BULLETINS = Definitions.BULLETINS
function Methods:Action(player, action, payload)
	payload = payload or {}
	local member = self.players[player]
	local lane = Stations.ForPlayer(self, player)
	if self.closing or not member or not self.d.present(player) then
		return false, "NotAdmitted"
	end
	if action == "CloseInspection" then
		return Lore.Close(self, member, payload.InspectionId)
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
		if lane.work and lane.work.Player == player and BENCHES[lane.work.Station] then
			lane.work = nil
		end
		self:_publish()
		return true
	end
	if action == "Replay" then
		if self.phase ~= "Results" or not self.d.sessionReady() or (member.Outcome and not member.Settled) then
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
	if action == "SelectStation" then
		if not member.ClockedIn or not member.Acknowledged or self.event then
			return false, "NotReady"
		end
		return Stations.Select(self, player, payload.Station)
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
			if not member.Focus or payload.FocusId ~= member.Focus.Id or self.d.clock() >= member.Focus.EndsAt then
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
		local station = id == "BrassKey" and "Tool_BrassKey" or "Tools"
		if self.d.seated(player) or not self.d.near(player, station) then
			return false, "MoveCloser"
		end
		local gear = id == "BrassKey" and { "BrassKey" } or { "Tester", "Screwdriver", "Cartridge" }
		local changed = false
		for _, item in ipairs(gear) do
			if not self.d.hasGear(player, item) then
				if not self.d.giveGear(player, item) then
					if changed then
						self:_publish()
					end
					return false, "NotReady"
				end
				member.Kit[item] = true
				changed = true
			end
		end
		if changed then
			self:_notice(id == "BrassKey" and "Collected BrassKey." or "Repair kit collected. Keep it for this shift.")
		end
		return true
	end
	if action == "Discover" then
		return Lore.Open(self, player, payload.Secret)
	end
	if action == "ReadRules" then
		member.Acknowledged = true
		local all = true
		for _, other in ipairs(self:_living()) do
			if not self.players[other].Acknowledged then
				all = false
			end
		end
		if all and not lane.order and self.phase == "Tutorial" and self.night == 1 then
			self:_newOrder(true)
		end
		self:_publish()
		return true
	end
	if not member.Acknowledged then
		return false, "ReadRules"
	end
	if action == "Vote" then
		lane = Stations.ForOrder(self, payload.OrderId) or lane
	end
	local order = lane.order
	if
		order
		and not order.PausedAt
		and order.ExpiresAt
		and self.d.clock() >= order.ExpiresAt
		and (action == "Vote" or action == "TakeOrder" or action == "Return" or action == "Secure" or WORK[action])
	then
		return false, "OrderChanged"
	end
	if action == "Vote" then
		lane = Stations.ForOrder(self, payload.OrderId) or lane
		order = lane.order
		if self.event or (order and order.PausedAt) then
			return false, "DisturbanceActive"
		end
		if not order or order.Step ~= "Evidence" or payload.OrderId ~= order.Id then
			return false, "OrderChanged"
		end
		if payload.Choice ~= "Report" and payload.Choice ~= "Hide" and payload.Choice ~= "Investigate" then
			return false, "InvalidChoice"
		end
		if Stations.Voting(self) ~= lane or not order.VoteEndsAt or self.d.clock() >= order.VoteEndsAt then
			return false, "VoteClosed"
		end
		order.Votes[player] = payload.Choice
		self:_resolveVote(lane)
		self:_publish()
		return true
	end
	local station = STATIONS[action]
	if station == "Bench" then
		station = lane.Id
	end
	if action == "PuzzleInput" and lane.work then
		station = lane.work.Station
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
		local work = lane.work
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
		if BENCHES[work.Station] and not self.d.seated(player, work.Station) then
			return false, "SitFirst"
		end
		local gear = Puzzles.Gear[work.Action]
		if gear and not self.d.hasGear(player, gear) then
			return false, "MissingTool"
		end
		if order and order.ExpiresAt and not order.PausedAt and self.d.clock() >= order.ExpiresAt then
			return false, "OrderChanged"
		end
		local ok, solved, code = Puzzles.Input(work.Puzzle, payload.Move, payload.PuzzleRevision, self.d.clock())
		if not ok then
			return false, code
		end
		if work.Action == "Secure" and order and work.Puzzle.Kind == "Screws" then
			order.Contacts = work.Puzzle.Progress
		end
		if solved then
			if work.Action == "Repair" then
				work.Puzzle, work.StartedAt, work.EndsAt = nil, self.d.clock(), self.d.clock() + self.c.FittingSeconds
			else
				lane.work = nil
				self:_completeWork(work, lane)
			end
		end
		self:_publish()
		return true
	end
	if action == "RestorePower" or action == "Silence" or action == "Answer" or action == "Records" then
		local event = self.event
		local expected = action == "RestorePower" and "Blackout" or action == "Records" and "Inspection" or "Call"
		if not event or event.Kind ~= expected or payload.EventId ~= event.Id or self.d.clock() >= event.EndsAt then
			return false, "EventChanged"
		end
		if action == "Answer" then
			self.answered = (self.answered or 0) + 1
			self:_say("The disconnected line", "We know you are still there. Do not turn around.")
			self:_notice("It said your name. You were told not to pick up.")
			self:Damage(player, 40, "Answered the disconnected phone")
		elseif action == "Records" then
			self:_say("Inspector", "Your records are in order. Keep working. We will be back.")
			self:_notice("The inspector accepts the repair log and leaves.")
			self.suspicion = math.max(0, self.suspicion - 10)
		else
			self:_notice(action == "Silence" and "The line goes quiet." or "Power restored. Something moved outside.")
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
		local ok, code = self.d.sit(player, station)
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
		for coworker, info in pairs(self.players) do
			if coworker ~= player and info.Alive and self.d.seated(coworker, station) then
				self:_converse(Conversations.Handoff(player, coworker))
				break
			end
		end
		return true
	end
	if lane.work then
		return false, "WorkInProgress"
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
		lane.work = {
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
		self:_converse(Conversations.Intake(order, player))
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
		self:_converse(Conversations.Return(order, player))
		self:_clearParts(lane)
		Stations.Stand(self, lane)
		lane.order, lane.nextOrder = nil, self.d.clock() + self.c.BetweenCustomers
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
		if BENCHES[station] and not self.d.seated(player, station) then
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
		if action == "Secure" then
			order.Contacts = 0
		end
		lane.work = {
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
	if lane.work then
		if action == "Collect" then
			local collected = lane.work
			lane.work = nil
			self:_completeWork(collected, lane)
		else
			self.workSerial = (self.workSerial or 0) + 1
			lane.work.Id = self.id .. "_work_" .. self.workSerial
			lane.work.Puzzle = Puzzles.New(
				action,
				order and order.Fault,
				order and order.PuzzleSeed or (self.d.random or math.random)(1, 1000000),
				order and order.SequenceLength,
				self.d.clock(),
				not order or (not order.Tutorial and self.night > 1)
			)
			lane.work.EndsAt = self.d.clock() + self.c.PuzzleTimeout
		end
	end
	self:_publish()
	return true
end

function Methods:_optional(player, action)
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
	if text and action == "TuneRadio" then
		self:_say("Shop radio", text)
	elseif text then
		member.PersonalNotice, member.PersonalNoticeUntil = text, now + 8
	end
	self:_publish()
	return true
end

return Methods
