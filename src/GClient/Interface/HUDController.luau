local UI = require(script.Parent.AuthoredUI)
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("GShared", 30)
local View = {}
View.__index = View
local ACCENT, AMBER = Color3.fromRGB(220, 213, 200), Color3.fromRGB(193, 155, 123)
local INK, PAPER = Color3.fromRGB(0, 0, 0), Color3.fromRGB(235, 235, 235)
local Public = require(Shared:WaitForChild("Repair", 30):WaitForChild("RepairDefinitions", 30))
local STEP_NAMES = Public.StepNames
local ERRORS = {
	ProgramInstalled = "The program is already installed.",
	TeamDecisionFinal = "Your team has already decided for this phone.",
	ProgramRequired = "Install the program, or ask your team to skip it.",
	InstallingProgram = "The program is still copying. Check again in a moment.",
	InvalidTicket = "Enter all six numbers on the ticket.",
	TicketNotFound = "No customer has that ticket. Check the six numbers.",
	PhoneNotReady = "Finish repairing and testing this phone first.",
	FaxClosed = "Use the fax phone again.",
	MissingTool = "Collect the highlighted tool before using this station.",
	KeyRequired = "This drawer needs a small brass key. Search the shop.",
	PuzzleChanged = "This task changed. Follow the new steps on screen.",
	FocusChanged = "Inspect the timeclock again to clock in.",
	AlreadyClockedIn = "Your timecard is already stamped for this shift.",
	InvalidInput = "Use the highlighted controls.",
	ClockInFirst = "Clock in beside the staff entrance before starting work.",
	StandFirst = "Stand up and walk into the parts room first.",
	SitFirst = "Sit in the repair chair before working on the phone.",
	BenchOccupied = "A teammate is using the repair chair. You can bring them a part.",
	MissingPart = "Bring the marked part to the bench and put it down first.",
	WrongPart = "Check the repair ticket and collect the matching part.",
	AlreadyCarrying = "Place your carried part at the bench first.",
	DisturbanceActive = "Repairs are paused. Follow the warning on screen first.",
	MoveCloser = "Move closer to the marked station.",
	WrongStep = "Finish the step shown on screen first.",
	OrderChanged = "There is a new phone. Follow the new instructions.",
	EventChanged = "That problem is already over.",
	WorkInProgress = "Someone is already working. Stay nearby until they finish.",
	NoPower = "Use the fuse box to turn the lights back on first.",
	OutOfStock = "Use PARTS to restock first.",
	ReadRules = "Read tonight's rules, then press READY.",
	DataNotReady = "Waiting for your saved data.",
	PleaseWait = "Please wait a moment.",
	RateLimited = "Please wait a moment.",
	RequestPending = "Please wait for the current request.",
	StockFull = "There are already enough spare parts.",
	ShiftClosed = "Your shift is over. Wait for your team to finish.",
	ShiftChanged = "A new shift has started.",
	NotReady = "Wait for your progress to be recorded.",
	VoteClosed = "Voting has ended.",
	ConnectionError = "The server is taking longer than usual. Try again shortly.",
	InvalidSignal = "Choose one of the approved team messages.",
	StudioPreviewComplete = "Studio return check passed. A published game would send you to the lobby.",
}

local function frame(parent, name)
	local object = UI.Bind("Frame", parent, name)
	UI.Bind("UICorner", object, nil)
	return object
end

local function label(parent, name)
	return UI.Bind("TextLabel", parent, name, { Text = "" })
end

