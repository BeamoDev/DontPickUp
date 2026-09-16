-- Fit a whole authored model in a relative close-up, including portrait screens.
return function(pivot, bounds, size, viewport, offset, fieldOfView)
	local vertical = math.rad(fieldOfView)
	local aspect = math.max(viewport.X, 1) / math.max(viewport.Y, 1)
	local horizontal = 2 * math.atan(math.tan(vertical / 2) * aspect)
	local distance = math.max(offset.Magnitude, size.Magnitude * 0.55 / math.sin(math.min(vertical, horizontal) / 2))
	local focus = bounds.Position
	local displacement = pivot:VectorToWorldSpace(offset.Unit * distance)
	local back = displacement.Unit
	local horizontalRight = pivot.UpVector:Cross(back)
	local right = horizontalRight.Magnitude > 0.001 and horizontalRight.Unit or pivot.RightVector
	return CFrame.fromMatrix(focus + displacement, right, back:Cross(right).Unit, back), CFrame.new(focus), fieldOfView
end
