-- Per-player exposure. Sample once per decision, never once per frame.
local Risk = {}
function Risk.Chance(config, seconds)
	return math.clamp(
		config.BaseChance + math.max(0, seconds - config.GraceSeconds) * config.ChancePerSecond,
		0,
		config.MaxChance
	)
end
function Risk.Step(state, now, outside, canArm, config, random)
	if outside ~= true then
		local threatened, changed = state.ThreatEndsAt ~= nil, state.Since ~= nil
		local escaped = outside == false and threatened
		state.Since, state.NextRoll, state.ThreatEndsAt = nil, nil, nil
		if threatened then
			state.CooldownUntil = now + config.Cooldown
		end
		return escaped and "Escaped" or changed and "Inside" or nil
	end
	if not state.Since then
		state.Since, state.NextRoll = now, now + config.GraceSeconds
		return "Outside"
	end
	if state.ThreatEndsAt then
		if now >= state.ThreatEndsAt then
			state.ThreatEndsAt, state.CooldownUntil, state.NextRoll = nil, now + config.Cooldown, now + config.Cooldown
			return "Attack"
		end
		return nil
	end
	if not canArm or now < state.NextRoll or now < (state.CooldownUntil or 0) then
		return nil
	end
	state.NextRoll = now + config.RollInterval
	if random(1, 100) <= Risk.Chance(config, now - state.Since) then
		state.ThreatEndsAt = now + config.WarningSeconds
		return "Warning"
	end
	return nil
end
return Risk
