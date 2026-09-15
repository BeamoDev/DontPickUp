-- Server-only pacing. Randomness is sampled at decisions, never every frame/tick.
local Director = {}
Director.__index = Director
local EVENTS = {
	{
		Kind = "Knocks",
		Minor = true,
		Weight = 3,
		Min = 6,
		Max = 9,
		Warning = "Three knocks at the staff door. Nobody is there. Wait for the sound to pass.",
	},
	{
		Kind = "Shadow",
		Minor = true,
		Weight = 3,
		Min = 7,
		Max = 10,
		Warning = "Someone crossed the window. Stay inside and watch.",
	},
	{
		Kind = "DeadAir",
		Minor = true,
		Weight = 2,
		Min = 6,
		Max = 9,
		Warning = "The radio is repeating an employee number. Wait for the signal to clear.",
	},
	{
		Kind = "Blackout",
		Weight = 3,
		Min = 24,
		Max = 30,
		Warning = "POWER FAILURE. Restore the fuse box before the backup light dies.",
	},
	{
		Kind = "Call",
		Weight = 3,
		Min = 22,
		Max = 28,
		Warning = "The disconnected phone is ringing. Silence it. Do not answer.",
	},
	{
		Kind = "Inspection",
		Weight = 2,
		Min = 25,
		Max = 30,
		Warning = "An inspector is outside. Present the repair records at the filing cabinet.",
	},
	{
		Kind = "Visitor",
		Weight = 2,
		Min = 22,
		Max = 28,
		Late = true,
		Warning = "Someone is at the window. Stay in the marked storage shelter until it leaves.",
	},
}
function Director.new(config, random)
	return setmetatable(
		{
			c = config,
			random = random,
			nextAt = config.CalmSeconds + random(0, config.FirstJitter),
			count = 0,
			scares = 0,
			seen = {},
		},
		Director
	)
end
function Director:Next(elapsed, suspicion, busy)
	if busy then
		self.nextAt = math.max(self.nextAt, elapsed + self.c.IntervalMin)
		return nil
	end
	if elapsed < self.nextAt or self.count >= self.c.MaxEvents then
		return nil
	end
	self.nextAt = elapsed + self.random(self.c.IntervalMin, self.c.IntervalMax)
	if self.count > 0 and self.random(1, 100) <= self.c.QuietChance then
		return nil
	end
	local eligible, total = {}, 0
	for _, event in ipairs(EVENTS) do
		if
			event.Kind ~= self.last
			and (not self.seen[event.Kind] or elapsed - self.seen[event.Kind] >= self.c.KindCooldown)
			and (self.count > 0 or event.Minor)
			and (not event.Late or elapsed >= self.c.LethalAfter)
		then
			local weight = event.Weight + (event.Kind == "Inspection" and math.floor(suspicion / 25) or 0)
			total += weight
			table.insert(eligible, { Event = event, Weight = weight })
		end
	end
	if total == 0 then
		return nil
	end
	local roll, chosen = self.random(1, total), nil
	for _, item in ipairs(eligible) do
		roll -= item.Weight
		if roll <= 0 then
			chosen = item.Event
			break
		end
	end
	local result = {
		Kind = chosen.Kind,
		Minor = chosen.Minor == true,
		Warning = chosen.Warning,
		Duration = self.random(chosen.Min, chosen.Max),
		At = elapsed,
	}
	-- The first interruption is a false alarm. Later scares remain optional and capped.
	if self.count > 0 and self.scares < self.c.MaxScares and self.random(1, 100) <= self.c.ScareChance then
		result.Scare = (chosen.Kind == "DeadAir" or chosen.Kind == "Call") and "Signal" or "Visitor"
		result.ScareDelay = self.random(20, 45) / 10
		self.scares += 1
	end
	self.count += 1
	self.last, self.seen[chosen.Kind] = chosen.Kind, elapsed
	return result
end
return Director
