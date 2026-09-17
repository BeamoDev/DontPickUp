local Motion = {}
Motion.__index = Motion
local function ease(t)
	return t * t * t * (t * (t * 6 - 15) + 10)
end
function Motion.new(rig, head)
	local self = setmetatable({ rig = rig, saved = {}, joints = {}, stages = {}, slots = {}, loose = {} }, Motion)
	local set = {}
	for _, part in ipairs(rig.parts) do
		set[part] = true
	end
	for _, part in ipairs(rig.parts) do
		for _, other in ipairs(part:GetConnectedParts(true)) do
			if not set[other] then
				return nil, "ExternallyWelded"
			end
		end
		self.saved[part] = {
			frame = part.CFrame,
			transparency = part.Transparency,
			anchored = part.Anchored,
			collide = part.CanCollide,
			touch = part.CanTouch,
			query = part.CanQuery,
		}
	end
	for _, joint in ipairs(rig.model:GetDescendants()) do
		if joint:IsA("JointInstance") or joint:IsA("WeldConstraint") or joint:IsA("Constraint") then
			-- Never disable a constraint connecting the phone to authored scenery.
			local a, b
			if joint:IsA("Constraint") and not joint:IsA("WeldConstraint") then
				a, b = joint.Attachment0, joint.Attachment1
			else
				a, b = joint.Part0, joint.Part1
			end
			if (a and not a:IsDescendantOf(rig.model)) or (b and not b:IsDescendantOf(rig.model)) then
				return nil, "ExternalConstraint"
			end
			self.joints[joint] = joint.Enabled
		end
	end
	local center = rig.body.Position
	-- The screen can sit above the cover's center; their center-to-center
	-- vector is not the face normal. Use the thin body axis and only its sign.
	local bodySize, bodyFrame = rig.body.Size, rig.body.CFrame
	local front = bodySize.X <= bodySize.Y and bodySize.X <= bodySize.Z and bodyFrame.RightVector
		or bodySize.Y <= bodySize.Z and bodyFrame.UpVector
		or bodyFrame.LookVector
	if front:Dot(rig.screen.Position - rig.keys.BackCover.Position) < 0 then
		front = -front
	end
	local up = bodySize.Y >= bodySize.X and bodySize.Y >= bodySize.Z and bodyFrame.UpVector
		or bodySize.X >= bodySize.Z and bodyFrame.RightVector
		or -bodyFrame.LookVector
	if math.abs(up:Dot(front)) > 0.95 then
		up = bodyFrame.RightVector
	end
	local source = CFrame.lookAt(center, center + front, up)
	local facing = Vector3.new(head.Position.X - center.X, 0, head.Position.Z - center.Z)
	facing = facing.Magnitude > 0.01 and facing.Unit or Vector3.zAxis
	local minimum, maximum =
		Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, part in ipairs(rig.parts) do
		for _, x in ipairs({ -0.5, 0.5 }) do
			for _, y in ipairs({ -0.5, 0.5 }) do
				for _, z in ipairs({ -0.5, 0.5 }) do
					local v = source:PointToObjectSpace(part.CFrame:PointToWorldSpace(part.Size * Vector3.new(x, y, z)))
					minimum, maximum = minimum:Min(v), maximum:Max(v)
				end
			end
		end
	end
	local size = maximum - minimum
	local width, length = math.max(size.X, 0.7), math.max(size.Y, 1)
	local bounds, boundSize = rig.model:GetBoundingBox()
	local tableY = bounds.Position.Y - boundSize.Y / 2
	local workCenter = Vector3.new(center.X, tableY - minimum.Z + 0.04, center.Z)
	local work = CFrame.lookAt(workCenter, workCenter - Vector3.yAxis, -facing)
	local lifted = CFrame.lookAt(
		center + Vector3.yAxis * math.max(1.2, length * 0.4),
		center + Vector3.yAxis * math.max(1.2, length * 0.4) + facing
	)
	local back = lifted * CFrame.Angles(0, math.pi, 0)
	local liftDelta, backDelta, workDelta = lifted * source:Inverse(), back * source:Inverse(), work * source:Inverse()
	self.plane = CFrame.lookAt(workCenter, workCenter - facing, Vector3.yAxis)
	self.half = Vector2.new(width * 2.3, length * 1.2)
	self.snap = math.clamp(math.min(width, length) * 0.24, 0.14, 0.6)
	self.frontView = { Pivot = lifted, Bounds = CFrame.new(lifted.Position), Size = Vector3.new(width, length, size.Z) }
	self.workView = {
		Pivot = self.plane,
		Bounds = CFrame.new(workCenter),
		Size = Vector3.new(self.half.X * 2, 0.2, self.half.Y * 2),
	}
	local home, lift, turn, unscrew, uncover, unseat, layout = {}, {}, {}, {}, {}, {}, {}
	local screwSet = {}
	for index = 1, 4 do
		screwSet[rig.keys["Screw" .. index]] = true
	end
	self.screwSet = screwSet
	for part, saved in pairs(self.saved) do
		home[part], lift[part], turn[part] = saved.frame, liftDelta * saved.frame, backDelta * saved.frame
		unscrew[part] = turn[part] + (screwSet[part] and -back.LookVector * 0.45 or Vector3.zero)
		uncover[part] = unscrew[part]
			+ (part == rig.keys.BackCover and -back.LookVector * math.max(size.Z + 0.5, 0.8) or Vector3.zero)
		unseat[part] = uncover[part]
			+ (part == rig.keys.Battery and back.UpVector * length * 0.6 - back.LookVector * 0.2 or Vector3.zero)
		layout[part] = workDelta * saved.frame
	end
	for key, part in pairs(rig.keys) do
		self.slots[key] = layout[part]
	end
	layout[rig.keys.BackCover] += self.plane.RightVector * -width * 1.4
	layout[rig.keys.Battery] += self.plane.RightVector * width * 1.35
	for index = 1, 4 do
		local part = rig.keys["Screw" .. index]
		local position = self.plane:PointToWorldSpace(Vector3.new((index - 2.5) * width * 0.5, 0.08, length * 0.85))
		layout[part] = CFrame.new(position) * layout[part].Rotation
	end
	for key, part in pairs(rig.keys) do
		self.loose[key] = layout[part]
	end
	local function stage(seconds, label, from, to, screwsFrom, screwsTo, spin)
		table.insert(self.stages, {
			seconds = seconds,
			label = label,
			from = from,
			to = to,
			a = screwsFrom or 0,
			b = screwsTo or 0,
			spin = spin,
			-- Interpolate one body transform, then local offsets, so rotations
			-- never squash the assembled phone or its exposed internal parts.
			localFrom = {},
			localTo = {},
		})
	end
	stage(0.4, "Picking up phone", home, home)
	stage(0.6, "Picking up phone", home, lift)
	stage(0.7, "Turning phone over", lift, turn)
	stage(0.7, "Removing screws", turn, unscrew, 0, 0, true)
	stage(0.25, "Removing screws", unscrew, unscrew, 0, 1)
	stage(0.45, "Removing back cover", unscrew, uncover, 1, 1)
	stage(0.45, "Sliding battery out", uncover, unseat, 1, 1)
	stage(0.7, "Laying out parts", unseat, layout, 1, 0)
	self.duration = 0
	for _, stageData in ipairs(self.stages) do
		self.duration += stageData.seconds
		for part in pairs(self.saved) do
			stageData.localFrom[part] = stageData.from[rig.body]:ToObjectSpace(stageData.from[part])
			stageData.localTo[part] = stageData.to[rig.body]:ToObjectSpace(stageData.to[part])
		end
	end
	return self
