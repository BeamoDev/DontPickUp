-- Private records for repaired devices. Only the current page is projected to its operator.
local Records = {}
function Records.New(order, night)
	return {
		Kind = "Phone",
		Direction = true,
		Revision = 0,
		Progress = 0,
		Night = night,
		Page = order.Fault == "Speaker" and "RestoredRecording"
			or order.Fault == "Battery" and "Ringing"
			or "RestoredKeypad",
		Customer = order.Customer,
		Evidence = order.Evidence,
		Tutorial = order.Tutorial,
		Policy = order.ShopPolicy,
		UpdateRequired = order.UpdateRequired,
		ServiceSerial = order.DeviceSerial or order.Ticket,
		Employee = order.EmployeeId or "UNASSIGNED",
		Anomaly = order.Anomaly,
		IntakeLine = order.Complaint,
		Seen = {},
		KnownNumbers = {},
		DialedNumbers = {},
		Reads = 0,
		Calls = 0,
		Answered = 0,
		Violations = 0,
		Installed = false,
		ContactNumber = string.format("0%05d", (tonumber(order.Ticket) or 1) % 99999),
		DiscoveryNumber = order.DiscoveryNumber,
		AccessLog = {},
	}
end
local function menu(p)
	local page = p.Page
	if page == "Home" then
		return p.Customer .. " / SERVICE " .. p.ServiceSerial,
			(
				p.UpdateRequired and "RED SERVICE STICKER: security update required."
				or "No security update required for this device."
			)
				.. (p.Installed and "\nCIVIC WATCH INSTALLED" or p.SkipApproved and "\nUPDATE OMITTED BY TEAM" or "")
				.. "\nPrivate records are optional. FINISH continues the repair.",
			{ "SECURITY UPDATE", "CALL HISTORY", "CONTACTS", "RECORDINGS", "SERVICE RECORDS", "FINISH" }
	elseif page == "Program" then
		return "CIVIC WATCH / SECURITY UPDATE",
			p.Installed and "Installed. Automatic reporting is active. The owner cannot disable it."
				or p.InstallAt and "Copying... Wait two seconds, then check installation."
				or "MINISTRY APPROVED. Open permissions to see what this update can access.",
			{
				p.Installed and "INSTALLED" or p.InstallAt and "CHECK INSTALLATION" or "INSTALL",
				"PERMISSIONS",
				"REQUEST EXCEPTION",
				"BACK",
			}
	elseif page == "Permissions" then
		return "INSTALLATION PERMISSIONS",
			"Microphone access, including while idle. Copy outgoing calls. Upload saved messages to the Ministry archive.",
			{ "BACK" }
	elseif page == "Skip" then
		return "LEAVE THE UPDATE OFF?",
			"A required update will be missing from the Ministry record. Ask your team before proceeding.",
			{ "ASK TEAM", "BACK" }
	elseif page == "CallHistory" then
		return "CALL HISTORY",
			"23:41 - "
				.. p.ContactNumber
				.. " (HOME)\n23:46 - "
				.. p.ContactNumber
				.. " (HOME)"
				.. (p.Evidence and "\n02:13 - SHOP / recorded before this shop opened." or "\nLast call: no answer."),
			{ "DELETED RECORDS", "BACK" }
	elseif page == "Contacts" then
		return "SAVED NUMBERS",
			"HOME: "
				.. p.ContactNumber
				.. (p.KnownNumbers[p.DiscoveryNumber or ""] and "\nARCHIVE: " .. p.DiscoveryNumber or "")
				.. "\nDial a revealed number using the physical shop telephone. Pickup tickets still work there.",
			{ "BACK" }
	elseif page == "Recordings" then
		return "RECORDINGS", "Opening a personal recording is optional.", { "PLAY SAVED MEMO", "BACK" }
	elseif page == "Recording" then
		return "SAVED MEMO / TRANSCRIPT",
			p.Anomaly == "Echo"
					and ('The recording repeats the words spoken at intake: "' .. p.IntakeLine .. '". It is dated tomorrow.')
				or p.Evidence and p.Evidence.Message
				or "Bring the ration card. Pick up bread. Please stop leaving the kettle on.",
			{ "BACK" }
	elseif page == "Service" then
		return "SERVICE HISTORY / " .. p.ServiceSerial,
			"SIGNED IN: EMPLOYEE "
				.. p.Employee
				.. (p.Anomaly == "WrongEmployee" and "\nPREVIOUS REPAIR: yesterday. Signed by EMPLOYEE " .. p.Employee .. ". You were not on shift." or "\nPrevious service: municipal depot. Numbered replacement authorized.")
				.. "\nRECOVERY ACCESSES: "
				.. #p.AccessLog,
			{ "DELETED RECORDS", "BACK" }
	elseif page == "Recovery" then
		return "DELETED RECORD RECOVERY",
			p.Recovered and "Recovered. Your employee number remains in the access log."
				or p.RecoveryAt and "Recovering... Check after six seconds. The access log cannot be erased."
				or "Recovery takes six seconds and logs your employee number. "
					.. (
						p.Policy.RecoveryForbidden and "TONIGHT: RECOVERY IS PROHIBITED."
						or "Continue only if you want to investigate."
					),
			{ p.Recovered and "OPEN RECORD" or p.RecoveryAt and "CHECK RECOVERY" or "START RECOVERY", "BACK" }
	elseif page == "Archive" then
		return "RECOVERED RECORD",
			p.Evidence and p.Evidence.Discovery
				or "Deleted shopping list: bread, tea, replacement kettle. Nothing else recovered.",
			{ "BACK TO PHONE" }
	elseif page == "RestoredRecording" then
		return "SPEAKER RESTORED",
			"The speaker works. There is a saved voice message.",
			{ "PLAY MESSAGE", "LEAVE IT PRIVATE" }
	elseif page == "RestoredKeypad" then
		return "KEYPAD RESTORED",
			"The keys work. Saved call history is now accessible.",
			{ "OPEN CALL HISTORY", "LEAVE IT PRIVATE" }
	elseif page == "Ringing" then
		return "BATTERY RESTORED / INCOMING CALL", "The device powers on. HOME is calling.", { "ANSWER", "IGNORE" }
	elseif page == "Incoming" then
		return "HOME / CONNECTED",
			p.Evidence and p.Evidence.Message or "Can you tell them to bring bread home? This is the third reminder.",
			{ "HANG UP" }
	end
	error("Unknown device page: " .. tostring(page))