function View.new(playerGui, actions)
	local self = setmetatable({ actions = actions, connections = {}, state = {}, rulesOpen = false }, View)
	self.gui = UI.Bind("ScreenGui", playerGui, "DPU_PrototypeHUD")
	self.gui.Enabled, self.gui.ResetOnSpawn = true, false
	local function button(parent, name, text, callback)
		local value = UI.Bind("TextButton", parent, name, { Text = text })
		table.insert(self.connections, value.Activated:Connect(callback))
		return value
	end
	local hud = playerGui:FindFirstChild("HUD")
	if hud and hud:FindFirstChild("Clock") then
		self.hud = UI.Bind("ScreenGui", playerGui, "HUD")
		self.hud.Enabled, self.hud.ResetOnSpawn = true, false
	end
	self.clockPanel = UI.Bind("Frame", self.hud or self.gui, "Clock")
	self.night = label(self.clockPanel, "Night")
	self.clock = label(self.clockPanel, "Time")
	self.warning = frame(self.gui, "Warning")
	UI.Bind("UISizeConstraint", self.warning, nil)
	self.warningText = label(self.warning, "Text")
	local authoredObjective = hud and hud:FindFirstChild("Objective")
	self.authoredObjective = authoredObjective ~= nil
	if authoredObjective then
		self.bottom = UI.Bind("Frame", hud, "Objective")
		local scope = self.bottom:FindFirstChild("Frame") or self.bottom
		local text = scope:FindFirstChild("Text", true) or scope:FindFirstChildWhichIsA("TextLabel", true)
		assert(text and text:IsA("TextLabel"), "[DPU] HUD.Objective.Frame needs its objective TextLabel")
		self.objective = UI.Bind("TextLabel", text.Parent, text.Name, { Text = "", Visible = true })
		local ancestor = text.Parent
		while ancestor and ancestor ~= self.bottom do
			if ancestor:IsA("GuiObject") then
				UI.Bind("GuiObject", ancestor.Parent, ancestor.Name, { Visible = true })
			end
			ancestor = ancestor.Parent
		end
		local use = scope:FindFirstChild("Use", true)
		if use and use:IsA("GuiButton") then
			self.use = UI.Bind("GuiButton", use.Parent, use.Name)
			self.useText = use:IsA("TextButton") and use or use:FindFirstChildWhichIsA("TextLabel", true)
			if self.useText and self.useText ~= use then
				self.useText = UI.Bind("TextLabel", self.useText.Parent, self.useText.Name)
			end
			table.insert(
				self.connections,
				use.Activated:Connect(function()
					local action = self:CurrentAction()
					if action and not self.busy then
						self.actions.act(action)
					end
				end)
			)
		end
	else
		self.bottom = frame(self.gui, "Objective")
		UI.Bind("UISizeConstraint", self.bottom, nil)
		self.objective = label(self.bottom, "Text")
		self.use = button(self.bottom, "Use", "INTERACT", function()
			local action = self:CurrentAction()
			if action and not self.busy then
				self.actions.act(action)
			end
		end)
		self.useText = self.use
	end
	self.signalButtons = {}
	if self.gui:FindFirstChild("TeamSignals") then
		self.signalMenu = frame(self.gui, "TeamSignals")
		UI.Bind("UISizeConstraint", self.signalMenu, nil)
		local signals = { "Parts", "Phone", "Inside", "NoAnswer", "Ticket", "Why" }
		for index, key in ipairs(signals) do
			self.signalButtons[key] = button(self.signalMenu, key, key, function()
				self.signalsOpen = false
				self.actions.act("Signal", key)
			end)
		end
	end
	if self.gui:FindFirstChild("Briefing") then
		self.modal = frame(self.gui, "Briefing")
		self.modalTitle = label(self.modal, "Title")
		local scroll = UI.Bind("ScrollingFrame", self.modal, "Content")
		self.modalText = label(scroll, "Text")
		self.ack = button(self.modal, "Acknowledge", "READY", function()
			if self.introVisible then
				self:AcknowledgeIntro()
			elseif self.state.NeedsRules then
				self.actions.act("ReadRules")
			else
				self.rulesOpen = false
				self:Render()
			end
		end)
		self.voteButtons = {}
		for i, choice in ipairs({ "Report", "Hide", "Investigate" }) do
			self.voteButtons[choice] = button(self.modal, choice, string.upper(choice), function()
				if not self.busy then
					if self.confirmAnswer then
						local eventId = self.confirmAnswer
						self.confirmAnswer = nil
						if choice == "Hide" and self.state.Event and self.state.Event.Id == eventId then
							self.actions.act("Answer")
						end
						self:Render()
					else
						self.actions.act("Vote", choice)
					end
				end
			end)
		end
		self.replay = button(self.modal, "Replay", "READY FOR ANOTHER NIGHT", function()
			if not self.busy then
				self.actions.act("Replay")
			end
		end)
		self.lobby = button(self.modal, "Lobby", "RETURN TO LOBBY", function()
			if self.busy or not self.state.CanReturn then
				return
			end
			if self.confirmReturn then
				self.actions.lobby()
			else
				self.confirmReturn = true
				self:Render()
			end
		end)
	end
	self:Render()
	return self
end