end
function Motion:Prepare()
	for joint in pairs(self.joints) do
		joint.Enabled = false
	end
	for part in pairs(self.saved) do
		part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery = true, false, false, true
		part.AssemblyLinearVelocity, part.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
		if self.rig.wires[part] or self.rig.markers[part] then
			part.Transparency = 1
		end
	end
end
function Motion:Advance(elapsed)
	local selected, t = self.stages[#self.stages], 1
	for _, stage in ipairs(self.stages) do
		if elapsed <= stage.seconds then
			selected, t = stage, math.clamp(elapsed / stage.seconds, 0, 1)
			break
		end
		elapsed -= stage.seconds
	end
	local alpha = ease(t)
	local bodyFrame = selected.from[self.rig.body]:Lerp(selected.to[self.rig.body], alpha)
	for part, saved in pairs(self.saved) do
		local frame = bodyFrame * selected.localFrom[part]:Lerp(selected.localTo[part], alpha)
		if self.screwSet[part] then
			if selected.spin then
				frame *= CFrame.Angles(0, 0, alpha * math.pi * 4)
			end
			part.Transparency = saved.transparency
				+ (1 - saved.transparency) * (selected.a + (selected.b - selected.a) * alpha)
		end
		part.CFrame = frame
	end
	return selected.label
end
function Motion:Markers(visible)
	for part in pairs(self.rig.markers) do
		part.Transparency = visible and 0.15 or 1
	end
end
function Motion:Restore(completed)
	for part, saved in pairs(self.saved) do
		if part.Parent then
			part.CFrame = saved.frame
			part.Transparency = completed and self.rig.wires[part] and 0 or saved.transparency
			part.CanCollide, part.CanTouch, part.CanQuery = saved.collide, saved.touch, saved.query
		end
	end
	for joint, enabled in pairs(self.joints) do
		if joint.Parent then
			joint.Enabled = enabled
		end
	end
	for part, saved in pairs(self.saved) do
		if part.Parent then
			part.Anchored = saved.anchored
		end
	end
end
return Motion
