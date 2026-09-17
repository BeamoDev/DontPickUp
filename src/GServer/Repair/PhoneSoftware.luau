-- Private device contents and interaction state. Snapshot exposes only the opened page.
local Phone = {}
local Records = require(script.Parent.Parent.Story.DeviceRecords)
function Phone.New(order, night)
	if order.ShopPolicy then
		return Records.New(order, night)
	end
	return {
		Kind = "Phone",
		Revision = 0,
		Progress = 0,
		Page = not order.Tutorial and order.PuzzleSeed % 5 == 0 and "Ringing" or "Home",
		Night = night,
		Customer = order.Customer,
		Evidence = order.Evidence,
		Tutorial = order.Tutorial,
		Seen = {},
		Reads = 0,
		Calls = 0,
		Answered = 0,
		Violations = 0,
		Installed = false,
		EmployeeReport = order.EmployeeReport,
	}
end
local function menu(p)
	local page = p.Page
	if page == "Home" then
		return p.Customer .. " / PHONE",
			"Government rule: install CIVIC WATCH. It copies private calls and messages to the Ministry.\n"
				.. (
					p.Installed and "PROGRAM INSTALLED"
					or p.SkipApproved and "TEAM APPROVED: NO PROGRAM"
					or "PROGRAM NOT INSTALLED"
				),
			{ "INSTALL PROGRAM", "MESSAGES", "CONTACTS", "RECORDINGS", "FINISH", "SKIP PROGRAM" }
	elseif page == "Program" then
		return "CIVIC WATCH / GOVERNMENT UPDATE",
			p.Installed and "Installation complete. The Ministry can now monitor this phone."
				or p.InstallAt and "Copying program... Wait two seconds, then check the installation."
				or "Connect the software cartridge to install the required monitoring program.",
			{ p.Installed and "INSTALLED" or p.InstallAt and "CHECK INSTALLATION" or "CONNECT AND INSTALL", "BACK" }
	elseif page == "Messages" then
		return "MESSAGES",
			"These messages belong to " .. p.Customer .. ". Reading is optional.",
			{ "FROM HOME", "SAVED MESSAGE", "BACK" }
	elseif page == "MessageHome" then
		return "FROM HOME",
			"Please bring bread on your way home. And don't let the repair shop charge you for a new ringtone again.",
			{ "BACK", "HOME" }
	elseif page == "MessageSaved" then
		return "SAVED MESSAGE",
			p.Evidence and p.Evidence.Message
				or "Your appointment is at nine tomorrow. Bring your service card. The kettle is finally working.",
			{ "BACK", "HOME" }
	elseif page == "Contacts" then
		return "CONTACTS",
			"Required pickup calls use the six-digit ticket on the shop fax. These are private contacts.",
			{ "CALL HOME", "CALL WORK", "BACK" }
	elseif page == "CallHome" then
		return "HOME / CONNECTED",
			"Hello? Is that you? You've been working so late. Who is speaking?",
			{ "I'M THE TECHNICIAN", "TAKE A MESSAGE", "HANG UP" }
	elseif page == "CallWork" then
		return "WORK / CONNECTED",
			"Municipal depot. All calls may be recorded. Please tell them tomorrow's shift starts at seven.",
			{ "THANK YOU / HANG UP" }
	elseif page == "Reply" then
		return "HOME",
			p.PassMessage and "Tell them we love them. And remind them about the bread. Thank you for passing that on."
				or "Oh! Please tell them their family is waiting. Good luck fixing that old thing.",
			{ "HANG UP" }
	elseif page == "Recordings" then
		return "RECORDINGS",
			"A personal voice memo is stored on this phone.",
			{
				p.EmployeeReport and "EMPLOYEE FILE" or "PLAY RECORDING",
				"BACK",
			}
	elseif page == "EmployeeFile" then
		local report = p.EmployeeReport
		return "CIVIC WATCH / EMPLOYEE REVIEW",
			"EMPLOYEE: " .. report.Employee .. "\nSTATUS: " .. report.Status .. "\n\nOBSERVED:\n- " .. table.concat(
				report.Observed,
				"\n- "
			) .. "\n\n" .. report.Notice,
			{ "BACK", "HOME" }
	elseif page == "Recording" then
		return "VOICE MEMO / TRANSCRIPT",
			"Remember: collect the ration cards, repair the radio, call home before curfew. Don't forget the bread this time.",
			{ "BACK", "HOME" }
	elseif page == "Ringing" then
		return "INCOMING CALL", "HOME is calling this customer's phone.", { "ANSWER", "IGNORE" }
	elseif page == "Skip" then
		return "SKIP GOVERNMENT PROGRAM?",
			"This breaks the shop rules. Your team must agree. The Ministry may notice the missing update.",
			{ "ASK TEAM TO SKIP", "KEEP WORKING" }
	elseif page == "Archive" then
		return "RECOVERED RECORD",
			p.Evidence and p.Evidence.Discovery
				or "SERVICE RECORD: CIVIC WATCH sends copies of private calls to a Ministry archive. The owner cannot turn it off.",
			{ "BACK TO PHONE" }
	end
	error("Unknown phone page")
