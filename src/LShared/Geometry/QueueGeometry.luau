local Geometry = {}

-- Enter may be a thin floor marker. Include the avatar root's height above the floor.
function Geometry.Contains(cframe, size, position)
	local point = cframe:PointToObjectSpace(position)
	return math.abs(point.X) <= size.X / 2 + 1
		and math.abs(point.Y) <= size.Y / 2 + 4
		and math.abs(point.Z) <= size.Z / 2 + 1
end

return Geometry
