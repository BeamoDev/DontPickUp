local inspectionFrame = require(script.Parent.InspectionFrame)
local Config = {
	Distance = 8,
	CameraSeconds = 0.35,
	FieldOfView = 45,
	-- A level view from the model's front (-Z), fitted to its bounds.
	CameraOffset = Vector3.new(0, 0, -4),
}
function Config.CameraFrame(pivot, bounds, size, viewport)
	return inspectionFrame(pivot, bounds, size, viewport, Config.CameraOffset, Config.FieldOfView)
end
return table.freeze(Config)
