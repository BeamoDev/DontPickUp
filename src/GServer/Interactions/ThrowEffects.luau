-- Short, owned effects. Authored attachments/emitters are never edited.
return function(root, charge, parts, character)
	local owned, closed = {}, false
	local function create(class, parent)
		local item = Instance.new(class)
		item.Name, item.Parent = "DPU_ThrowFX", parent
		table.insert(owned, item)
		return item
	end
	local left, right = create("Attachment", root), create("Attachment", root)
	local width = math.clamp(root.Size.X * 0.25, 0.08, 0.35)
	left.Position, right.Position = Vector3.new(-width, 0, 0), Vector3.new(width, 0, 0)
	local trail = create("Trail", root)
	trail.Attachment0, trail.Attachment1 = left, right
	trail.FaceCamera, trail.Lifetime, trail.MinLength = true, 0.18, 0.08
	trail.Color = ColorSequence.new(Color3.fromRGB(242, 234, 210), Color3.fromRGB(165, 176, 182))
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
	trail.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) })
	trail.LightEmission, trail.Enabled = 0.15, true
	local sparks = create("ParticleEmitter", left)
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Rate, sparks.LightEmission = 0, 0.2
	sparks.Color = trail.Color
	sparks.Lifetime, sparks.Speed = NumberRange.new(0.12, 0.28), NumberRange.new(2, 5)
	sparks.SpreadAngle, sparks.Drag = Vector2.new(40, 40), 6
	sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.09), NumberSequenceKeypoint.new(1, 0) })
	sparks.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1) })
	sparks:Emit(6 + math.floor(charge * 6))
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
	task.delay(0.45 + 0.3 * charge, function()
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
