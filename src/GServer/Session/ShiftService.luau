local Stats = require(script.Parent.ShiftStats)
-- Shift lifecycle and scheduling. Repair, staff actions, threats and snapshots are separate method modules.
local Shift = {}
Shift.__index = Shift
local Stations = require(script.Parent.Parent.Repair.RepairStations)
local Policy = require(script.Parent.Parent.Story.GovernmentService)
local Stories = require(script.Parent.Parent.Story.CustomerStories)
local Pickup = require(script.Parent.Parent.Orders.CustomerPickupService)
local Catalog = require(script.Parent.Parent.Customers.CustomerCatalog)
local Endings = require(script.Parent.Parent.Story.EndingRules)
local Lore = require(script.Parent.Parent.Story.LoreService)
local Dialogue = require(script.Parent.Parent.Story.DialogueService)
local Engagement = require(script.Parent.EmployeeService)
local Director = require(script.Parent.Parent.Horror.EventDirector)
local Modes = require(script.Parent.ModeRules)
function Shift.new(deps, config)
	return setmetatable({
		d = deps,
		c = config,
		players = {},
		stations = Stations.New(),
		dialogueChannel = Dialogue.new(),
		phase = "Waiting",
		serial = 0,
		revision = 0,
		stock = { Battery = 4, Speaker = 4, Keypad = 4 },
		repaired = 0,
		missed = 0,
		revenue = 0,
		suspicion = 0,
		decisions = {},
		employeeReports = {},
		awards = {},
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
	local late = self.phase == "Night" or self.phase == "Closing" or self.phase == "Results" or self.night > 1
	self.players[player] = {
		Alive = not late,
		StationId = "Bench",
		HP = late and 0 or 100,
		Acknowledged = false,
		ClockedIn = false,
		Repairs = 0,
		Actions = 0,
		Spectator = late,
		Kit = {},
		Secrets = {},
	}
	Engagement.ResetMember(self.players[player], false)
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

function Shift:_converse(lines)
	self.dialogueChannel:Start(self.id, lines, self.d.clock())
	self.dialogue = self.dialogueChannel.Current
	self:_publish()
end

function Shift:_say(speaker, line, appearanceId, userId)
	self:_converse({ { Speaker = speaker, Text = line, AppearanceId = appearanceId, UserId = userId } })
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

function Shift:_start(continuing)
	if continuing then
		self.employeeReports = Engagement.BuildReports(self)
	else
		self.employeeReports = {}
	end
	self.awards = {}
	self.dialogue = nil
	self.dialogueChannel:Clear()
	self:_clearParts()
	self.night = continuing and self.night + 1 or 1
	self.nightsCleared = continuing and self.nightsCleared or 0
	self.directorConfig = Modes.Director(self.c.Director, self.d.mode(), self.night)
	self.deck = Catalog.Deck(self.d.random or math.random, self.d.mode(), Modes.Customer(self.d.mode(), self.night))
	self.resumeAt = nil
	self.closingEndsAt = nil
	self.director, self.pendingScare = nil, nil
	self.nextOutsideCheck = nil
	self.doorOpen, self.lampOn, self.radioChannel = false, true, 0
	self.answered = continuing and self.answered or 0
	self.phoneReads, self.phoneCalls, self.ruleBreaks = 0, 0, 0
	self.optionalCooldowns = {}
	self.id = self.d.id()
	self.phase, self.reason, self.endedAt = "Tutorial", nil, nil
	self.startedAt, self.nightAt, self.eventIndex, self.event = self.d.clock(), nil, 1, nil
	self.serial, self.repaired, self.missed, self.revenue = 0, 0, 0, 0
	self.anomaliesReported = 0
	self.suspicion = continuing and self.suspicion or 0
	self.stations = Stations.New()
	self.voteOrderId = nil
	self.decisions = continuing and self.decisions or {}
	self.stock = { Battery = 4, Speaker = 4, Keypad = 4 }
	Policy.Start(self, continuing)
	Stories.Start(self, continuing)
	for player, member in pairs(self.players) do
		Stats.Reset(member, continuing)
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
		member.ScareImpact, member.Outside, member.Injury = nil, nil, nil
		member.Kit, member.Secrets, member.Focus = {}, continuing and member.Secrets or {}, nil
		member.NextDiscovery, member.Inspection, member.StationId = nil, nil, "Bench"
		member.Fax, member.PrivateDialogue = nil, nil
		Engagement.ResetMember(member, continuing)
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
	self.event = nil
	for _, lane in pairs(self.stations) do
		lane.work, lane.order, lane.nextOrder = nil, nil, nil
	end
	if reason == "Dawn" then
		self.nightsCleared += 1
	end
	for player, member in pairs(self.players) do
		Stats.Stop(member, self.endedAt)
		member.ScareImpact, member.Outside = nil, nil
		if member.Alive and not member.Spectator and reason == "Dawn" then
			member.Outcome = "Survived"
			Stats.Complete(member, self.nightsCleared, self.endedAt, self.repaired, self.anomaliesReported)
		end
	end
	-- Freeze every employee before settlement can publish or yield.
	for player, member in pairs(self.players) do
		self:_settle(player, member)
	end
	self.employeeReports = Engagement.BuildReports(self)
	self.awards = Engagement.Awards(self.players)
	for player, member in pairs(self.players) do
		for _, award in ipairs(self.awards) do
			if award.UserId == player.UserId then
				Engagement.Unlock(member, "Stamps", award.Title)
			end
		end
	end
	self:_publish()
end

function Shift:Damage(player, amount, reason, fromScare)
	local member = self.players[player]
	if
		not member
		or not member.Alive
		or (self.phase ~= "Night" and self.phase ~= "Tutorial" and self.phase ~= "Closing")
	then
		return
	end
	if amount > 0 then
		if not fromScare then
			self:_scare(player, "Visitor", false, { Damage = amount, Reason = reason, Applied = true })
		end
		member.Focus = nil
		member.Fax, member.PrivateDialogue = nil, nil
		self.d.stand(player)
		Stations.CancelPlayer(self, player)
		member.Injury = { Damage = math.min(amount, member.HP), Reason = reason, ExpiresAt = self.d.clock() + 8 }
	end
	member.HP = math.max(0, member.HP - amount)
	if member.HP == 0 then
		self:_recoverPart(player)
		self.d.stand(player)
		member.Alive, member.Outcome, member.DeathReason = false, "Died", reason
		Stats.Freeze(member, self.nightsCleared, self.d.clock())
		member.Focus = nil
		member.Fax, member.PrivateDialogue = nil, nil
		member.ScareImpact, member.Outside = nil, nil
		self.d.clearGear(player)
		Stations.CancelPlayer(self, player)
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
	Stations.CancelPlayer(self, player)
	for _, lane in pairs(self.stations) do
		if lane.order then
			lane.order.Contributors[player] = nil
		end
	end
	if (self.phase == "Night" or self.phase == "Tutorial" or self.phase == "Closing") and #self:_living() == 0 then
		self:Finish("Interrupted")
	end
	self:_publish()
end

function Shift:CanReturn(player)
	local member = self.players[player]
	return (member ~= nil and member.Outcome == "Died" and member.Settled == true)
		or (self.phase == "Results" and member ~= nil and (not member.Outcome or member.Settled))
		or (self.phase == "Waiting" and self.d.sessionState() ~= "WaitingForParty" and not self.d.sessionReady())
end

function Shift:CanContinue()
	return self.phase == "Results" and Modes.Continue(self.d.mode(), self.night, self.reason, #self:_living())
end

function Shift:Tick()
	if self.closing then
		return
	end
	local now = self.d.clock()
	if self.dialogueChannel:Tick(now) then
		self.dialogue = self.dialogueChannel.Current
		if self.dialogue then
			self:_publish()
		end
	end
	for player, member in pairs(self.players) do
		if member.PrivateDialogue and now >= member.PrivateDialogue.ExpiresAt then
			member.PrivateDialogue = nil
			self:_publish()
		end
		Lore.Tick(self, player, member)
		Pickup.Tick(self, player, member)
		if member.SignalUntil and now >= member.SignalUntil then
			member.Signal, member.SignalUntil = nil, nil
			self:_publish()
		end
		local lane = Stations.ForPlayer(self, player)
		if
			member.Focus
			and (now >= member.Focus.EndsAt or not member.Alive or not self.d.near(player, member.Focus.Station))
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
				or Policy.BlocksWork(self)
				or not lane.order
				or lane.order.Step == "Waiting"
				or lane.order.Step == "Arriving"
				or lane.order.Step == "Return"
				or lane.order.Step == "ReadyForPickup"
				or lane.order.Step == "PickupArriving"
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
			if ((not continuing or member.Alive) and not member.Replay) or (member.Outcome and not member.Settled) then
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
	if self.phase == "Night" and now >= self.nightAt + self.c.NightSeconds then
		self:BeginClosing()
	end
	self:CheckClosing()
	if self.phase == "Results" then
		return
	end
	if self.phase == "Night" then
		self:_tickScareImpacts(now)
		if self.phase == "Results" then
			return
		end
		self:_tickOutside(now)
		self:_tickDisturbance(now)
		if self.phase == "Results" then
			return
		end
	end
	if self.phase == "Tutorial" and not self.stations.Bench.order then
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
				self.phase, self.nightAt, self.stations.Bench.nextOrder = "Night", now, now + Policy.Gap(self)
				-- Keep ordinary customers before the chapter's evidence phone.
				self.serial = 1
				if self.c.Director.Enabled then
					self.director = Director.new(self.directorConfig, self.d.random or math.random)
				end
				self:_publish()
			end
		end
	end
	if Policy.Enabled(self) and self.phase == "Night" and #self:_living() > 1 then
		local second = self.stations.Bench2
		if not second.order and not second.nextOrder then
			second.nextOrder = now + Policy.Gap(self)
		end
	end
	for _, id in ipairs(Stations.Ids) do
		self:_tickRepair(self.stations[id], now)
	end
	local voting = Stations.Voting(self)
	if voting and not voting.order.VoteEndsAt then
		self:_resolveVote(voting)
	end
	self:CheckClosing()
end

for name, method in pairs(require(script.Parent.ShiftClosing)) do
	assert(Shift[name] == nil, "Duplicate shift method: " .. name)
	Shift[name] = method
end

for name, method in pairs(require(script.Parent.Parent.Orders.OrderService)) do
	assert(Shift[name] == nil, "Duplicate shift method: " .. name)
	Shift[name] = method
end
for name, method in pairs(require(script.Parent.ShiftActions)) do
	assert(Shift[name] == nil, "Duplicate shift method: " .. name)
	Shift[name] = method
end
for name, method in pairs(require(script.Parent.ShiftSnapshot)) do
	assert(Shift[name] == nil, "Duplicate shift method: " .. name)
	Shift[name] = method
end
for name, method in pairs(require(script.Parent.Parent.Horror.ThreatService)) do
	assert(Shift[name] == nil, "Duplicate shift method: " .. name)
	Shift[name] = method
end

return Shift
