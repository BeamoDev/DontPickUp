local Config = require(script.Parent.MonsterAnimations)
local Actor = {}
Actor.__index = Actor
function Actor.new(viewport)
	local source = viewport:FindFirstChild("ScaryNPC", true)
	if not source or not source:IsA("Model") then
		return nil
	end
	local archivable = source.Archivable
	source.Archivable = true
	local ok, model = pcall(source.Clone, source)
	source.Archivable = archivable
	if not ok or not model then
		return nil
	end
	for _, name in ipairs({ "InitialPoses", "AnimSaves" }) do
		local saved = model:FindFirstChild(name)
		if saved then
			saved:Destroy()
		end
	end
	local root = model:FindFirstChild("RootPart", true)
		or model.PrimaryPart
		or model:FindFirstChildWhichIsA("BasePart", true)
	for _, item in ipairs(model:GetDescendants()) do
		if item:IsA("LuaSourceContainer") or item:IsA("Animator") then
			item:Destroy()
		elseif item:IsA("BasePart") then
			item.Anchored, item.CanCollide, item.CanTouch, item.CanQuery = item == root, false, false, false
		end
	end
	local world = Instance.new("WorldModel")
	world.Name, world.Parent = "ScareWorld", viewport
	model.Parent = world -- Keep the exact authored pose relative to the authored viewport camera.
	local host = model:FindFirstChildWhichIsA("AnimationController", true)
		or model:FindFirstChildWhichIsA("Humanoid", true)
	if not host then
		host = Instance.new("AnimationController")
		host.Parent = model
	end
	local animator = Instance.new("Animator")
	animator.Parent = host
	local self = setmetatable(
		{ world = world, model = model, source = source, parent = source.Parent, animator = animator, tracks = {} },
		Actor
	)
	source.Parent = nil -- Hide the saved rig while the pooled animated copy is displayed.
	return self
end
function Actor:Stop()
	if self.track then
		self.track:Stop(0)
		self.track = nil
	end
end
function Actor:Play()
	self:Stop()
	local index = math.random(1, #Config.Clips)
	if index == self.previous then
		index = index % #Config.Clips + 1
	end
	self.previous = index
	local clip = Config.Clips[index]
	local track = self.tracks[index]
	if not track then
		local animation = Instance.new("Animation")
		animation.AnimationId = "rbxassetid://" .. clip.Id
		local ok, loaded = pcall(self.animator.LoadAnimation, self.animator, animation)
		animation:Destroy()
		if not ok or not loaded then
			if not self.warned then
				warn("[DPU] Scare animation unavailable; check rig and asset permissions.")
				self.warned = true
			end
			return
		end
		track, self.tracks[index] = loaded, loaded
	end
	self.track = track
	track.Looped, track.Priority = clip.Looped == true, Enum.AnimationPriority.Action
	track:Play(0.08)
end
function Actor:Destroy()
	self:Stop()
	for _, track in pairs(self.tracks) do
		track:Destroy()
	end
	self.world:Destroy()
	self.source.Parent = self.parent
end
return Actor
