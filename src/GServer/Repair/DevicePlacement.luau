-- Runtime devices can use the existing furniture; no generated map anchors are required.
local Placement = {}
local surfaces = {
	RepairPhone = "Bench",
	RepairPhone2 = "Bench2",
	CounterPhone_Bench = "Counter",
	CounterPhone_Bench2 = "Counter",
}
function Placement.Resolve(folder, name, body)
	local anchor = folder:FindFirstChild(name)
	if anchor and (anchor:IsA("Model") or anchor:IsA("BasePart")) then
		return anchor:GetPivot(), anchor
	end
	local surface = folder:FindFirstChild(surfaces[name])
	assert(surface and surface:IsA("BasePart"), "[DPU] Missing phone placement surface " .. tostring(surfaces[name]))
	local mount = surface:FindFirstChild(name .. "Mount")
	if mount and mount:IsA("Attachment") then
		return mount.WorldCFrame
	end
	local frame, size = surface.CFrame, surface.Size
	local halfHeight = (
		math.abs(frame.RightVector.Y) * size.X
		+ math.abs(frame.UpVector.Y) * size.Y
		+ math.abs(frame.LookVector.Y) * size.Z
	) / 2
	local offset = Vector3.zero
	if surfaces[name] == "Counter" then
		local sign = name == "CounterPhone_Bench" and -1 or 1
		for _, axis in ipairs({ frame.RightVector * size.X, frame.UpVector * size.Y, frame.LookVector * size.Z }) do
			local horizontal = Vector3.new(axis.X, 0, axis.Z) * (0.25 * sign)
			if horizontal.Magnitude > offset.Magnitude then
				offset = horizontal
			end
		end
	end
	local thickness = math.min(body.Size.X, body.Size.Y, body.Size.Z)
	local position = frame.Position + offset + Vector3.new(0, halfHeight + thickness / 2 + 0.03, 0)
	local forward = Vector3.new(frame.LookVector.X, 0, frame.LookVector.Z)
	if forward.Magnitude < 0.01 then
		forward = Vector3.new(frame.RightVector.X, 0, frame.RightVector.Z)
	end
	return CFrame.lookAt(position, position + forward.Unit)
end
return Placement