function View:RequestAnswer()
	local event = self.state.Event
	if not event then
		return
	end
	if not self.modal and self.answerArmed == event.Id and workspace:GetServerTimeNow() < (self.answerUntil or 0) then
		self.answerArmed = nil
		self.actions.act("Answer")
	else
		self.confirmAnswer = event.Id
		self:Render()
	end
end
function View:RenderNotice(ending, vote, intro, rules, authoredLoss)
	if not self.panels or not self.panels.briefing or authoredLoss or intro then
		return
	end
	local state, message = self.state, nil
	if self.confirmAnswer then
		message = {
			Title = "PICK UP?",
			Text = "Answering this call will hurt you and change the Story ending. Understood closes this warning. To answer anyway, click the receiver again within ten seconds.",
			Action = "ArmAnswer",
		}
	elseif ending then
		message = {
			Title = state.Ending and state.Ending.Title or state.Reason == "Dawn" and "SHIFT COMPLETE" or "SHIFT ENDED",
			Text = string.format(
				"Nights cleared: %d. Phones fixed: %d. Shop earnings: $%d.\n\n%s",
				state.NightsCleared or 0,
				state.Repaired or 0,
				state.Revenue or 0,
				state.Replay and "You are ready. Waiting for the other employees."
					or state.CanReplay and "Press Understood to ready up and continue with your team."
					or state.CanReturn and "Press Understood to return to the lobby."
					or "Your results are being saved. Please wait."
			),
			Action = state.CanReplay and "Replay" or "ReturnLobby",
			Disabled = state.Replay or not (state.CanReplay or state.CanReturn),
		}
	elseif
		vote and self.voteSeen ~= state.RunId .. ":" .. state.Vote.OrderId .. ":" .. tostring(state.Vote.Purpose)
	then
		message = {
			Title = "TEAM DECISION",
			Text = state.Vote.Message
				.. (
					state.Vote.Purpose == "Software"
						and "\n\nUse the vote parts: REPORT installs CIVIC WATCH; HIDE skips it; INVESTIGATE skips it and opens a record. Skipping raises suspicion."
					or "\n\nUse the vote parts: REPORT sends evidence to the government; HIDE protects it; INVESTIGATE looks deeper. Hiding or investigating raises suspicion."
				),
			Action = "VoteNotice",
		}
	elseif rules and not self.panels.rules then
		message = { Title = "TONIGHT'S RULES", Text = table.concat(state.RuleSections or {}, "\n\n"), Action = "Rules" }
	end
	self.notice = message
	self.panels:Notice(message, self.busy)
end
function View:AcknowledgeNotice()
	local message, state = self.notice, self.state
	if not message or self.busy or message.Disabled then
		return
	end
	if message.Action == "ArmAnswer" then
		self.answerArmed, self.answerUntil = self.confirmAnswer, workspace:GetServerTimeNow() + 10
		self.confirmAnswer = nil
	elseif message.Action == "VoteNotice" then
		self.voteSeen = state.RunId .. ":" .. state.Vote.OrderId .. ":" .. tostring(state.Vote.Purpose)
	elseif message.Action == "Rules" then
		if state.NeedsRules then
			self.actions.act("ReadRules")
		else
			self.rulesOpen = false
		end
	else
		self.actions.act(message.Action)
	end
	self:Render()
end

function View:AcknowledgeIntro()
	if self.introVisible and not self.busy then
		self.introSeen = self.state.RunId
		self:Render() -- Local acknowledgement only; clock-in and rules remain server validated.
	end
end

function View:IsModalOpen()
	return (self.modal ~= nil and self.modal.Visible) or (self.panels ~= nil and self.panels:IsOpen())
end

function View:ToggleRules()
	self.rulesOpen = not self.rulesOpen
	self.signalsOpen = false
	self:Render()
end
function View:ToggleSignals()
	if not self.signalMenu then
		return
	end
	self.signalsOpen = not self.signalsOpen
	self.rulesOpen = false
	self:Render()
end

