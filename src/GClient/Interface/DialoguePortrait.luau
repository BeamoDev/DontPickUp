local Shared = game:GetService("ReplicatedStorage"):WaitForChild("GShared", 30)
local Templates = require(Shared:WaitForChild("Customers", 30):WaitForChild("CustomerTemplates", 30))
local Animations = require(Shared:WaitForChild("Customers", 30):WaitForChild("CustomerAnimations", 30))
local Config = require(script.Parent.DialogueConfig)
local Grayscale = require(script.Parent.GrayscaleImage)
local PortraitGrayscale = require(script.Parent.PortraitGrayscale)
local Portrait = {}
Portrait.__index = Portrait
function Portrait.new(viewport, deps)
	local self = setmetatable({
		viewport = viewport,
		d = deps,
		serial = 0,
		connections = {},
		saved = {
			CurrentCamera = viewport.CurrentCamera,
			ImageColor3 = viewport.ImageColor3,
			Ambient = viewport.Ambient,
			LightColor = viewport.LightColor,
			LightDirection = viewport.LightDirection,
		},
	}, Portrait)
	self.world = Instance.new("WorldModel")
	self.world.Name, self.world.Parent = "DPU_DialoguePortrait", viewport
	self.camera = viewport.CurrentCamera or viewport:FindFirstChildWhichIsA("Camera")
	if not self.camera then
		assert(not deps.requireAuthoredCamera, "[DPU] Missing authored " .. viewport:GetFullName() .. ".Camera")
		self.camera = Instance.new("Camera")
		self.camera.Name, self.camera.CFrame, self.camera.FieldOfView =
			"DPU_DialogueCamera", Config.PortraitCameraFrame, Config.PortraitFieldOfView
		self.camera.Parent, self.ownsCamera = viewport, true
	end
	viewport.CurrentCamera = self.camera
	viewport.Ambient = Grayscale.Color(viewport.Ambient)
	viewport.LightColor = Grayscale.Color(viewport.LightColor)
	viewport.ImageColor3 = Color3.new(1, 1, 1)
	for _, signal in ipairs({ deps.player.CharacterAdded, deps.player.CharacterAppearanceLoaded }) do
		table.insert(
			self.connections,
			signal:Connect(function()
				if self.speaker == "You" then
					self:Show("You")
				end
			end)
		)
	end
	return self
end
function Portrait:Source(speaker)
	if speaker == "You" then
		return self.d.player.Character
	end
	return Templates.Find(self.d.storage, self.appearanceId)
end
function Portrait:Animate(name)
	self.animationName = name
	if not self.animator then
		return
	end
	local humanoid = self.model:FindFirstChildWhichIsA("Humanoid", true)
	local id = self.speaker == "You"
			and (humanoid and humanoid.RigType == Enum.HumanoidRigType.R6 and Config.PlayerIdleR6 or Config.PlayerIdleR15)
		or Animations.Get(self.gender, name or Config.DefaultNPCAnimation)
	if self.animationId == id then
		return
	end
	if self.track then
		self.track:Stop(0)
		self.track:Destroy()
		self.track = nil
	end
	if self.animation then
		self.animation:Destroy()
	end
	self.animationId = id
	local animation = Instance.new("Animation")
	animation.AnimationId = "rbxassetid://" .. id
	self.animation = animation
	local ok, track = pcall(self.animator.LoadAnimation, self.animator, animation)
	if not ok then
		warn("[DPU][Dialogue] Could not load portrait animation", id, track)
		return
	end
	self.track = track
	track.Looped = true
	track.Priority = Enum.AnimationPriority.Idle
	track:Play(0.2)
end

function Portrait:Clear()
	self.serial += 1
	self.speaker, self.head = nil, nil
	if self.track then
		self.track:Stop(0)
		self.track:Destroy()
		self.track = nil
	end
	if self.animation then
		self.animation:Destroy()
		self.animation = nil
	end
	self.animator, self.animationId = nil, nil
	if self.grayscale then
		self.grayscale:Destroy()
		self.grayscale = nil
	end
	if self.model then
		self.model:Destroy()
		self.model = nil
	end
end
function Portrait:Show(speaker, animationName, appearanceId)
	self:Clear()
	if self.destroyed then
		return
	end
	self.speaker, self.animationName, self.appearanceId = speaker, animationName, appearanceId
	local serial = self.serial
	task.spawn(function()
		if self.destroyed or serial ~= self.serial then
			return
		end
		local source = self:Source(speaker)
		if not source or not source:IsA("Model") then
			if speaker == "NPC" and not self.warned then
				self.warned = true
				warn("[DPU][Dialogue] Expected customer Models in ReplicatedStorage.Assets.Characters.Female/Male")
			end
			return
		end
		-- Character.Archivable is commonly false. Restore it before any yield.
		local archivable = source.Archivable
		source.Archivable = true
		local ok, clone = pcall(source.Clone, source)
		source.Archivable = archivable
		if not ok or not clone then
			return
		end
		-- Editor pose libraries are not part of the portrait rig.
		for _, name in ipairs({ "InitialPoses", "AnimSaves" }) do
			local item = clone:FindFirstChild(name)
			if item then
				item:Destroy()
			end
		end
		local anchor = clone:FindFirstChild("HumanoidRootPart", true)
			or clone.PrimaryPart
			or clone:FindFirstChildWhichIsA("BasePart", true)
		for _, item in ipairs(clone:GetDescendants()) do
			if
				item:IsA("LuaSourceContainer")
				or item:IsA("Animator")
				or item:IsA("Sound")
				or item:IsA("ParticleEmitter")
				or item:IsA("Trail")
				or item:IsA("Beam")
			then
				item:Destroy()
			elseif item:IsA("BasePart") then
				item.Anchored, item.CanCollide, item.CanTouch, item.CanQuery = item == anchor, false, false, false
				item.LocalTransparencyModifier = 0 -- Undo first-person avatar hiding in the portrait only.
			elseif item:IsA("Humanoid") then
				item.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			end
		end
		if self.destroyed or serial ~= self.serial then
			clone:Destroy()
			return
		end
		self.head = clone:FindFirstChild("Head", true) or anchor
		if not self.head then
			clone:Destroy()
			return
		end
		self.gender = Templates.Gender(source)
		self.model, clone.Parent = clone, self.world
		clone:PivotTo(Config.PortraitTransforms[speaker])
		-- The fixed viewport camera is configured once; speaker swaps only replace the model.
		local host = clone:FindFirstChildWhichIsA("Humanoid", true)
			or clone:FindFirstChildWhichIsA("AnimationController", true)
		if not host then
			host = Instance.new("AnimationController")
			host.Parent = clone
		end
		self.animator = Instance.new("Animator")
		self.animator.Parent = host
		self:Animate(self.animationName)
		self.grayscale = PortraitGrayscale.new(clone, self.d.assets)
	end)
end
function Portrait:Destroy()
	if self.destroyed then
		return
	end
	self.destroyed = true
	self:Clear()
	for _, connection in ipairs(self.connections) do
		connection:Disconnect()
	end
	for key, value in pairs(self.saved) do
		self.viewport[key] = value
	end
	-- nil values do not survive in the property table.
	if self.saved.CurrentCamera == nil then
		self.viewport.CurrentCamera = nil
	end
	self.world:Destroy()
	if self.ownsCamera then
		self.camera:Destroy()
	end
end
return Portrait
