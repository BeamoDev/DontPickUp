local Config = {
	ChargeSeconds = 1.5,
	MinSpeed = 28,
	MaxSpeed = 90,
	MaxHoldSeconds = 12,
	Distance = 8,
	HoldOffset = Vector3.new(1.15, 0.35, -2.7),
	MaxParts = 32,
	MaxSize = 8,
}
function Config.Charge(seconds)
	return math.clamp(seconds / Config.ChargeSeconds, 0, 1)
end
function Config.Speed(seconds)
	return Config.MinSpeed + (Config.MaxSpeed - Config.MinSpeed) * Config.Charge(seconds)
end
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
