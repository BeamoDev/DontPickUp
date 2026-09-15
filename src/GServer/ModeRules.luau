-- Run progression stays in this reserved server; profiles only store earned outcomes.
local Modes = {}
Modes.StoryNights = 3
local chapters = {
	{
		Title = "THE FIRST SHIFT",
		Text = "You have been assigned to the night repair desk. Fix the phones, install the state package, and get home at dawn. Some customers have messages the government wants erased.",
		Customer = "nina",
	},
	{
		Title = "STATION NINE",
		Text = "Ward Seven was not empty. An overnight transfer passed through Station Nine. Another phone may connect the names. What you reported yesterday is still on file.",
		Customer = "jonas",
	},
	{
		Title = "THE TRANSFER LIST",
		Text = "The names on the discharge list never returned home. Tonight is your last shift. Decide which records survive, then make it to morning. Your choices across all three nights determine your ending.",
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
			Text = "Survive as many nights as you can. Repair phones, maintain supplies and protect each other. Pressure increases each night. Survivors ready up at dawn; dead staff spectate until the run ends.\n\nClock in to begin. Early minutes stay quiet. There is no final story ending in this mode.",
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
