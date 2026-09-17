-- Run totals stay server-owned and stop changing when this employee dies.
local Stats = {}

function Stats.Reset(member, continuing)
	member.WorkStartedAt = nil
	if not continuing then
		member.WorkSeconds, member.RunRepairs, member.LossStats = 0, 0, nil
	end
end

function Stats.ClockIn(member, now)
	member.WorkStartedAt = member.WorkStartedAt or now
end

function Stats.Stop(member, now)
	if member.WorkStartedAt then
		member.WorkSeconds = (member.WorkSeconds or 0) + math.max(0, now - member.WorkStartedAt)
		member.WorkStartedAt = nil
	end
end

function Stats.Freeze(member, nights, now)
	Stats.Stop(member, now)
	member.LossStats = member.LossStats
		or {
			Nights = nights or 0,
			PhonesFixed = member.RunRepairs or 0,
			TimeWorked = math.floor(member.WorkSeconds or 0),
		}
end

return Stats
