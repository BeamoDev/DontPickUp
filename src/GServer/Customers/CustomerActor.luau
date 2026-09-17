local Actor = {}
Actor.__index = Actor
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("GShared", 30)
local Templates = require(Shared:WaitForChild("Customers", 30):WaitForChild("CustomerTemplates", 30))
local Animations = require(Shared:WaitForChild("Customers", 30):WaitForChild("CustomerAnimations", 30))
-- Keep the title stable for the same named customer, including return visits.
function Actor.CustomerName(template, name)
	local parent = template and template.Parent
	if
		not template
		or template.Name ~= "Cop"
		or not parent
		or parent.Name ~= "Male"
		or not parent.Parent
		or parent.Parent.Name ~= "Characters"
	then
		return name
	end
	for _, title in ipairs({ "Chief", "Sheriff", "Cop", "Officer" }) do
		if name:sub(1, #title + 1) == title .. " " then
			return name
		end
	end
	local titles = { "Chief", "Sheriff", "Cop" }
	return titles[(string.byte(name, 1) or 0) % #titles + 1] .. " " .. name
end
function Actor.PrepareTemplates(storage)
	local models = Templates.List(storage)
	assert(
		#models > 0,
		"[DPU] ReplicatedStorage.Assets.Characters.Female/Male must contain customer Models (legacy Assets.NPC supported)"
	)
	for index, model in ipairs(models) do
		model:SetAttribute(Templates.Attribute, "npc_" .. index)
		model:SetAttribute(Templates.GenderAttribute, Templates.Gender(model))
	end
	return models
end
function Actor.new(services, folder, frame, config)
	local template = config.Template or Templates.Find(services.ReplicatedStorage, config.AppearanceId)
	assert(template, "[DPU] Customer appearance missing from ReplicatedStorage.Assets.Characters")
	local archivable = template.Archivable
	template.Archivable = true
	local ok, model = pcall(template.Clone, template)
	template.Archivable = archivable
	assert(ok and model, "[DPU] Could not clone customer NPC")
	local gender = Templates.Gender(template)
	local customerName = config.CustomerName and Actor.CustomerName(template, config.CustomerName)
	model.Name = customerName or "Customer"
	model:SetAttribute("DPU_CustomerName", customerName)
	model:SetAttribute(Templates.GenderAttribute, gender)
	for _, name in ipairs({ "InitialPoses", "AnimSaves" }) do
		local item = model:FindFirstChild(name)
		if item then
			item:Destroy()
		end
	end
	for _, tag in ipairs(services.CollectionService:GetTags(model)) do
		services.CollectionService:RemoveTag(model, tag)
	end
	local anchor = model:FindFirstChild("HumanoidRootPart", true)
		or model.PrimaryPart
		or model:FindFirstChildWhichIsA("BasePart", true)
	model.PrimaryPart = anchor
	local connected = { [anchor] = true }
	for _, part in ipairs(anchor:GetConnectedParts(true)) do
		connected[part] = true
	end
	for _, item in ipairs(model:GetDescendants()) do
		for _, tag in ipairs(services.CollectionService:GetTags(item)) do
			services.CollectionService:RemoveTag(item, tag)
		end
		if item:IsA("LuaSourceContainer") or item:IsA("Animator") or item:IsA("Sound") then
			item:Destroy()
		elseif item:IsA("BasePart") then
			item.Anchored = item == anchor or not connected[item]
			item.CanCollide, item.CanTouch = false, false
			item.CanQuery = item.Transparency < 1
		elseif item:IsA("Humanoid") then
			item.DisplayDistanceType, item.AutoRotate = Enum.HumanoidDisplayDistanceType.None, false
		end
	end
	local degrees = template:GetAttribute("CustomerRotation")
	if typeof(degrees) ~= "Vector3" then
		degrees = typeof(config.CustomerRotation) == "Vector3" and config.CustomerRotation or Vector3.new(90, 180, 0)
	end
	local rotation = CFrame.fromOrientation(math.rad(degrees.X), math.rad(degrees.Y), math.rad(degrees.Z))
	model:PivotTo(frame * rotation)
	local bounds, size = model:GetBoundingBox()
	local pivot = model:GetPivot()
	-- Markers sit on the floor; preserve the template's pivot while grounding it.
	local grounded = pivot + Vector3.yAxis * (frame.Position.Y - (bounds.Position.Y - size.Y / 2))
	model:PivotTo(grounded)
	model.Parent = folder
	local driver = Instance.new("CFrameValue")
	driver.Value = grounded
	local self = setmetatable({
		s = services,
		gender = gender,
		walkAnimation = template:GetAttribute("CustomerWalkAnimation") or Animations.Pick(gender, "Walk"),
		idleAnimation = template:GetAttribute("CustomerIdleAnimation") or Animations.Pick(gender, "Idle"),
		model = model,
		driver = driver,
		offset = frame:ToObjectSpace(grounded),
		rotation = rotation,
		heightOffset = grounded.Position.Y - frame.Position.Y,
	}, Actor)
	local head = model:FindFirstChild("Head", true)
	self.target = head and head:IsA("BasePart") and head or anchor
	self.connection = driver:GetPropertyChangedSignal("Value"):Connect(function()
		if model.Parent then
			model:PivotTo(driver.Value)
		end
	end)
	local controller = model:FindFirstChildWhichIsA("Humanoid", true)
		or model:FindFirstChildWhichIsA("AnimationController", true)
	if controller then
		self.animator = Instance.new("Animator")
		self.animator.Parent = controller
	end
	self:Animate()
	return self
end
function Actor:Animate(walking)
	if not self.animator then
		return
	end
	if self.track then
		self.track:Stop(0.15)
		self.track:Destroy()
		self.track = nil
	end
	local animation = Instance.new("Animation")
	animation.AnimationId = "rbxassetid://"
		.. Animations.Get(
			self.gender,
			walking and self.walkAnimation or self.idleAnimation,
			walking and "NormalWalking" or "HappyIdle"
		)
	local ok, track = pcall(self.animator.LoadAnimation, self.animator, animation)
	animation:Destroy()
	if ok then
		self.track = track
		track.Looped = true
		track.Priority = walking and Enum.AnimationPriority.Movement or Enum.AnimationPriority.Idle
		track:Play(0.2, 1, 1)
	end
end
function Actor:MoveTo(frame, seconds)
	if self.destroyed then
		return
	end
	if self.arrived then
		self.arrived:Disconnect()
		self.arrived = nil
	end
	if self.tween then
		self.tween:Cancel()
		self.tween = nil
	end
	local position = self.driver.Value.Position
	local delta = frame.Position - position
	local direction = Vector3.new(delta.X, 0, delta.Z)
	if seconds <= 0 or direction.Magnitude < 0.001 then
		self.driver.Value = frame * self.offset
		self:Animate(false)
		return
	end
	-- With the authored (90, 180, 0) correction, the character faces +X.
	-- Rotate that calibrated heading around world Y, not the imported rig's tilted axes.
	local facing = CFrame.Angles(0, math.atan2(-direction.Z, direction.X), 0) * self.rotation
	self.driver.Value = CFrame.new(position) * facing
	local goal = CFrame.new(frame.Position + Vector3.yAxis * self.heightOffset) * facing
	self:Animate(true)
	self.tween = self.s.TweenService:Create(
		self.driver,
		TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
		{ Value = goal }
	)
	self.arrived = self.tween.Completed:Connect(function(state)
		if state == Enum.PlaybackState.Completed then
			self:Animate(false)
		end
	end)
	self.tween:Play()
end
function Actor:Destroy()
	if self.destroyed then
		return
	end
	self.destroyed = true
	if self.arrived then
		self.arrived:Disconnect()
	end
	if self.tween then
		self.tween:Cancel()
	end
	self.connection:Disconnect()
	if self.track then
		self.track:Stop(0)
		self.track:Destroy()
	end
	self.driver:Destroy()
	self.model:Destroy()
end
return Actor
