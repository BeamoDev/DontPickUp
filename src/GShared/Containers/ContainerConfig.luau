-- Public presentation/authoring defaults. Only the server accepts an open/close.
local inspectionFrame = require(script.Parent.Parent.Interactions.InspectionFrame)
local Config = {
	OpenOffset = Vector3.new(0, 0, -0.8), -- World Z: 34.989 -> 34.189, relative to each box.
	TweenSeconds = 0.35,
	Distance = 8,
	CameraOffset = Vector3.new(0, 2.8, -3.4),
	CameraSeconds = 0.35,
	FieldOfView = 45,
	IsBox = function(part)
		return part:IsA("BasePart") and part.Name:match("^Box%d*$") ~= nil
	end,
}

function Config.CameraFrame(pivot, bounds, size, viewport)
	-- Fit both closed and open positions; sliding one Box must not reframe the camera.
	local offset = bounds:VectorToObjectSpace(Config.OpenOffset)
	local travel = Vector3.new(math.abs(offset.X), math.abs(offset.Y), math.abs(offset.Z))
	-- Some drawers may already be open when selected; allow travel in either direction.
	return inspectionFrame(pivot, bounds, size + travel * 2, viewport, Config.CameraOffset, Config.FieldOfView)
end

return table.freeze(Config)
