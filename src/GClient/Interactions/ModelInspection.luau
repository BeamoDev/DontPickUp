-- Camera-only inspection. Object input and server mutations stay with their adapters.
local Inspection = {}
Inspection.__index = Inspection

function Inspection.new(deps)
	return setmetatable({ d = deps }, Inspection)
end

function Inspection:Open(model)
	local camera, character = self.d.workspace.CurrentCamera, self.d.player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if
		self.saved
		or self.destroyed
		or not model:IsA("Model")
		or not model:IsDescendantOf(self.d.workspace)
		or not camera
		or camera.CameraType ~= Enum.CameraType.Custom
		or not root
		or not humanoid
		or humanoid.Health <= 0
		or humanoid.Sit
		or self.d.blocked()
		or (self.d.valid and not self.d.valid(model))
	then
		return false
	end
	local bounds, size = model:GetBoundingBox()
	if (root.Position - bounds.Position).Magnitude > self.d.config.Distance + size.Magnitude / 2 then
		return false
	end
	self.saved = {
		Camera = camera,
		Type = camera.CameraType,
		Subject = camera.CameraSubject,
		Frame = camera.CFrame,
		Focus = camera.Focus,
		FOV = camera.FieldOfView,
		Character = character,
		Root = root,
		Humanoid = humanoid,
		Position = root.Position,
		Model = model,
		Pivot = model:GetPivot(),
		Bounds = bounds,
		Size = size,
		Viewport = camera.ViewportSize,
	}
	self.hidden = {}
	local function hide(part)
		if part:IsA("BasePart") and self.hidden[part] == nil then
			self.hidden[part] = part.LocalTransparencyModifier
			part.LocalTransparencyModifier = 1
		end
	end
	for _, part in ipairs(character:GetDescendants()) do
		hide(part)
	end
	self.added = character.DescendantAdded:Connect(hide)
	camera.CameraType = Enum.CameraType.Scriptable
	self.d.active(true)
	local target, focus, fov = self.d.config.CameraFrame(self.saved.Pivot, bounds, size, camera.ViewportSize)
	if self.d.reduced() then
		camera.CFrame, camera.Focus, camera.FieldOfView = target, focus, fov
	else
		self.entering = true
		local tween = self.d.tweens:Create(
			camera,
			TweenInfo.new(self.d.config.CameraSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
			{ CFrame = target, Focus = focus, FieldOfView = fov }
		)
		self.tween = tween
		self.completed = tween.Completed:Connect(function()
			if self.tween ~= tween then
				return
			end
			self.entering, self.tween = false, nil
			self.completed:Disconnect()
			self.completed = nil
		end)
		tween:Play()
	end
	self.frame = self.d.render.RenderStepped:Connect(function()
		self:Check()
	end)
	return true
end

function Inspection:CancelTween()
	if self.completed then
		self.completed:Disconnect()
	end
	if self.tween then
		self.tween:Cancel()
	end
	self.completed, self.tween, self.entering = nil, nil, false
end

function Inspection:Check()
	local saved = self.saved
	if not saved then
		return
	end
	if
		self.d.workspace.CurrentCamera ~= saved.Camera
		or self.d.player.Character ~= saved.Character
		or not saved.Root.Parent
		or saved.Humanoid.Health <= 0
		or saved.Humanoid.Sit
		or saved.Humanoid.MoveDirection.Magnitude > 0.05
		or (saved.Root.Position - saved.Position).Magnitude > 0.75
		or not saved.Model:IsDescendantOf(self.d.workspace)
		or (self.d.valid and not self.d.valid(saved.Model))
		or self.d.blocked()
		or self.d.input:GetFocusedTextBox()
		or saved.Camera.CameraType ~= Enum.CameraType.Scriptable
	then
		self:Close()
		return
	end
	for part in pairs(self.hidden) do
		if part.Parent then
			part.LocalTransparencyModifier = 1
		end
	end
	if saved.Viewport ~= saved.Camera.ViewportSize then
		self:CancelTween()
		saved.Viewport = saved.Camera.ViewportSize
		saved.Camera.CFrame, saved.Camera.Focus, saved.Camera.FieldOfView =
			self.d.config.CameraFrame(saved.Pivot, saved.Bounds, saved.Size, saved.Viewport)
	end
end

function Inspection:Close()
	self:CancelTween()
	if self.frame then
		self.frame:Disconnect()
		self.frame = nil
	end
	if self.added then
		self.added:Disconnect()
		self.added = nil
	end
	for part, value in pairs(self.hidden or {}) do
		if part.Parent then
			part.LocalTransparencyModifier = value
		end
	end
	self.hidden = nil
	local saved = self.saved
	self.saved = nil
	if not saved then
		return
	end
	if saved.Camera.CameraType == Enum.CameraType.Scriptable then
		saved.Camera.CFrame, saved.Camera.Focus, saved.Camera.FieldOfView = saved.Frame, saved.Focus, saved.FOV
		local character = self.d.player.Character
		local subject = character == saved.Character and saved.Subject
			or (character and character:FindFirstChildOfClass("Humanoid"))
		if subject then
			saved.Camera.CameraSubject = subject
		end
		saved.Camera.CameraType = saved.Type
	end
	self.d.active(false)
end

function Inspection:Destroy()
	self.destroyed = true
	self:Close()
end

return Inspection
