local UI = require(script.Parent.Parent.Interface.AuthoredUI)
local SceneStorage = game:GetService("ReplicatedStorage"):WaitForChild("GShared", 30)
local Scene = require(SceneStorage:WaitForChild("World", 30):WaitForChild("SceneReferences", 30))
-- One pooled local viewport. No world camera override, flashing, or gameplay effects.
local Scares = {}
Scares.__index = Scares
function Scares.new(deps, gui)
	local self = setmetatable({ d = deps }, Scares)
	self.frame = UI.Bind("Frame", gui, "Scare", { Visible = false })
	self.viewport = UI.Bind("ViewportFrame", self.frame, "Visitor")
	local camera = self.viewport.CurrentCamera
	if camera == deps.workspace.CurrentCamera then
		camera = nil -- A copied reference must never give scares the world camera.
	end
	camera = camera or self.viewport:FindFirstChildWhichIsA("Camera")
	if camera then
		self.cameraState = { CFrame = camera.CFrame, FieldOfView = camera.FieldOfView }
	else
		-- Cameras created during Play need not be present in the saved GUI copy.
		camera = Instance.new("Camera")
		camera.Name, camera.CFrame, camera.FieldOfView = "DPU_ScareCamera", CFrame.new(0, 0.1, 7), 54
		camera.Parent, self.ownsCamera = self.viewport, true
	end
	self.viewport.CurrentCamera = camera
	self.camera = camera
	self.fallback = UI.Bind("Sound", self.frame, "Impact")
	local ambientParent = self.frame
	if not ambientParent:FindFirstChild("ShopAnomaly") then
		local world = Scene.Find(deps.workspace)
		local copied = world and world:FindFirstChild("ShopAnomaly", true)
		if copied and copied:IsA("Sound") then
			ambientParent = copied.Parent
		end
	end
	self.ambient = UI.Bind("Sound", ambientParent, "ShopAnomaly")
	self.ambient:Stop()
	self.fallback:Stop()
	self.head = UI.Bind("Part", self.viewport)
	self.caption = UI.Bind("TextLabel", self.frame, "Caption", { Text = "" })
	return self
end
function Scares:Clear()
	if self.lunge then
		self.lunge:Cancel()
		self.lunge = nil
	end
	if self.tween then
		self.tween:Cancel()
		self.tween = nil
	end
	if self.sound then
		if self.sound == self.fallback then
			self.sound:Stop()
		else
			self.sound:Destroy()
		end
		self.sound = nil
	end
	self.frame.Visible, self.untilAt = false, nil
