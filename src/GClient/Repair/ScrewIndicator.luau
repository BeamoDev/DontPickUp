-- Four lightweight, non-interactive rings. Updated by the existing repair render connection.
local Indicator = {}
function Indicator.new(part)
	local gui = Instance.new("BillboardGui")
	gui.Name, gui.Adornee, gui.Size = "ScrewIndicator", part, UDim2.fromOffset(32, 32)
	gui.AlwaysOnTop, gui.Active = true, false
	local ring = Instance.new("Frame")
	ring.AnchorPoint, ring.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
	ring.Size, ring.BackgroundTransparency, ring.Active = UDim2.fromOffset(24, 24), 1, false
	local corner = Instance.new("UICorner")
	corner.CornerRadius, corner.Parent = UDim.new(1, 0), ring
	local stroke = Instance.new("UIStroke")
	stroke.Thickness, stroke.Color, stroke.Transparency = 1.5, Color3.fromRGB(220, 213, 200), 0.35
	stroke.Parent = ring
	local tick = Instance.new("Frame")
	tick.AnchorPoint, tick.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0)
	tick.Size, tick.BackgroundColor3 = UDim2.fromOffset(5, 3), stroke.Color
	tick.BorderSizePixel, tick.Active, tick.Parent = 0, false, ring
	ring.Parent, gui.Parent = gui, part
	return { gui = gui, ring = ring, stroke = stroke }
end
function Indicator.Update(indicator, spec, dragging, progress, now, reduced)
	indicator.gui.Enabled = not spec.Done and not spec.Hidden
	indicator.ring.Rotation = reduced and 0 or dragging and progress * 360 or (now * 55) % 360
	indicator.stroke.Transparency = dragging and 0 or 0.35
end
return Indicator
