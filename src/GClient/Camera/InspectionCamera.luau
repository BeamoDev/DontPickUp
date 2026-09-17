-- Owns the local inspection camera and temporary character freeze.
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
		Anchored = root.Anchored == true,
		AutoRotate = humanoid.AutoRotate,
		Humanoid = humanoid,
		Position = root.Position,
		Model = model,
		Pivot = model:GetPivot(),
		Bounds = bounds,
		Size = size,
		Viewport = camera.ViewportSize,
	}
	-- Freeze before changing camera ownership; keep it frozen through the return.
	root.Anchored = true
	humanoid.AutoRotate = false
	self.saved.BoundsOffset = self.saved.Pivot:ToObjectSpace(bounds)
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
	self:Transition(target, focus, fov)
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

function Inspection:Transition(target, focus, fov, done)
	self:CancelTween()
	local camera = self.saved.Camera
	if self.d.reduced() then
		camera.CFrame, camera.Focus, camera.FieldOfView = target, focus, fov
		if done then
			done()
		end
		return
	end
	self.entering = not self.exiting
	local tween = self.d.tweens:Create(
		camera,
		TweenInfo.new(
			self.d.config.CameraSeconds or self.d.config.TweenSeconds,
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.InOut
		),
		{ CFrame = target, Focus = focus, FieldOfView = fov }
	)
	self.tween = tween
	self.completed = tween.Completed:Connect(function()
		if self.tween ~= tween then
			return
		end
		self.completed:Disconnect()
		self.completed, self.tween, self.entering = nil, nil, false
		if done then
			done()
		end
	end)
	tween:Play()
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
		or saved.Camera.CameraType ~= Enum.CameraType.Scriptable
	then
		self:Close(true)
		return
	end
	for part in pairs(self.hidden) do
		if part.Parent then
			part.LocalTransparencyModifier = 1
		end
	end
	if self.exiting then
		-- TweenService writes the return path each frame; translate that path with
		-- the character so walking out does not return to an obsolete world position.
		local delta = saved.Root.Position - saved.ReturnPosition
		saved.Camera.CFrame += delta
		saved.Camera.Focus += delta
		return
	end
	if
		saved.Humanoid.Sit
		or (self.d.config.IgnoreMovementInput ~= true and saved.Humanoid.MoveDirection.Magnitude > 0.05)
		or (saved.Root.Position - saved.Position).Magnitude > 0.75
		or not saved.Model:IsDescendantOf(self.d.workspace)
		or (self.d.valid and not self.d.valid(saved.Model))
		or self.d.blocked()
		or self.d.input:GetFocusedTextBox()
	then
		self:Close()
		return
	end
	local pivot, viewport = saved.Model:GetPivot(), saved.Camera.ViewportSize
	if (self.d.config.TrackModel ~= false and pivot ~= saved.Pivot) or viewport ~= saved.Viewport then
		saved.Pivot, saved.Viewport = pivot, viewport
		-- Keep the captured drawer bounds stable while drawers slide.
		local bounds = pivot * saved.BoundsOffset
		local frame, focus, fov = self.d.config.CameraFrame(pivot, bounds, saved.Size, viewport)
		self:Transition(frame, focus, fov)
	end
end

function Inspection:Finish()
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
		local character = self.d.player.Character
		local subject = character == saved.Character and saved.Subject
			or (character and character:FindFirstChildOfClass("Humanoid"))
		if self.exiting and character == saved.Character and saved.Root.Parent then
			local delta = saved.Root.Position - saved.Position
			saved.Camera.CFrame, saved.Camera.Focus = saved.Frame + delta, saved.Focus + delta
		end
		if subject then
			saved.Camera.CameraSubject = subject
		end
		saved.Camera.FieldOfView = saved.FOV
		saved.Camera.CameraType = saved.Type
	end
	if saved.Root.Parent then
		saved.Root.Anchored = saved.Anchored
	end
	if saved.Humanoid.Parent then
		saved.Humanoid.AutoRotate = saved.AutoRotate
	end
	self.exiting = false
	if self.d.returning then
		self.d.returning(false, saved.Camera)
	end
end

function Inspection:Close(immediate)
	local saved = self.saved
	if not saved then
		return
	end
	if self.exiting and not immediate then
		return
	end
	if not self.exiting then
		self.d.active(false)
	end
	self.exiting = true
	if self.d.returning then
		self.d.returning(true, saved.Camera)
	end
	saved.ReturnPosition = saved.Root.Position
	local delta = saved.Root.Parent and saved.Root.Position - saved.Position or Vector3.zero
	local target, focus = saved.Frame + delta, saved.Focus + delta
	if
		immediate
		or self.destroyed
		or self.d.workspace.CurrentCamera ~= saved.Camera
		or self.d.player.Character ~= saved.Character
		or saved.Humanoid.Health <= 0
		or saved.Camera.CameraType ~= Enum.CameraType.Scriptable
	then
		if saved.Camera.CameraType == Enum.CameraType.Scriptable then
			saved.Camera.CFrame, saved.Camera.Focus = target, focus
		end
		self:Finish()
		return
	end
	self:Transition(target, focus, saved.FOV, function()
		self:Finish()
	end)
end

function Inspection:Destroy()
	self.destroyed = true
	self:Close(true)
end

return Inspection
