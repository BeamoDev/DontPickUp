-- Run progression stays in this reserved server; profiles only store earned outcomes.
local Modes = {}
Modes.StoryNights = 3
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
		Text = "One more shift. The phones know the routine now. Fix what you can, decide what to report, and get everyone to morning.",
		Customer = "silas",
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
			.. ". Clock in, read the directive, and work together.",
	}
end
function Modes.Customer(mode, night)
	return mode == "Story" and chapters[math.min(night, #chapters)].Customer or nil
end
function Modes.Directive(base, mode, night)
	return base:gsub("NIGHT DIRECTIVE 01", "NIGHT DIRECTIVE " .. string.format("%02d", night))
		.. (mode == "Endless" and "\nENDLESS DUTY: survive until dawn; remaining staff ready up together for the next night." or "\nSTORY DUTY: decisions and discovered records carry through all three nights.")
		.. "\nSERVICE BULLETIN: use each device's own contact count and verification label. Last customer's answers may not work."
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
