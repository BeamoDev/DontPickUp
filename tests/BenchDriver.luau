-- Deterministic simulated player for end-to-end repair scenarios.
return function(p, now)
	if p.Kind == "Clean" then
		for i, dirt in ipairs(p.Dirt) do
			if dirt > 0 then
				return i
			end
		end
	elseif p.Kind == "Screws" then
		for i, turns in ipairs(p.Turns) do
			if turns < 3 then
				return i
			end
		end
	elseif p.Kind == "Debris" then
		return table.find(p.Removed, false) * 10 + 1
	elseif p.Kind == "Broken" then
		return p.Bad
	elseif p.Kind == "Screen" then
		return p.Phase < 3 and 11 or table.find(p.Clips, false)
	elseif p.Kind == "SIM" then
		return p.Rotation == p.Notch and 11 or 7
	elseif p.Kind == "Fuse" then
		return p.Phase == 1 and 11 or p.Rating * 10 + 1
	elseif p.Kind == "Charger" then
		return p.Port * 10 + 1
	elseif p.Kind == "Sort" or p.Kind == "Assembly" then
		local item = table.find(p.Placed, false)
		return item * 10 + table.find(p.Slots, item)
	elseif p.Kind == "Waves" then
		return p.Values[1] ~= p.Targets[1] and 2 or p.Values[2] ~= p.Targets[2] and 4 or 7
	elseif p.Kind == "Meter" then
		local value = p.Value + (now - p.At) * p.Drift
		return value < 0.4 and 2 or value > 0.57 and 1 or 7
	elseif p.Kind == "Stamp" then
		return p.Retest and 3 or p.Failed and 2 or 1
	end
	return nil
end
