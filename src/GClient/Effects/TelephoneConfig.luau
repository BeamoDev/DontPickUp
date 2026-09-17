local inspectionFrame = require(script.Parent.Parent.Camera.InspectionFrame)
local Config = {
	Distance = 8,
	TweenSeconds = 0.35,
	FieldOfView = 45,
	-- Relative to the model's pivot axes, aimed at the model's bounds center.
	CameraOffset = Vector3.new(0, 2.5, -2.4),
	MaxDigits = 12,
	ControlOrder = table.freeze({
		"Key1",
		"Key2",
		"Key3",
		"Key4",
		"Key5",
		"Key6",
		"Key7",
		"Key8",
		"Key9",
		"Key*",
		"Key0",
		"Key#",
		"KeyClear",
		"Dial",
		"End",
		"KeyClose",
	}),
}

function Config.Key(name)
	local digit = name:match("^Key(%d)$")
	if digit then
		return digit
	end
	return ({ ["Key*"] = "*", ["Key#"] = "#", KeyClear = "Clear", KeyClose = "Close", End = "End", Dial = "Dial" })[name]
end

function Config.CameraFrame(pivot, bounds, size, viewport)
	return inspectionFrame(pivot, bounds, size, viewport, Config.CameraOffset, Config.FieldOfView)
end

return table.freeze(Config)