function View:CurrentAction()
	local state = self.state
	if state.NeedsClockIn then
		if state.Focus then
			return nil
		end
		return state.Target == "Timeclock" and "OpenClock" or "ToggleDoor"
	end
	if not state.Alive or state.NeedsRules or state.Phase == "Results" then
		return nil
	end
	if state.Outside and state.Outside.ThreatEndsAt then
		return not state.DoorOpen and "ToggleDoor" or nil
	end
	if
		state.Event
		and ((state.WorkBlocked == true or state.WorkBlocked == nil and state.Event ~= nil) or not state.Order)
	then
		local mapped = { Blackout = "RestorePower", Call = "Silence", Inspection = "Records" }
		if mapped[state.Event.Kind] then
			return mapped[state.Event.Kind]
		end
		if state.Event.Kind == "Visitor" then
			return nil
		end
		return nil
	end
	local order = state.Order
	if state.RequiredTool then
		return state.Seated and "Stand" or "PickupTool"
	end
	if state.CarriedPart then
		return "DepositPart"
	end
	if not order or state.Work or state.Vote then
		return nil
	end
	if order.Step == "ReadyForPickup" then
		return state.Seated and "Stand" or "OpenFax"
	end
	if order.Step == "Waiting" then
		return "TakeOrder"
	end
	if state.Seated and (order.Step == "Collect" or (state.SeatStation and state.Target ~= state.SeatStation)) then
		return "Stand"
	end
	if table.find({ "Diagnose", "Repair", "Secure", "Install", "Test" }, order.Step) and not state.Seated then
		return "Sit"
	end
	if order.Step == "Repair" and not order.PartDelivered then
		return nil
	end
	if order.Step == "Collect" and (state.Stock[order.Fault] or 0) == 0 then
		return "Restock"
	end
	if table.find({ "Diagnose", "Collect", "Repair", "Secure", "Install", "Test", "Return" }, order.Step) then
		return order.Step
	end
end

function View:SetState(state)
	if state.RunId ~= self.state.RunId then
		self.confirmReturn, self.rulesOpen = false, false
		self.error = nil
	end
	self.state = state
	if state.Error then
		self:Error(state.Error)
	end
	self:Render()
end

function View:Error(code)
	self.error = ERRORS[code] or "That action is unavailable. Follow the current objective."
	self.errorUntil = os.clock() + 4
	self:Render()
end

function View:SetBusy(busy)
	self.busy = busy
	self:Render()
end

