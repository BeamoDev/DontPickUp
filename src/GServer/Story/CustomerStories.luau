-- Story identities and future branches never leave the server in a snapshot.
local Stories = {}
function Stories.Start(run, continuing)
	run.customerStory = continuing and run.customerStory or {}
end
function Stories.Apply(run, order)
	local story = run.customerStory
	if order.Tutorial then
		order.Evidence, order.Sensitive = nil, false
		return
	end
	-- One authored case per night. Ordinary catalog phones retain their humor.
	local case = not run.caseIssued and run.serial >= 3 and run.d.mode() == "Story"
	if not case then
		if order.PuzzleSeed % 20 >= 4 then
			order.Evidence, order.Sensitive, order.Kind = nil, false, "Normal"
		end
		if not order.Evidence and order.PuzzleSeed % 20 == 0 then
			order.Anomaly = ({ "Echo", "WrongEmployee", "QuietBattery", "Duplicate" })[math.floor(order.PuzzleSeed / 20) % 4 + 1]
		end
		if order.Anomaly == "QuietBattery" then
			order.Fault, order.Complaint = "Battery", "Please take the old battery out before we talk."
			order.Requirement = "Replacement BATTERY"
		end
		return
	end
	run.caseIssued = true
	order.CaseId, order.DeviceSerial = "missing_worker", "MW-041"
	order.Fault, order.Kind, order.Sensitive = "Speaker", "Story", true
	order.Device, order.Requirement = "Municipal handset MW-041", "Replacement SPEAKER"
	order.Patience = math.max(order.Patience or 120, 240)
	if not story.Introduced then
		story.Introduced, story.AppearanceId, story.FirstNight = true, order.AppearanceId, run.night
		order.CaseStage = "Origin"
		order.Customer, order.CustomerId = "Mara", "mara_worker"
		order.Complaint = "The speaker stopped working. Please leave the saved message alone."
		order.Line = "If anyone asks, I collected this myself."
		order.Evidence = {
			Id = "missing_worker_message",
			Message = "If they ask, tell them I am still at work.",
			Discovery = "DEPOT TRANSFER 041. The workers listed here never clocked out. Destination: Ministry archive.",
		}
	elseif story.Choice == "Report" then
		order.Customer, order.CustomerId = "Officer Vale", "vale_worker"
		order.Complaint = "This handset was recovered during an inquiry. Have you serviced it before?"
		order.Line = "The owner will not be collecting it. Thank you for your cooperation."
		order.Evidence = {
			Id = "worker_detained",
			Message = "OWNER DETAINED. SOURCE: repair shop report.",
			Discovery = "The report was filed from this shop. MW-041 is now government property.",
		}
		order.GovernmentDevice = true
	else
		order.Customer, order.CustomerId, order.AppearanceId = "Mara", "mara_worker", story.AppearanceId
		order.Complaint = story.Choice and "You kept my message safe. There is something else you should hear."
			or "I came back for that message. Did anybody listen to it?"
		order.Line = "There are other families. They will know this shop can listen."
		order.Evidence = {
			Id = "worker_archive",
			Message = "They are using the security update to listen inside our homes.",
			Discovery = "Archive switchboard: 041984. Ask for transfer 041. Do not give your real name.",
		}
	end
	if not order.CaseStage then
		local chapter = run.night - (story.FirstNight or 1)
		order.CaseStage = "Followup"
		if chapter == 2 then
			order.Customer, order.CustomerId, order.Fault = "Depot clerk", "depot_worker", "Battery"
			order.Complaint = "It will not turn on. This is the handset from transfer 041."
			order.Line = "Those were people on the transfer list. Not equipment."
			order.Evidence = {
				Id = "worker_transfer",
				Message = "MW-041 transferred to archive intake. The owner was still on the line.",
				Discovery = "All municipal repair shops upload to the same archive. Employee and customer microphones are both monitored.",
			}
		elseif chapter == 3 then
			order.Customer, order.CustomerId, order.Fault = "Ministry courier", "archive_courier", "Keypad"
			order.GovernmentDevice = true
			order.Complaint = "The keys do not work. Install today's update before returning it."
			order.Line = "Destroy yesterday's paperwork. Today's version is the correct one."
			order.Evidence = {
				Id = "worker_correction",
				Message = "CORRECTION: transfer 041 never occurred. Replace earlier service records.",
				Discovery = "The old transfer sheet is still here. Its service number matches Mara's handset: MW-041.",
			}
		elseif chapter >= 4 then
			order.Complaint = "One last speaker repair. Listen carefully before you hand this back."
			order.Line = story.Choice == "Report" and "The Ministry thanks you for your continued cooperation."
				or "If that copy survives, they cannot erase all of us."
			order.Evidence = {
				Id = "worker_final_copy",
				Message = "FINAL COPY: archive transfers, names, and the shops that reported them.",
				Discovery = "The names match the phones you repaired. Your own service records are included. This copy can prove what happened.",
			}
		end
		order.Requirement = "Replacement " .. string.upper(order.Fault)
	end
	order.DiscoveryNumber = "041984"
end
function Stories.Decide(run, order, choice)
	if order.CaseId and order.VotePurpose ~= "Software" then
		-- Later choices must not undo the original customer's disappearance.
		if order.CaseStage == "Origin" or not run.customerStory.Choice then
			run.customerStory.Choice = choice
		end
		run.customerStory.LatestChoice = choice
	end
end
return Stories
