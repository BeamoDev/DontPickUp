-- Methods operate on the owning shift; no module-global gameplay state.
local Methods = {}
local Pickup = require(script.Parent.Parent.Orders.CustomerPickupService)
local Stations = require(script.Parent.Parent.Repair.RepairStations)
local Policy = require(script.Parent.Parent.Story.GovernmentService)
local Puzzles = require(script.Parent.Parent.Repair.RepairPuzzles)
local Dialogue = require(script.Parent.Parent.Story.DialogueService)
local Modes = require(script.Parent.ModeRules)
local Definitions = require(script.Parent.ShiftDefinitions)
local Engagement = require(script.Parent.EmployeeService)
local OBJECTIVES = Definitions.OBJECTIVES
function Methods:Snapshot(player)
	local member = self.players[player]
	local lane = Stations.ForPlayer(self, player)
	local order, event = lane.order, self.event
	local counterOrder = Stations.AtCounter(self, player).order
	local elapsed = self.nightAt and math.clamp((self.endedAt or self.d.clock()) - self.nightAt, 0, self.c.NightSeconds)
		or 0
	local snapshot = {
		Revision = self.revision,
		StationId = lane.Id,
		CounterOrderId = counterOrder and counterOrder.Id,
		PhoneName = lane.Id == "Bench" and "RepairPhone" or "RepairPhone2",
		TrayName = lane.Id == "Bench" and "ReplacementTray" or "ReplacementTray2",
		Dialogue = self.dialogue and self.d.clock() < self.dialogue.ExpiresAt and table.clone(self.dialogue) or nil,
		RunId = self.id,
		Phase = self.phase,
		PhaseLabel = self.phase == "Tutorial" and "Preparation" or self.phase == "Night" and "Shop open" or self.phase,
		ClosingEndsAt = self.closingEndsAt,
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
		RuleSections = { "Repair the phones.", "Report unusual customers.", "Do not answer the ringing shop phone." },
		Tutorial = self.phase == "Tutorial",
		NeedsClockIn = member
			and member.Alive
			and not member.ClockedIn
			and (self.phase == "Tutorial" or self.phase == "Night"),
		DoorOpen = self.doorOpen == true,
		Focus = member and member.Focus and table.clone(member.Focus),
		Fax = Pickup.Snapshot(self, member),
		Inspection = member and member.Inspection and table.clone(member.Inspection),
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
		Injury = member and member.Injury and self.d.clock() < member.Injury.ExpiresAt and table.clone(member.Injury)
			or nil,
		Outside = member and member.Alive and member.Outside and member.Outside.Since and {
			Since = member.Outside.Since,
			ThreatEndsAt = member.Outside.ThreatEndsAt,
		} or nil,
		NeedsRules = member
			and member.Alive
			and member.ClockedIn
			and not member.Acknowledged
			and (self.phase == "Tutorial" or self.phase == "Night"),
		Alive = member and member.Alive or false,
		Seated = member and self.d.seated(player) or false,
		SeatStation = member and self.d.seatStation and self.d.seatStation(player) or nil,
		SeatVisit = member and member.SeatVisit or 0,
		CarriedPart = member and member.CarriedPart and member.CarriedPart.Fault or nil,
		WorkBlocked = Policy.BlocksWork(self),
		ArrivalsPaused = self.event ~= nil or self.resumeAt ~= nil,
		HP = member and member.HP or 0,
		PersonalRepairs = member and member.Repairs or 0,
		Outcome = member and member.Outcome,
		LossStats = member and member.LossStats and table.clone(member.LossStats) or nil,
		CompleteStats = member and member.CompleteStats and table.clone(member.CompleteStats) or nil,
		DeathReason = member and member.DeathReason,
		Spectator = member and member.Spectator,
		SaveStatus = member
				and member.Outcome
				and (member.Settled and self.d.saveStatus(player) or "Waiting to record progress")
			or nil,
		Repaired = self.repaired,
		Missed = self.missed,
		Revenue = self.revenue,
		PhoneReads = self.phoneReads or 0,
		PhoneCalls = self.phoneCalls or 0,
		RuleBreaks = self.ruleBreaks or 0,
		Suspicion = self.suspicion,
		Stock = table.clone(self.stock),
		CanReturn = self:CanReturn(player),
		CanReplay = self.phase == "Results"
			and self.d.sessionReady()
			and member ~= nil
			and (not member.Outcome or member.Settled == true)
			and (not self:CanContinue() or member and member.Alive == true),
		Roster = {},
		Decisions = table.clone(self.decisions),
		EmployeeReports = Engagement.PublicReports(self.employeeReports),
		Awards = table.clone(self.awards or {}),
		Handbook = Engagement.CollectionSnapshot(member),
		Notice = self.noticeUntil and self.d.clock() < self.noticeUntil and self.notice or nil,
		NoticeUntil = self.noticeUntil,
		Objective = self.phase == "Waiting" and "Waiting for your party and saved data..."
			or self.phase == "Closing" and "Shop closed to new customers. Help finish the remaining phones."
			or "Next customer soon. Tune the radio or restock in the STOCKROOM.",
		SessionState = self.d.sessionState(),
		Replay = member and member.Replay or false,
		Signals = Engagement.Signals,
	}
	if Policy.Enabled(self) and self.policy then
		snapshot.RuleSections[2] = self.policy.Text
		snapshot.Rules = "MINISTRY DEVICE SERVICE / NIGHT "
			.. self.night
			.. "\n\n"
			.. self.policy.Text
			.. "\n\nRepair one faulty part. Check the phone. Return it using its pickup ticket. Private records are optional."
		snapshot.Intro = {
			Title = "NIGHT " .. self.night .. " / MINISTRY DEVICE SERVICE",
			Text = "The Ministry owns this repair shop. Customers come for repairs. You also service their security updates.\n\n"
				.. self.policy.Text,
		}
	end
	if member and member.PrivateDialogue and self.d.clock() < member.PrivateDialogue.ExpiresAt then
		snapshot.Dialogue = table.clone(member.PrivateDialogue)
	end
	for other, info in pairs(self.players) do
		table.insert(snapshot.Roster, {
			UserId = other.UserId,
			Name = other.DisplayName,
			Alive = info.Alive,
			HP = info.HP,
			Repairs = info.Repairs,
			Replay = info.Replay,
			Acknowledged = info.Acknowledged,
			Signal = info.SignalUntil and self.d.clock() < info.SignalUntil and info.Signal or nil,
		})
	end
	table.sort(snapshot.Roster, function(a, b)
		return a.UserId < b.UserId
	end)
	if order then
		snapshot.Order = {
			Id = order.Id,
			Ticket = order.Ticket,
			Customer = order.Customer,
			AppearanceId = order.AppearanceId,
			Complaint = order.Complaint,
			Device = order.Device,
			DeviceId = order.DeviceId or "Phone",
			RedSticker = order.UpdateRequired == true,
			Fee = order.Fee,
			PartDelivered = order.PartDelivered == true,
			Contacts = order.Contacts or 0,
			RequiredContacts = order.RequiredContacts or self.c.SecureContacts,
			Requirement = order.Requirement,
			PartCarrier = order.PartHolder and order.PartHolder.DisplayName or nil,
			Paused = order.PausedAt ~= nil,
			PatienceRemaining = order.PausedAt and order.ExpiresAt and math.max(0, order.ExpiresAt - order.PausedAt)
				or nil,
			Step = order.Step,
			Fault = order.Step ~= "Waiting" and order.Step ~= "Arriving" and order.Step ~= "Diagnose" and order.Fault
				or nil,
			ExpiresAt = order.ExpiresAt,
		}
		snapshot.Objective = OBJECTIVES[order.Step]
		if Policy.Enabled(self) and order.Step == "Install" then
			snapshot.Objective = order.UpdateRequired
					and "Check the phone. RED sticker: install the security update or ask your team."
				or "Check the repaired phone. Private records are optional; choose FINISH when ready."
		end
		snapshot.Target = (order.Step == "Waiting" or order.Step == "Arriving") and "Counter"
			or order.Step == "Collect" and (self.stock[order.Fault] > 0 and "Part_" .. order.Fault or "Stock")
			or order.Step == "ReadyForPickup" and "Fax"
			or (order.Step == "Return" or order.Step == "PickupArriving") and "Counter"
			or lane.Id
	end
	local voting = Stations.Voting(self)
	if voting then
		local order = voting.order
		snapshot.Vote = {
			OrderId = order.Id,
			Ticket = order.Ticket,
			EndsAt = order.VoteEndsAt,
			Choice = order.Votes[player],
			Purpose = order.VotePurpose,
			Message = order.VotePurpose == "Software"
					and "The technician wants to leave this phone without CIVIC WATCH. This breaks government rules."
				or (order.Evidence and order.Evidence.Message or "Private information was found."),
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
	if not order and self.phase == "Tutorial" then
		snapshot.Objective = "Read tonight's rules. Wait for everyone to press READY."
	end
	if lane.work then
		snapshot.Work = {
			Action = lane.work.Action,
			Name = lane.work.Player.DisplayName,
			UserId = lane.work.Player.UserId,
			Station = lane.work.Station,
			StartedAt = lane.work.StartedAt,
			EndsAt = lane.work.EndsAt,
			Id = lane.work.Id,
			OrderId = lane.work.OrderId,
			Interactive = lane.work.Puzzle ~= nil,
			Puzzle = lane.work.Player == player and lane.work.Puzzle and Puzzles.Snapshot(lane.work.Puzzle) or nil,
		}
	end
	if event then
		snapshot.Event = table.clone(event)
	end
	if member and order and not lane.work and not Policy.BlocksWork(self) then
		local required = Puzzles.Gear[order.Step]
		if required and not self.d.hasGear(player, required) then
			snapshot.RequiredTool = required
			snapshot.Target = "Tools"
			snapshot.Objective = "Collect the REPAIR KIT beside the bench. Stand up to fetch it."
		end
	end
	if snapshot.NeedsClockIn then
		snapshot.Objective = "Enter through the STAFF DOOR, then use the TIMECLOCK to start your shift."
		snapshot.Target = (self.doorOpen or self.d.near(player, "Timeclock")) and "Timeclock" or "StaffDoor"
	end
	if member and member.PersonalNoticeUntil and self.d.clock() < member.PersonalNoticeUntil then
		snapshot.Notice, snapshot.NoticeUntil = member.PersonalNotice, member.PersonalNoticeUntil
	end
	if snapshot.Outside and snapshot.Outside.ThreatEndsAt then
		snapshot.Target, snapshot.Objective =
			"StaffDoor", "FOOTSTEPS BEHIND YOU. Get inside the shop before they reach you."
	end
	return snapshot
end

return Methods