function View:Render()
	local state, now = self.state, workspace:GetServerTimeNow()
	local camera = workspace.CurrentCamera
	local short = camera and camera.ViewportSize.Y < 700
	local compact = camera and (camera.ViewportSize.X < 750 or short)
	if self.layoutShort ~= short or self.layoutCompact ~= compact or not self.layoutReady then
		self.layoutShort, self.layoutCompact, self.layoutReady = short, compact, true
		self.warning.Position = UDim2.new(0.5, 0, 0, 72)
		self.warning.Size = UDim2.new(0.94, 0, 0, short and 36 or 56)
		self.warningText.TextSize = short and 12 or 15
		if self.modal then
			self.modal.Position = short and UDim2.new(0.04, 0, 0, 116) or UDim2.fromScale(0.08, 0.22)
			self.modal.Size = short and UDim2.new(0.92, 0, 1, -126) or UDim2.fromScale(0.84, 0.58)
			self.modalTitle.TextSize = compact and 18 or 23
		end
		if not self.authoredObjective then
			self.objective.TextSize = compact and 15 or 17
		end
	end
	local hour = state.ClockHour or 0
	if state.NightStartedAt and state.NightDuration then
		hour = math.clamp(((state.TimeFrozenAt or now) - state.NightStartedAt) / state.NightDuration, 0, 1) * 6
	end
	local minutes = math.floor(hour * 60)
	self.night.Text = tostring(state.Night or 1)
	self.clock.Text = state.NeedsClockIn and "CLOCK IN"
		or state.Phase == "Tutorial" and "PREPARATION"
		or state.Phase == "Closing" and ("CLOSING " .. math.max(0, math.ceil((state.ClosingEndsAt or now) - now)) .. "s")
		or string.format(
			"%02d:%02d AM",
			math.floor(minutes / 60) % 12 == 0 and 12 or math.floor(minutes / 60) % 12,
			minutes % 60
		)
	local objective = state.Objective or "Loading your shift..."
	if state.StationId and (state.Phase == "Night" or state.Phase == "Closing") then
		objective = (state.StationId == "Bench2" and "BENCH 2: " or "BENCH 1: ") .. objective
	end
	if state.Order and state.Order.Fault then
		objective ..= "\nPart: " .. state.Order.Fault
	end
	if state.Order and state.Order.RedSticker then
		objective ..= "\nRED SERVICE STICKER / SECURITY UPDATE REQUIRED"
	end
	if state.CarriedPart then
		objective = "CARRYING: " .. state.CarriedPart .. ". Go back to the bench and press PUT PART ON BENCH."
	elseif state.Order and state.Order.PartCarrier and not state.Order.PartDelivered then
		objective = state.Order.PartCarrier .. " is bringing the replacement. Wait at the bench or help with the shop."
	elseif state.Order and state.Order.PartDelivered and state.Order.Step == "Repair" then
		objective = "Replacement ready. Sit at the repair bench and fit it to the phone."
	elseif not state.Order and state.ArrivalsPaused then
		objective = "SERVICE PAUSED. Customers will return after the shop is safe."
	end
	if state.Work then
		objective = state.Work.Interactive
				and (state.Work.Name .. ": " .. state.Work.Action .. ". Complete the bench controls.")
			or state.Work.Name
				.. ": "
				.. state.Work.Action
				.. " ("
				.. math.max(0, math.ceil(state.Work.EndsAt - now))
				.. "s). Stay by the station."
	end
	if state.RequiredTool and not state.Work then
		objective = "Collect the repair kit beside the bench. Stand up to fetch it."
	end
	if
		state.Event
		and ((state.WorkBlocked == true or state.WorkBlocked == nil and state.Event ~= nil) or not state.Order)
	then
		objective = state.Event.Warning
	end
	if state.Outside and state.Outside.ThreatEndsAt then
		objective = "Return through the STAFF DOOR before the footsteps reach you."
	end
	if state.Phase == "Results" then
		objective = "Shift complete. Review your results."
	end
	if state.Outcome == "Died" and state.Phase ~= "Results" then
		objective = "YOU DIED. Watching your team until the shift ends.\n" .. (state.DeathReason or "")
	end
	self.objective.Text = objective
	local action = self:CurrentAction()
	if self.use then
		self.use.Visible, self.use.Active = action ~= nil, not self.busy and action ~= nil
	end
	if self.useText then
		self.useText.Text = self.busy and "PLEASE WAIT"
			or action == "ClockIn" and "CLOCK IN"
			or action == "OpenFax" and "USE FAX PHONE"
			or action == "OpenClock" and "OPEN TIMECLOCK"
			or action == "PickupTool" and "TAKE REPAIR KIT"
			or action == "ToggleDoor" and "OPEN STAFF DOOR"
			or action == "Secure" and "PUT PHONE BACK TOGETHER"
			or action == "Sit" and "SIT AT REPAIR BENCH"
			or action == "Stand" and "STAND UP"
			or action == "DepositPart" and "PUT PART ON BENCH"
			or action == "Collect" and ("TAKE " .. string.upper(state.Order.Fault or "PART"))
			or action == "Repair" and ("FIT " .. string.upper(state.Order.Fault or "PART"))
			or action == "Diagnose" and "FIND THE BROKEN PART"
			or action == "Install" and "OPEN CUSTOMER PHONE"
			or action == "Test" and "CHECK THE PHONE"
			or action == "TakeOrder" and "TAKE CUSTOMER'S PHONE"
			or action == "Return" and "GIVE PHONE BACK"
			or action == "Restock" and "UNPACK MORE PARTS"
			or action == "ReadRules" and "READ TONIGHT'S RULES"
			or action == "Records" and "SHOW REPAIR PAPERS"
			or action and string.upper(action:gsub("(%l)(%u)", "%1 %2"))
			or "WAIT"
	end
	local outsideWarning = state.Outside and state.Outside.ThreatEndsAt
	local injury = state.Alive and state.Injury and now < state.Injury.ExpiresAt and state.Injury or nil
	local warning = outsideWarning
			and ("GET INSIDE. Footsteps behind you.  " .. math.max(0, math.ceil(outsideWarning - now)) .. "s")
		or injury and ("HURT: -" .. injury.Damage .. " HP / " .. state.HP .. " HP LEFT. " .. injury.Reason)
		or state.Event and (state.Event.Warning .. "  " .. math.max(0, math.ceil(state.Event.EndsAt - now)) .. "s")
		or ((not state.NoticeUntil or now < state.NoticeUntil) and state.Notice or nil)
		or state.Outside and "You feel watched outside. The longer you stay, the greater the danger."
	local hasError = self.error and os.clock() < (self.errorUntil or 0)
	if hasError then
		warning = self.error
	end
	self.warning.Visible, self.warningText.Text = warning ~= nil, warning or ""
	if state.Order then
		local o = state.Order
		self.orderDetails = "REPAIR TICKET "
			.. (o.Ticket or o.Id)
			.. "\n\n"
			.. o.Customer
			.. "\n"
			.. (o.Device or "Customer phone")
			.. " / $"
			.. (o.Fee or 45)
			.. "\n"
			.. o.Complaint
			.. (o.Requirement and "\nJOB: " .. o.Requirement or "")
			.. "\n\n"
			.. (STEP_NAMES[o.Step] or o.Step)
			.. (o.Fault and "\nPART: " .. o.Fault or "")
			.. (
				o.Paused and "\nCustomer is waiting while we deal with the problem."
				or o.ExpiresAt and "\nCustomer leaves in: " .. math.max(0, math.ceil(o.ExpiresAt - now)) .. "s"
				or (o.Step == "ReadyForPickup" or o.Step == "PickupArriving" or o.Step == "Return") and "\nRepair finished. Waiting for collection."
				or "\nTraining: take your time"
			)
	else
		self.orderDetails = "SERVICE WINDOW\n\nWaiting for the next customer.\n\nRepairs: " .. (state.Repaired or 0)
	end
	local staff, results, readied, eligible = {}, {}, 0, 0
	for _, member in ipairs(state.Roster or {}) do
		table.insert(staff, member.Name .. "  " .. (member.Alive and member.HP .. " HP" or "OFF DUTY"))
		table.insert(
			results,
			member.Name .. "  |  " .. member.Repairs .. " repairs  |  " .. (member.Alive and "Alive" or "Off duty")
		)
		if not state.ContinueRun or member.Alive then
			eligible += 1
			if member.Replay then
				readied += 1
			end
		end
	end
	self.rosterDetails = "ON DUTY\n\n"
		.. table.concat(staff, "\n")
		.. "\n\nSHOP EARNINGS $"
		.. (state.Revenue or 0)
		.. "\nKEEPSAKES "
		.. (state.SecretsFound or 0)
		.. " FOUND"
	local failed = state.Phase == "Waiting"
		and (state.SessionState == "Incomplete" or state.SessionState == "Interrupted")
	local ending = state.Phase == "Results" or failed
	local vote = state.Vote
		and not outsideWarning
		and state.Alive
		and not ending
		and not state.NeedsRules
		and not (state.WorkBlocked == true or state.WorkBlocked == nil and state.Event ~= nil)
		and not (state.Order and state.Order.Paused)
	local focused = state.Fax ~= nil
		or state.Inspection ~= nil
		or state.Focus ~= nil
		or (
			state.Work ~= nil
			and state.Work.Puzzle ~= nil
			and state.Alive == true
			and not (state.WorkBlocked == true or state.WorkBlocked == nil and state.Event ~= nil)
			and (state.Work.Station ~= "Bench" or state.Seated == true)
		)
	if focused or state.Event or ending or outsideWarning then
		self.rulesOpen = false
		self.signalsOpen = false
	end
	local rules = not ending
		and not vote
		and not (state.WorkBlocked == true or state.WorkBlocked == nil and state.Event ~= nil)
		and (state.NeedsRules or self.rulesOpen)
	local intro = not ending
		and not vote
		and not focused
		and not (state.WorkBlocked == true or state.WorkBlocked == nil and state.Event ~= nil)
		and state.Intro ~= nil
		and state.Alive == true
		and state.RunId ~= self.introSeen
		and state.NeedsClockIn == true
	self.introVisible = intro
	if not state.Event or state.Event.Kind ~= "Call" or state.Event.Id ~= self.confirmAnswer or not state.Alive then
		self.confirmAnswer = nil
	end
	local authoredRules, authoredLoss, authoredIntro, authoredComplete = false, false, false, false
	if self.panels then
		authoredRules, authoredLoss, authoredIntro, authoredComplete =
			self.panels:Update(state, self.busy, rules == true, intro == true)
	end
	if self.modal then
		self.modal.Visible = not authoredLoss
			and not authoredComplete
			and (
				self.confirmAnswer ~= nil
				or (intro and not authoredIntro)
				or ending
				or vote ~= nil and vote ~= false
				or (rules == true and not authoredRules)
			)
	else
		self:RenderNotice(ending, vote, intro, rules, authoredLoss or authoredComplete)
	end
	self.clockPanel.Visible = not self:IsModalOpen() and not focused
	self.bottom.Visible = not self:IsModalOpen() and not focused
	if self.signalMenu then
		self.signalMenu.Visible = self.signalsOpen == true and self.clockPanel.Visible and state.Alive == true
	end
	for key, signalButton in pairs(self.signalButtons) do
		signalButton.Text = state.Signals and state.Signals[key] or key
		signalButton.Active = not self.busy
	end
	-- Keep urgent feedback, but don't repeat hazard instructions in two cards.
	self.warning.Visible = warning ~= nil
		and (hasError == true or outsideWarning ~= nil or injury ~= nil or (not focused and not self:IsModalOpen()))
	if
		state.Seated
		and not (state.WorkBlocked == true or state.WorkBlocked == nil and state.Event ~= nil)
		and not hasError
		and not injury
		and not outsideWarning
	then
		self.warning.Visible = false
	end
	self.warning.Position = UDim2.new(0.5, 0, 0, state.Seated and not focused and not self:IsModalOpen() and 152 or 72)
	if
		state.Event
		and (state.WorkBlocked == true or state.WorkBlocked == nil and state.Event ~= nil)
		and not hasError
	then
		self.bottom.Visible = action ~= nil
		self.objective.Text = "Respond before the time runs out."
	end
	if not self.authoredObjective then
		self.objective.Size = action and UDim2.new(0.67, -18, 1, -18) or UDim2.new(1, -24, 1, -18)
	end
	if not self.modal then
		return
	end
	self.ack.Visible = intro or rules == true
	self.ack.Active = not self.busy
	self.ack.Text = intro and "START SHIFT" or state.NeedsRules and "READY" or "BACK TO WORK"
	for choice, button in pairs(self.voteButtons) do
		button.Visible, button.Active = vote ~= nil and vote ~= false, not self.busy
		local label = vote
				and state.Vote.Purpose == "Software"
				and ({ Report = "INSTALL PROGRAM", Hide = "SKIP PROGRAM", Investigate = "LOOK CLOSER" })[choice]
			or ({ Report = "TELL GOVERNMENT", Hide = "KEEP SECRET", Investigate = "LOOK CLOSER" })[choice]
		button.Text = label .. (vote and (" (" .. state.Vote[choice] .. ")") or "")
		button.TextColor3 = vote and state.Vote.Choice == choice and ACCENT or PAPER
		if vote and state.Vote.Choice == choice then
			button.Text = "[ " .. button.Text .. " ]"
		end
	end
	self.replay.Visible, self.lobby.Visible = ending and state.CanReplay == true, ending
	self.replay.Active, self.lobby.Active = not self.busy, not self.busy and state.CanReturn == true
	self.replay.Text = state.Replay and "READY - WAITING FOR TEAM"
		or (state.ContinueRun and "NEXT NIGHT" or "NEW RUN") .. " (" .. readied .. "/" .. eligible .. ")"
	self.lobby.Text = self.busy and "PLEASE WAIT..." or self.confirmReturn and "CONFIRM RETURN" or "RETURN TO LOBBY"
	if self.confirmAnswer then
		self.modalTitle.Text = "PICK UP?"
		self.modalText.Text = "The rules say not to answer. Answering will hurt you and change the Story ending."
		self.ack.Visible, self.replay.Visible, self.lobby.Visible = false, false, false
		self.voteButtons.Report.Visible, self.voteButtons.Hide.Visible, self.voteButtons.Investigate.Visible =
			true, true, false
		self.voteButtons.Report.Text, self.voteButtons.Hide.Text = "LEAVE IT", "ANSWER ANYWAY"
	elseif ending then
		self.modalTitle.Text = state.Ending and state.Ending.Title
			or failed and "PARTY COULD NOT START"
			or state.Outcome == "Died" and "YOU DID NOT MAKE IT"
			or state.Reason == "Dawn" and "6 AM - SHIFT SURVIVED"
			or "SHIFT INTERRUPTED"
		self.modalText.Text = (
			failed and "Your whole party could not arrive. Return to the lobby and try again."
			or string.format(
				"REPAIRS FINISHED: %d\nCUSTOMERS MISSED: %d\nSHOP EARNINGS: $%d\nYOUR REPAIRS: %d\n\n%s\n\nDECISIONS: %s\n\n%s",
				state.Repaired or 0,
				state.Missed or 0,
				state.Revenue or 0,
				state.PersonalRepairs or 0,
				table.concat(results, "\n"),
				table.concat(state.Decisions or {}, ", "),
				state.SaveStatus or "Interrupted shifts do not award survival progress."
			)
		)
		if state.Ending then
			self.modalText.Text = state.Ending.Summary .. "\n\n" .. self.modalText.Text
		end
		if state.Outcome == "Died" and state.DeathReason then
			self.modalText.Text = "CAUSE: " .. state.DeathReason .. "\n\n" .. self.modalText.Text
		end
		if state.Mode then
			self.modalText.Text = state.Mode:upper()
				.. " / NIGHTS CLEARED: "
				.. (state.NightsCleared or 0)
				.. (state.ContinueRun and "\nSurvivors ready up for the next night. Dead staff can spectate or return to the lobby." or "\nRun complete. Start a new run or return to the lobby.")
				.. "\n\n"
				.. self.modalText.Text
		end
		self.modalText.Text ..= "\n\nPHONE LOG: " .. (state.PhoneReads or 0) .. " records read / " .. (state.PhoneCalls or 0) .. " private calls / " .. (state.RuleBreaks or 0) .. " rule breaks.\nWAGES: 10 credits per completed repair + 50 for surviving. Paid once when this night is recorded."
		if state.Awards and #state.Awards > 0 then
			self.modalText.Text ..= "\n\nEMPLOYEE AWARDS"
			for _, award in ipairs(state.Awards) do
				self.modalText.Text ..= "\n" .. award.Title .. " â€” " .. award.Name .. "\n" .. award.Detail
			end
		end
	elseif intro then
		self.modalTitle.Text, self.modalText.Text = state.Intro.Title, state.Intro.Text
	elseif vote then
		self.modalTitle.Text = state.Vote.Purpose == "Software" and "GOVERNMENT PROGRAM - TEAM VOTE"
			or "PRIVATE MESSAGE - TEAM VOTE"
		self.modalText.Text = state.Vote.Message
			.. (state.Vote.Purpose == "Software" and "\n\nINSTALL: obey the rule.\nSKIP: leave the program off; suspicion rises.\nLOOK CLOSER: leave it off and open a recovered record; suspicion rises further.\n\n" or "\n\nTELL GOVERNMENT: report the message. The customer may be in danger.\nKEEP SECRET: hide it; suspicion rises.\nLOOK CLOSER: open the recovered record; suspicion rises further.\n\n")
			.. math.max(0, math.ceil(state.Vote.EndsAt - now))
			.. (
				state.Vote.Purpose == "Software" and "s left. No votes/ties prefer INSTALL, then SKIP."
				or "s left. No votes/ties prefer TELL GOVERNMENT, then KEEP SECRET."
			)
	elseif rules then
		self.modalTitle.Text = state.NeedsRules and "YOUR NIGHT JOB" or "SHIFT INFO"
		self.modalText.Text = (state.Rules or "Loading tonight's rules...")
			.. "\n\nYOUR FIRST JOB\nTake the repair kit. Accept a phone. Follow the highlighted part.\n\nClick or tap small objects. At the bench, drag parts or choose USE BUTTONS. Q / B stands up. A friend can bring parts.\n\nThe first repair is practice. Keep the shop running until 6 AM."
		if not state.NeedsRules then
			self.modalText.Text = self.orderDetails
				.. "\n\n"
				.. self.rosterDetails
				.. "\n\nTONIGHT'S RULES\n"
				.. self.modalText.Text
			local reportLines = {}
			for _, report in ipairs(state.EmployeeReports or {}) do
				table.insert(reportLines, report.Employee .. " / " .. report.Status)
			end
			local handbook = state.Handbook or {}
			self.modalText.Text ..= "\n\nEMPLOYEE REVIEW\n" .. (#reportLines > 0 and table.concat(reportLines, "\n\n") or "No prior review on file.") .. "\n\nEMPLOYEE HANDBOOK\nCustomers " .. (handbook.Customers or 0) .. " / Anomalies " .. (handbook.Anomalies or 0) .. " / Stamps " .. (handbook.Stamps or 0)
		end
	end
end

function View:Destroy()
	if self.panels then
		self.panels:Destroy()
	end
	for _, connection in ipairs(self.connections) do
		connection:Disconnect()
	end
	UI.Release(self.bottom)
	UI.Release(self.clockPanel)
	UI.Release(self.hud)
	UI.Release(self.gui)
end

return View
