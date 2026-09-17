-- Adapt existing gesture descriptors to authored device meshes and sockets.
local View = {}
local function component(phone, name)
	return phone:FindFirstChild(name, true)
end
local function art(spec, part, frame, pose)
	if not part or not part:IsA("BasePart") then
		return
	end
	pose = pose or part.CFrame
	spec.Source = part
	spec.Position = frame:PointToObjectSpace(pose.Position)
	spec.ArtRotation = frame:ToObjectSpace(pose).Rotation
	-- Use projected mesh bounds, not hard-coded old blockout hitboxes.
	local relative = frame:ToObjectSpace(pose)
	local size = part.Size
	local x = math.abs(relative.RightVector.X) * size.X
		+ math.abs(relative.UpVector.X) * size.Y
		+ math.abs(relative.LookVector.X) * size.Z
	local z = math.abs(relative.RightVector.Z) * size.X
		+ math.abs(relative.UpVector.Z) * size.Y
		+ math.abs(relative.LookVector.Z) * size.Z
	spec.Size = Vector3.new(math.max(0.25, x), 0.15, math.max(0.25, z))
end
function View.Adapt(specs, puzzle, phone, frame)
	if not phone:GetAttribute("DPU_DeviceId") or not puzzle.DeviceStage then
		return
	end
	for _, spec in ipairs(specs) do
		if puzzle.Kind == "Screws" then
			local part = component(phone, "Screw" .. spec.Index)
			local removed = puzzle.DeviceStage == "OpenScrews" and puzzle.Turns[spec.Index] > 0
				or puzzle.DeviceStage == "CloseScrews" and puzzle.Turns[spec.Index] == 0
			art(spec, part, frame, part and part:GetAttribute(removed and "DPU_DeviceLoose" or "DPU_DeviceHome"))
		elseif puzzle.Kind == "Screen" then
			local name = puzzle.Component == "BACK COVER" and "BackCover"
				or puzzle.Component == "BATTERY" and "Battery"
				or puzzle.Component == "SPEAKER" and "Speaker"
				or "Keypad"
			local part = component(phone, name)
			if part then
				local home, loose = part:GetAttribute("DPU_DeviceHome"), part:GetAttribute("DPU_DeviceLoose")
				local pose = spec.Role == "Drop" and (puzzle.Phase == 1 and loose or home)
					or (puzzle.Phase == 1 and home or loose)
				art(spec, part, frame, pose)
				spec.Text = ""
			end
		elseif puzzle.Kind == "Probes" and spec.Index <= 3 then
			art(spec, component(phone, ({ "Battery", "Speaker", "Keypad" })[spec.Index]), frame)
		end
	end
end
return View
