-- One pooled local viewport. No world camera override, flashing, or gameplay effects.
local Scares = {}
Scares.__index = Scares
local function make(class, parent, props)
	local item = Instance.new(class)
	for key, value in pairs(props) do
		item[key] = value
	end
	item.Parent = parent
	return item
end
function Scares.new(deps, gui)
	local self = setmetatable({ d = deps }, Scares)
	self.frame = make("Frame", gui, {
		Name = "Scare",
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 0.5,
		BorderSizePixel = 0,
		ZIndex = 40,
	})
	self.viewport = make("ViewportFrame", self.frame, {
		Name = "Visitor",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.48),
		Size = UDim2.fromScale(0.9, 0.95),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(130, 132, 109),
		LightColor = Color3.fromRGB(217, 209, 177),
		LightDirection = Vector3.new(-1, -1, -1),
		ZIndex = 41,
	})
	local camera =
		make("Camera", self.viewport, { CFrame = CFrame.lookAt(Vector3.new(0, 0, 6), Vector3.zero), FieldOfView = 48 })
	self.viewport.CurrentCamera = camera
	self.camera = camera
	self.fallback = make("Sound", self.frame, {
		Name = "Impact",
		SoundId = "rbxasset://sounds/impact_explosion_03.mp3",
		Volume = 0.55,
		PlaybackSpeed = 0.65,
		Looped = false,
	})
	self.ambient = make("Sound", self.frame, { Name = "ShopAnomaly", Volume = 0, Looped = false })
	-- Temporary angular face; replace presentation when authored scare assets arrive.
	local specs = {
		{ Vector3.new(2.5, 3.5, 1.5), Vector3.new(0, 0, 0), Color3.fromRGB(115, 119, 95) },
		{ Vector3.new(0.7, 0.45, 0.2), Vector3.new(-0.65, 0.65, 0.82), Color3.fromRGB(7, 9, 6) },
		{ Vector3.new(0.7, 0.45, 0.2), Vector3.new(0.65, 0.65, 0.82), Color3.fromRGB(7, 9, 6) },
		{ Vector3.new(0.15, 0.15, 0.08), Vector3.new(-0.65, 0.64, 0.96), Color3.fromRGB(232, 226, 190) },
		{ Vector3.new(0.15, 0.15, 0.08), Vector3.new(0.65, 0.64, 0.96), Color3.fromRGB(232, 226, 190) },
		{ Vector3.new(0.65, 1.2, 0.25), Vector3.new(0, -0.65, 0.85), Color3.fromRGB(5, 7, 5) },
	}
	for i, spec in ipairs(specs) do
		local piece = make(
			"Part",
			self.viewport,
			{ Size = spec[1], CFrame = CFrame.new(spec[2]), Color = spec[3], Anchored = true }
		)
		if i == 1 then
			self.head = piece
		end
	end
	-- Pooled hood, jaw and uneven teeth give the silhouette depth during the lunge.
	for _, x in ipairs({ -1.45, 1.45 }) do
		make("Part", self.viewport, {
			Size = Vector3.new(0.55, 4.1, 1.8),
			CFrame = CFrame.new(x, -0.1, -0.25) * CFrame.Angles(0, 0, x * 0.1),
			Color = Color3.fromRGB(10, 14, 11),
			Anchored = true,
		})
	end
	make("Part", self.viewport, {
		Size = Vector3.new(3.8, 1.2, 1.8),
		CFrame = CFrame.new(0, -2.4, -0.3),
		Color = Color3.fromRGB(12, 17, 13),
		Anchored = true,
	})
	for i = 1, 5 do
		for _, y in ipairs({ -0.22, -1.05 }) do
			make("Part", self.viewport, {
				Size = Vector3.new(0.10, 0.20 + (i % 2) * 0.09, 0.12),
				CFrame = CFrame.new(-0.28 + (i - 1) * 0.14, y, 1.02),
				Color = Color3.fromRGB(177, 173, 134),
				Anchored = true,
			})
		end
	end
	self.caption = make("TextLabel", self.frame, {
		Name = "Caption",
		Position = UDim2.fromScale(0.08, 0.78),
		Size = UDim2.fromScale(0.84, 0.14),
		BackgroundTransparency = 1,
		Font = Enum.Font.Code,
		TextColor3 = Color3.fromRGB(210, 219, 192),
		TextScaled = true,
		TextWrapped = true,
		ZIndex = 42,
		Text = "",
	})
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
		local angle = (variant - 2) * 0.16
		self.head.Color = scare.Kind == "Signal" and Color3.fromRGB(81, 107, 72) or Color3.fromRGB(145, 142, 115)
		self.camera.CFrame = CFrame.new((variant - 2) * 0.5, 0.1, 7) * CFrame.Angles(0, 0, angle)
		self.camera.FieldOfView = 54
		self.lunge =
			self.d.tweens:Create(self.camera, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				CFrame = CFrame.new(0, -0.1, 4.2) * CFrame.Angles(0, 0, -angle),
				FieldOfView = 43,
			})
		self.lunge:Play()
		self.tween = self.d.tweens:Create(
			self.viewport,
			TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ ImageTransparency = 1 }
		)
		self.tween:Play()
		local folder = self.d.storage:FindFirstChild("DontPickUpTemplates")
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
		local world = self.d.workspace:FindFirstChild("DPU_Prototype")
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
	self:Clear()
	self.ambient:Destroy()
	self.frame:Destroy()
end
return Scares
