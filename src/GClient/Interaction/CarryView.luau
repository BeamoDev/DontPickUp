-- Cosmetic owner prediction only. Server parts, validation and launch stay authoritative.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("GShared", 30)
local Query = require(Shared:WaitForChild("Interaction", 30):WaitForChild("InteractionQuery", 30))
local View = {}
View.__index = View
function View.new(item, deps)
	local camera = deps.workspace.CurrentCamera
	local character = deps.player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not camera then
		return nil
	end
	local archivable = item.Archivable
	item.Archivable = true
	local ok, clone = pcall(item.Clone, item)
	item.Archivable = archivable
	if not ok or not clone then
		return nil
	end
	local all = clone:GetDescendants()
	table.insert(all, clone)
	for _, part in ipairs(all) do
		if part:IsA("BasePart") then
			part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery = true, false, false, false
			part.LocalTransparencyModifier = 0
		elseif
			part:IsA("LuaSourceContainer")
			or part:IsA("Sound")
			or part:IsA("Trail")
			or part:IsA("Beam")
			or part:IsA("ParticleEmitter")
		then
			part:Destroy()
		end
	end
	local self = setmetatable({
		clone = clone,
		item = item,
		identity = item:GetAttribute("DPU_ThrowId"),
		character = character,
		camera = camera,
		localFrame = camera.CFrame:ToObjectSpace(item:GetPivot()),
		d = deps,
		saved = {},
		frame = item:GetPivot(),
		velocity = Vector3.zero,
		rotation = camera.CFrame.Rotation:ToObjectSpace(item:GetPivot().Rotation),
		raycast = RaycastParams.new(),
	}, View)
	clone.Name, clone.Parent = "DPU_CarryVisual", deps.workspace
	self.excluded = { character, item, clone }
	all = item:GetDescendants()
	table.insert(all, item)
	for _, part in ipairs(all) do
		if part:IsA("BasePart") then
			self.saved[part] = part.LocalTransparencyModifier
			part.LocalTransparencyModifier = 1
		end
	end
	return self
end
function View:Cast(origin, destination)
	return Query.Cast(self.d.workspace, self.d.collection, origin, destination - origin, self.raycast, self.excluded)
end
function View:Update(direction, dt)
	local camera = self.d.workspace.CurrentCamera
	if camera ~= self.camera or not direction then
		return
	end
	local config = self.d.config
	-- Smooth the local offset, not a world-space point left behind by a turn.
	local target = camera.CFrame:VectorToObjectSpace(direction) * -config.HoldOffset.Z
		+ Vector3.new(config.HoldOffset.X, config.HoldOffset.Y, 0)
	local worldTarget = camera.CFrame:PointToWorldSpace(target)
	if self:Cast(camera.CFrame.Position, worldTarget) then
		return
	end
	local step = math.clamp(dt or 1 / 60, 0, 0.1)
	local rate = config.CarryResponsiveness
	local decay = math.exp(-rate * step)
	local offset = self.localFrame.Position - target
	local spring = self.velocity + offset * rate
	local position = target + (offset + spring * step) * decay
	local localFrame = CFrame.new(position) * self.localFrame.Rotation:Lerp(self.rotation, 1 - decay)
	local frame = camera.CFrame * localFrame
	if self:Cast(camera.CFrame.Position, frame.Position) then
		return
	end
	self.velocity = (self.velocity - spring * (rate * step)) * decay
	self.localFrame, self.frame = localFrame, frame
	self.clone:PivotTo(frame)
end
function View:Release(direction, revision)
	self.released, self.elapsed, self.blend = true, 0, 0
	self.releaseRevision = revision or self.item:GetAttribute("DPU_ThrowRevision")
	self.flightVelocity = direction * self.d.config.ThrowSpeed + Vector3.yAxis * self.d.config.UpwardBoost
	self.predicted = self.frame
end
function View:UpdateRelease(dt)
	if
		self.destroyed
		or not self.item:IsDescendantOf(self.d.workspace)
		or self.d.player.Character ~= self.character
		or self.d.workspace.CurrentCamera ~= self.camera
		or not self.d.collection:HasTag(self.item, "throw")
		or self.item:GetAttribute("DPU_ThrowId") ~= self.identity
		or (self.releaseRevision and (self.item:GetAttribute("DPU_ThrowRevision") or 0) > self.releaseRevision + 1)
	then
		return false
	end
	local humanoid = self.character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 or self.d.blocked() then
		return false
	end
	local step = math.clamp(dt or 1 / 60, 0, 0.1)
	self.elapsed += step
	-- A lost response never leaves an invisible world object behind.
	if self.elapsed >= 0.75 then
		return false
	end
	local config = self.d.config
	if not self.hit then
		local gravity = Vector3.new(0, -self.d.workspace.Gravity, 0)
		local position = self.predicted.Position + self.flightVelocity * step + gravity * (step * step * 0.5)
		local obstruction = self:Cast(self.predicted.Position, position)
		if obstruction then
			self.hit = true -- Await real collision physics; never predict a bounce through scenery.
		else
			self.flightVelocity += gravity * step
			local spin = config.ThrowAngularVelocity
			self.predicted = CFrame.new(position)
				* CFrame.fromAxisAngle(spin.Unit, spin.Magnitude * step)
				* self.predicted.Rotation
		end
	end
	-- Receipt alone can arrive before the replicated launch state.
	if self.accepted and self.item:GetAttribute("DPU_ThrowHeld") == false then
		self.blend = math.min(self.blend + step / 0.18, 1)
	end
	local alpha = self.blend * self.blend * self.blend * (self.blend * (self.blend * 6 - 15) + 10)
	local frame = self.predicted:Lerp(self.item:GetPivot(), alpha)
	self.frame = frame
	self.clone:PivotTo(frame)
	return self.blend < 1
end
function View:Destroy()
	if self.destroyed then
		return
	end
	self.destroyed = true
	for part, value in pairs(self.saved) do
		if part.Parent then
			part.LocalTransparencyModifier = value
		end
	end
	table.clear(self.saved)
	self.clone:Destroy()
end
return View