end
function Scares:Update(state)
	local now = self.d.workspace:GetServerTimeNow()
	self:_ambient(state, now)
	if self.runId ~= state.RunId then
		self:Clear()
		self.runId, self.seen = state.RunId, nil
	end
	if self.untilAt and (now >= self.untilAt or self.d.menuOpen()) then
		self:Clear()
	end
	if self.untilAt and self.d.reduced() then
		self.viewport.Visible = false
		if self.lunge then
			self.lunge:Cancel()
			self.lunge = nil
		end
		if self.sound then
			if self.sound == self.fallback then
				self.sound:Stop()
			else
				self.sound:Destroy()
			end
			self.sound = nil
		end
	end
	if self.lunge and self.d.shake and not self.d.shake() then
		self.lunge:Cancel()
		self.lunge = nil
		self.camera.CFrame, self.camera.FieldOfView = CFrame.new(0, 0.1, 7), 54
	end
	local scare = state.Scare
	if not scare or scare.Id == self.seen then
		return
	end
	if self.d.menuOpen() then
		self.seen = scare.Id
		return
	end
	-- Server debug announcement precedes the actual hit; wait without consuming the ID.
	if scare.At > now and scare.At - now <= 1 then
		return
	end
	self.seen = scare.Id
	if now - scare.At > 2 or now < scare.At - 1 or self.d.menuOpen() then
		return
	end
	self:Clear()
	local reduced = self.d.reduced()
	self.untilAt = now + (reduced and 1.5 or 0.8)
	self.frame.Visible, self.viewport.Visible = true, not reduced
	self.caption.Text = scare.Fatal and "IT FOUND YOU."
		or scare.Damage and ("YOU WERE HIT.  -" .. scare.Damage .. " HP")
		or scare.Kind == "Signal" and "THAT WAS NOT A BROADCAST."
		or "SOMETHING WAS RIGHT BEHIND YOU."
	self.viewport.ImageTransparency = 0
	if not reduced then
		local variant = math.clamp(scare.Variant or 1, 1, 3)
		local shake = not self.d.shake or self.d.shake()
		local angle = shake and (variant - 2) * 0.16 or 0
		self.head.Color = scare.Kind == "Signal" and Color3.fromRGB(81, 107, 72) or Color3.fromRGB(145, 142, 115)
		self.camera.CFrame = CFrame.new(shake and (variant - 2) * 0.5 or 0, 0.1, 7) * CFrame.Angles(0, 0, angle)
		self.camera.FieldOfView = 54
		if shake then
			self.lunge = self.d.tweens:Create(
				self.camera,
				TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{
					CFrame = CFrame.new(0, -0.1, 4.2) * CFrame.Angles(0, 0, -angle),
					FieldOfView = 43,
				}
			)
			self.lunge:Play()
		end
		self.tween = self.d.tweens:Create(
			self.viewport,
			TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ ImageTransparency = 1 }
		)
		self.tween:Play()
		local folder = self.d.storage:FindFirstChild("Assets")
		local sound = folder and folder:FindFirstChild("ScareSound")
		if sound and sound:IsA("Sound") then
			self.sound = sound:Clone()
			self.sound.Volume = math.min(self.sound.Volume, 0.6) * self.d.volume()
			self.sound.Parent = self.frame
			self.sound:Play()
		else
			self.sound = self.fallback
			self.sound.Volume = 0.55 * self.d.volume()
			self.sound.PlaybackSpeed = 0.55 + variant * 0.08
			self.sound.TimePosition = 0
			self.sound:Play()
		end
	end
end
function Scares:_ambient(state, now)
	local event = state.Event
	local kind = event and event.Minor and (event.Kind == "Knocks" or event.Kind == "DeadAir") and event.Kind
	local key = kind and tostring(state.RunId) .. ":" .. event.Id
	if not key or now >= event.EndsAt or self.d.reduced() or self.d.menuOpen() then
		if self.ambientKey then
			self.ambient:Stop()
			self.ambientKey = nil
		end
		return
	end
	if self.ambientKey ~= key then
		self.ambient:Stop()
		self.ambientKey, self.knock = key, 0
		self.ambient.SoundId = kind == "Knocks" and "rbxasset://sounds/action_jump_land.mp3"
			or "rbxasset://sounds/action_falling.ogg"
		self.ambient.PlaybackSpeed, self.ambient.Looped = kind == "Knocks" and 0.65 or 0.4, kind == "DeadAir"
		local world = Scene.Find(self.d.workspace)
		self.ambient.Parent = world and world:FindFirstChild(kind == "Knocks" and "StaffDoor" or "Radio") or self.frame
		if kind == "DeadAir" then
			self.ambient:Play()
		end
	end
	self.ambient.Volume = (kind == "Knocks" and 0.35 or 0.12) * self.d.volume()
	if kind == "Knocks" then
		local beat = math.floor((now - (event.StartedAt or now)) / 0.55) + 1
		if beat >= 1 and beat <= 3 and beat > self.knock then
			self.knock = beat
			self.ambient.TimePosition = 0
			self.ambient:Play()
		end
	end
end
function Scares:Destroy()
	if self.destroyed then
		return
	end
	self.destroyed = true
	self:Clear()
	self.ambient:Stop()
	if self.cameraState then
		for key, value in pairs(self.cameraState) do
			self.camera[key] = value
		end
	end
	UI.Release(self.ambient)
	UI.Release(self.frame)
	if self.ownsCamera then
		self.camera:Destroy()
	end
end
return Scares
