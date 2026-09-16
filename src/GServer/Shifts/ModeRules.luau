-- Run progression stays in this reserved server; profiles only store earned outcomes.
local Modes = {}
Modes.StoryNights = 5
local chapters = {
	{
		Title = "THE FIRST SHIFT",
		Text = "New job. Night shift. Questionable phones. Fix them, follow the posted rules, and make it to 6 AM.",
		Customer = "nina",
	},
	{
		Title = "STATION NINE",
		Text = "You came back. Payroll seems surprised. Fix the phones and watch for the same names. Your earlier choices still count.",
		Customer = "jonas",
	},
	{
		Title = "THE TRANSFER LIST",
		Text = "The phones know the routine now. Fix what you can, decide what to report, and get everyone to morning.",
		Customer = "silas",
	},
	{
		Title = "THE LISTENING ROOM",
		Text = "Every repaired phone is listening. Find out where the recordings go. The Ministry is checking private calls tonight.",
		Customer = "mira",
	},
	{
		Title = "THE LAST REPORT",
		Text = "Last night. The government wants the archive sealed. What you report and what you protect will decide how you leave.",
		Customer = "reed",
	},
}
function Modes.Continue(mode, night, reason, living)
	return reason == "Dawn" and living > 0 and (mode == "Endless" or night < Modes.StoryNights)
end
function Modes.Intro(mode, night)
	if mode == "Endless" then
		return {
			Title = "ENDLESS / NIGHT " .. night,
			Text = "Fix phones. Notice weird things. Reach 6 AM. Survivors can start another night together.\n\nIt gets busier, but the first minutes stay quiet. No final Story ending here.",
		}
	end
	local chapter = chapters[math.min(night, #chapters)]
	return {
		Title = "STORY / " .. chapter.Title,
		Text = chapter.Text
			.. "\n\nNIGHT "
			.. night
			.. " OF "
			.. Modes.StoryNights
			.. ". Clock in, read the rules, and work together.",
	}
end
function Modes.Customer(mode, night)
	return mode == "Story" and chapters[math.min(night, #chapters)].Customer or nil
end
function Modes.Directive(base, mode, night)
	local policy = night >= 2 and "\nTODAY: do not read private messages or recordings."
		or "\nTODAY: you may check messages while testing."
	policy ..= night >= 3 and "\nPRIVATE CALLS: do not call contacts or answer customer calls. Use only the fax for pickup." or "\nPRIVATE CALLS: allowed for testing today."
	return base:gsub("TONIGHT'S RULES 01", "TONIGHT'S RULES " .. string.format("%02d", night))
		.. policy
		.. (mode == "Endless" and "\nENDLESS: reach 6 AM. Everyone still alive can choose to play the next night." or "\nSTORY: your choices and the notes you find still count on the next night.")
		.. "\nREPAIR TIP: follow the instructions on this phone. Each phone can have a different answer."
end
function Modes.Director(base, mode, night)
	local result = table.clone(base)
	local pressure = math.min(night - 1, mode == "Endless" and 10 or 2)
	result.MaxEvents = math.min(8, base.MaxEvents + math.floor(pressure / 2))
	result.IntervalMin = math.max(18, base.IntervalMin - pressure)
	result.IntervalMax = math.max(30, base.IntervalMax - pressure * 2)
	-- Never remove the calm opening, reaction time floor, or personal scare cap.
	return result
end
return Modes
