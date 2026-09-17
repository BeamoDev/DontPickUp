-- Short, owned effects. Authored attachments/emitters are never edited.
return function(root, parts, character, world)
	local owned, closed = {}, false
	local function create(class, parent)
		local item = Instance.new(class)
		item.Name, item.Parent = "DPU_ThrowFX", parent
		table.insert(owned, item)
		return item
	end
	local left, right = create("Attachment", root), create("Attachment", root)
	local width = math.clamp(root.Size.X * 0.12, 0.04, 0.12)
	left.Position, right.Position = Vector3.new(-width, 0, 0), Vector3.new(width, 0, 0)
	local trail = create("Trail", root)
	trail.Attachment0, trail.Attachment1 = left, right
	trail.FaceCamera, trail.Lifetime, trail.MinLength = true, 0.18, 0.08
	trail.Color = ColorSequence.new(Color3.new(1, 1, 1))
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
	trail.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) })
	trail.LightEmission, trail.Enabled = 0.15, true
	-- Keep world collisions active while briefly ignoring the thrower's own body.
	local ignores = {}
	for _, body in ipairs(character:GetDescendants()) do
		if body:IsA("BasePart") then
			for _, part in ipairs(parts) do
				local constraint = create("NoCollisionConstraint", root)
				constraint.Part0, constraint.Part1 = part, body
				table.insert(ignores, constraint)
			end
		end
	end
	task.delay(0.35, function()
		if closed then
			return
		end
		for _, constraint in ipairs(ignores) do
			constraint:Destroy()
		end
	end)
	task.delay(0.65, function()
		if not closed then
			trail.Enabled = false
		end
	end)
	local function cleanup()
		if closed then
			return
		end
		closed = true
		for _, item in ipairs(owned) do
			item:Destroy()
		end
	end
	task.delay(1.1, cleanup)
	return cleanup
end
