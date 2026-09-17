local Config = {
	ThrowSpeed = 36,
	UpwardBoost = 4,
	ThrowAngularVelocity = Vector3.new(3, 7, -4),
	MaxHoldSeconds = 30,
	AimInterval = 0.05, -- At most 20 changed aim updates per second.
	AimDotThreshold = 0.99999,
	CarryResponsiveness = 24,
	Distance = 8,
	HoldOffset = Vector3.new(0.65, -0.45, -3.2),
	MaxParts = 32,
	MaxSize = 8,
}
function Config.Direction(payload)
	for _, key in ipairs({ "X", "Y", "Z" }) do
		local value = payload[key]
		if type(value) ~= "number" or value ~= value or math.abs(value) > 1.01 then
			return nil
		end
	end
	local direction = Vector3.new(payload.X, payload.Y, payload.Z)
	if direction.Magnitude < 0.9 or direction.Magnitude > 1.1 then
		return nil
	end
	return direction.Unit
end
return table.freeze(Config)