end
function Phone.Snapshot(p)
	if p.Direction then
		return Records.Snapshot(p)
	end
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
function Phone.ReadPage(p)
	if p.Direction then
		return Records.ReadPage(p)
	end
	if
		(
			p.Page == "MessageHome"
			or p.Page == "MessageSaved"
			or p.Page == "Recording"
			or p.Page == "EmployeeFile"
			or p.Page == "Archive"
		) and not p.Seen[p.Page]
	then
		p.Seen[p.Page] = true
		p.Reads += 1
		if p.Night >= 2 then
			p.Violations += 1
		end
	end
	if (p.Page == "MessageSaved" or p.Page == "Archive") and p.Evidence then
		p.Discovered = true
	end
end
function Phone.Input(p, move, revision, now)
	if p.Direction then
		return Records.Input(p, move, revision, now)
	end
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
		if move == 5 then
			if not p.Installed and not p.SkipApproved then
				return false, false, "ProgramRequired"
			end
			done = true
		elseif move == 6 and p.DecisionResolved then
			return false, false, "TeamDecisionFinal"
		elseif move == 6 and p.Installed then
			return false, false, "ProgramInstalled"
		else
			p.Page = ({ "Program", "Messages", "Contacts", "Recordings", "Home", "Skip" })[move]
		end
	elseif page == "Program" then
		if move == 2 then
			p.Page = "Home"
		elseif not p.Installed then
			if not p.InstallAt then
				p.InstallAt = now + 2
			elseif now < p.InstallAt then
				return false, false, "InstallingProgram"
			else
				p.Installed, p.Progress, p.Feedback = true, 1, "PROGRAM INSTALLED"
			end
		end
	elseif page == "Messages" then
		p.Page = ({ "MessageHome", "MessageSaved", "Home" })[move]
	elseif page == "MessageHome" or page == "MessageSaved" then
		p.Page = move == 1 and "Messages" or "Home"
	elseif page == "Contacts" then
		p.Page = ({ "CallHome", "CallWork", "Home" })[move]
		if move < 3 then
			p.Calls += 1
			if p.Night >= 3 then
				p.Violations += 1
			end
		end
	elseif page == "CallHome" then
		if move == 3 then
			p.Page = "Contacts"
		else
			p.PassMessage = move == 2 or p.PassMessage
			p.Page = "Reply"
		end
	elseif page == "CallWork" or page == "Reply" then
		p.Page = "Contacts"
	elseif page == "Recordings" then
		p.Page = move == 1 and (p.EmployeeReport and "EmployeeFile" or "Recording") or "Home"
	elseif page == "Recording" or page == "EmployeeFile" then
		p.Page = move == 1 and "Recordings" or "Home"
	elseif page == "Ringing" then
		p.Page = move == 1 and "CallHome" or "Home"
		if move == 1 then
			p.Answered += 1
			if p.Night >= 3 then
				p.Violations += 1
			end
		end
	elseif page == "Skip" then
		if move == 1 and not p.Tutorial then
			p.RequestSkip, done = true, true
		else
			p.Page, p.Feedback = "Home", p.Tutorial and "Training: install the program first." or nil
		end
	elseif page == "Archive" then
		p.Page = "Home"
	end
	Phone.ReadPage(p)
	p.Revision += 1
	return true, done
end
return Phone