end
function Records.Snapshot(p)
	local title, hint, labels = menu(p)
	return {
		Kind = "Phone",
		Title = title,
		Hint = hint,
		Labels = labels,
		Revision = p.Revision,
		Feedback = p.Feedback,
		Progress = p.Progress,
		Installed = p.Installed,
	}
end
function Records.ReadPage(p)
	local page = p.Page
	if page == "Contacts" or page == "CallHistory" then
		p.KnownNumbers[p.ContactNumber] = "Home"
	end
	if page == "Archive" and p.DiscoveryNumber then
		p.KnownNumbers[p.DiscoveryNumber] = "Archive"
	end
	if page == "Recording" or page == "Incoming" or page == "Archive" or page == "CallHistory" then
		if not p.Seen[page] then
			p.Reads += 1
			p.Seen[page] = true
		end
		if p.Evidence then
			p.Discovered = true
		end
	end
end
function Records.Input(p, move, revision, now)
	if revision ~= p.Revision then
		return false, false, "PuzzleChanged"
	end
	local _, _, labels = menu(p)
	if type(move) ~= "number" or move % 1 ~= 0 or not labels[move] then
		return false, false, "InvalidInput"
	end
	local page, done = p.Page, false
	p.Feedback = nil
	if page == "Home" then
		if move == 6 then
			if p.UpdateRequired and not p.Installed and not p.SkipApproved then
				return false, false, "ProgramRequired"
			end
			done = true
		else
			p.Page = ({ "Program", "CallHistory", "Contacts", "Recordings", "Service" })[move]
		end
	elseif page == "Program" then
		if move == 1 and not p.Installed then
			if not p.InstallAt then
				p.InstallAt = now + 2
			elseif now < p.InstallAt then
				return false, false, "InstallingProgram"
			else
				p.Installed, p.Progress = true, 1
			end
		elseif move == 2 then
			p.Page = "Permissions"
		elseif move == 3 then
			if p.Installed then
				return false, false, "ProgramInstalled"
			end
			if p.SoftwareDecisionResolved then
				return false, false, "TeamDecisionFinal"
			end
			p.Page = p.UpdateRequired and "Skip" or "Home"
		elseif move == 4 then
			p.Page = "Home"
		end
	elseif page == "Skip" then
		if move == 1 and not p.Tutorial then
			p.RequestSkip, done = true, true
		else
			p.Page = "Program"
		end
	elseif page == "Permissions" then
		p.Page = "Program"
	elseif page == "CallHistory" or page == "Service" then
		p.Page = move == 1 and "Recovery" or "Home"
	elseif page == "Recordings" then
		p.Page = move == 1 and "Recording" or "Home"
	elseif page == "RestoredRecording" then
		p.Page = move == 1 and "Recording" or "Home"
	elseif page == "RestoredKeypad" then
		p.Page = move == 1 and "CallHistory" or "Home"
	elseif page == "Ringing" then
		p.Page = move == 1 and "Incoming" or "Home"
		if move == 1 then
			p.Answered += 1
		end
	elseif page == "Recovery" then
		if move == 2 then
			p.Page = "Home"
		elseif p.Recovered then
			p.Page = "Archive"
		elseif not p.RecoveryAt then
			p.RecoveryAt = now + 6
			table.insert(p.AccessLog, { Employee = p.Employee, At = now })
			if p.Policy.RecoveryForbidden then
				p.Violations += 1
			end
		elseif now < p.RecoveryAt then
			return false, false, "PleaseWait"
		else
			p.Recovered, p.Page = true, "Archive"
		end
	else
		p.Page = "Home"
	end
	Records.ReadPage(p)
	p.Revision += 1
	return true, done
end
-- Contact numbers are revealed through a page, not accepted as arbitrary guesses.
function Records.Dial(p, number)
	local contact = p.KnownNumbers[number]
	if not contact then
		return nil
	end
	if not p.DialedNumbers[number] then
		p.DialedNumbers[number] = true
		p.Calls += 1
		if p.Policy.CallsForbidden then
			p.Violations += 1
		end
	end
	return contact == "Archive" and "Transfer 041? That department does not exist. Stop calling from a government shop."
		or p.Evidence and "Do not tell them I called. If anyone asks, they are still at work."
		or "The repair shop? Please tell them their family is waiting. And remind them about the bread."
end
return Records
