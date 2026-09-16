-- Public, local phone inspection/keypad. No call/reward/story intent exists yet.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("GShared", 30)
local Tags = require(Shared:WaitForChild("Interactions", 30):WaitForChild("InteractionTags", 30))
local Telephone = {}
Telephone.__index = Telephone

function Telephone.new(deps)
	local self = setmetatable(
		{ d = deps, connections = {}, focused = true, digits = "", raycast = RaycastParams.new() },
		Telephone
	)
	local function connect(signal, callback)
		table.insert(self.connections, signal:Connect(callback))
	end
	connect(deps.input.InputBegan, function(input, processed)
		if processed or not self.saved then
			return
		end
		if input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.ButtonB then
			self:Close()
			return
		end
		if not self:Ready() then
			return
		end
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			if self.press then
				return
			end
			self.press, self.start, self.started = input, input.Position, os.clock()
			self.key = self:PickKey(Vector2.new(input.Position.X, input.Position.Y))
		elseif
			input.KeyCode == Enum.KeyCode.DPadLeft
			or input.KeyCode == Enum.KeyCode.DPadRight
			or input.KeyCode == Enum.KeyCode.DPadUp
			or input.KeyCode == Enum.KeyCode.DPadDown
		then
			local step = (input.KeyCode == Enum.KeyCode.DPadLeft and -1)
				or (input.KeyCode == Enum.KeyCode.DPadRight and 1)
				or (input.KeyCode == Enum.KeyCode.DPadUp and -3)
				or 3
			self.selected = (self.selected - 1 + step) % #self.d.config.ControlOrder + 1
			self:Update()
		elseif input.KeyCode == Enum.KeyCode.ButtonR2 or input.KeyCode == Enum.KeyCode.ButtonA then
			self:Activate(self:PickKey())
		else
			local digits = {
				Zero = "0",
				One = "1",
				Two = "2",
				Three = "3",
				Four = "4",
				Five = "5",
				Six = "6",
				Seven = "7",
				Eight = "8",
				Nine = "9",
			}
			local value = digits[(input.KeyCode.Name:gsub("^Keypad", ""))]
			if value then
				self:Enter(value)
			elseif input.KeyCode == Enum.KeyCode.Backspace then
				self:Enter("Backspace")
			elseif input.KeyCode == Enum.KeyCode.Delete then
				self:Enter("Clear")
			elseif input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.KeypadEnter then
				self:Enter("Dial")
			end
		end
	end)
	connect(deps.input.InputEnded, function(input, processed)
		if input ~= self.press then
			return
		end
		local key = self.key
		local tapped = (input.Position - self.start).Magnitude <= 18 and os.clock() - self.started <= 0.6
		self:CancelPress()
		if
			not processed
			and tapped
			and self:Ready()
			and key == self:PickKey(Vector2.new(input.Position.X, input.Position.Y))
		then
			self:Activate(key)
		end
	end)
	connect(deps.input.WindowFocusReleased, function()
		self.focused = false
		self:Close()
	end)
	connect(deps.input.WindowFocused, function()
		self.focused = true
	end)
	connect(deps.player.CharacterAdded, function()
		self:Close()
	end)
	return self
end

function Telephone:CancelPress()
	self.press, self.start, self.key = nil, nil, nil
end

function Telephone:IsTelephone(model)
	return model
		and model:IsA("Model")
		and Tags.Kind(self.d.collection, model) == "Fax"
		and model:IsDescendantOf(self.d.workspace)
end

function Telephone:Target(hit, root)
	local part = hit and hit.Instance
	if not part or (root.Position - hit.Position).Magnitude > self.d.config.Distance then
		return nil
	end
	local model = part.Parent
	while model and model ~= self.d.workspace do
		if self:IsTelephone(model) then
			return model
		end
		model = model.Parent
	end
	return nil
end

function Telephone:Ready()
	return self.saved
		and not self.entering
		and self.focused
		and not self.d.menuOpen()
		and not self.d.input:GetFocusedTextBox()
		and not self.d.modalOpen()
end

function Telephone:Write()
	if self.label and self.label.Parent then
		self.label.Text = self.status or self.digits
	end
end

function Telephone:Enter(value)
	if not self:Ready() then
		return
	end
	if value == "Close" then
		self:Close()
		return
	end
	self.status = nil
	if value == "Clear" or value == "End" then
		self.digits = ""
	elseif value == "Backspace" then
		self.digits = self.digits:sub(1, -2)
	elseif value == "Dial" then
		self.status = #self.digits == 0 and "ENTER NUMBER" or "NOT CONNECTED"
	elseif type(value) == "string" and value:match("^[%d*#]$") and #self.digits < self.d.config.MaxDigits then
		self.digits ..= value
	end
	self:Write()
end

function Telephone:Activate(part)
	if part then
		self:Enter(self.d.config.Key(part.Name))
	end
end

function Telephone:PickKey(position)
	if not self:Ready() then
		return nil
	end
	if self.d.input.PreferredInput == Enum.PreferredInput.Gamepad then
		local key = self.model:FindFirstChild(self.d.config.ControlOrder[self.selected])
		return key and key:IsA("BasePart") and key or nil
	end
	local camera = self.saved.Camera
	local ray = position and camera:ScreenPointToRay(position.X, position.Y)
		or camera:ViewportPointToRay(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
	local hit = self.d.workspace:Raycast(ray.Origin, ray.Direction * 40, self.raycast)
	local part = hit and hit.Instance
	if part and part:IsDescendantOf(self.model) and self.d.config.Key(part.Name) then
		return part
	end
	return nil
end

function Telephone:Open(model)
	if
		self.saved
		or self.destroyed
		or not self:IsTelephone(model)
		or not self.focused
		or self.d.menuOpen()
		or self.d.modalOpen()
	then
		return
	end
	local camera, character = self.d.workspace.CurrentCamera, self.d.player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if
		not camera
		or camera.CameraType ~= Enum.CameraType.Custom
		or not root
		or not humanoid
		or humanoid.Health <= 0
		or humanoid.Sit
	then
		return
	end
	local bounds, size = model:GetBoundingBox()
	if (root.Position - bounds.Position).Magnitude > self.d.config.Distance + size.Magnitude / 2 then
		return
	end
	self.saved = {
		Camera = camera,
		Type = camera.CameraType,
		Subject = camera.CameraSubject,
		CFrame = camera.CFrame,
		Focus = camera.Focus,
		FOV = camera.FieldOfView,
		Character = character,
		Root = root,
		Humanoid = humanoid,
		Position = root.Position,
		Pivot = model:GetPivot(),
		Viewport = camera.ViewportSize,
	}
	self.model, self.digits, self.status, self.selected = model, "", nil, 1
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
	self.characterParts = character.DescendantAdded:Connect(hide)
	self.raycast.FilterType, self.raycast.FilterDescendantsInstances = Enum.RaycastFilterType.Exclude, { character }
	-- Use only the authored label/ancestor chain; no replacement phone screen is generated.
	local inputArea = model:FindFirstChild("InputArea")
	local surface = inputArea and inputArea:FindFirstChild("SurfaceGui")
	local frame = surface and surface:FindFirstChild("Frame")
	local label = frame and frame:FindFirstChild("TextLabel")
	self.visible = {}
	if label and label:IsA("TextLabel") then
		self.label, self.oldText = label, label.Text
		self.visible = {
			{ surface, "Enabled", surface.Enabled },
			{ frame, "Visible", frame.Visible },
			{ label, "Visible", label.Visible },
		}
		for _, spec in ipairs(self.visible) do
			spec[1][spec[2]] = true
		end
		self:Write()
	else
		warn("[DPU][Telephone] Expected InputArea.SurfaceGui.Frame.TextLabel in", model:GetFullName())
	end
	self.d.active(true)
	camera.CameraType = Enum.CameraType.Scriptable
	local target, focus, fov = self.d.config.CameraFrame(self.saved.Pivot, bounds, size, camera.ViewportSize)
	if self.d.reduced() then
		camera.CFrame, camera.Focus, camera.FieldOfView = target, focus, fov
	else
		self.entering = true
		self.tween = self.d.tweens:Create(
			camera,
			TweenInfo.new(self.d.config.TweenSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
			{ CFrame = target, Focus = focus, FieldOfView = fov }
		)
		self.completed = self.tween.Completed:Connect(function()
			self.entering = false
			self.completed:Disconnect()
			self.completed, self.tween = nil, nil
		end)
		self.tween:Play()
	end
	self.frame = self.d.render.RenderStepped:Connect(function()
		self:Check()
	end)
end

function Telephone:Check()
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
		or not self:IsTelephone(self.model)
		or self.d.menuOpen()
		or self.d.modalOpen()
		or not self.focused
		or self.d.input:GetFocusedTextBox()
		or saved.Camera.CameraType ~= Enum.CameraType.Scriptable
	then
		self:Close()
		return
	end
	local pivot, viewport = self.model:GetPivot(), saved.Camera.ViewportSize
	for part in pairs(self.hidden) do
		if part.Parent then
			part.LocalTransparencyModifier = 1
		end
	end
	if pivot ~= saved.Pivot or viewport ~= saved.Viewport then
		self:CancelTween()
		saved.Pivot, saved.Viewport = pivot, viewport
		local bounds, size = self.model:GetBoundingBox()
		saved.Camera.CFrame, saved.Camera.Focus, saved.Camera.FieldOfView =
			self.d.config.CameraFrame(pivot, bounds, size, viewport)
	end
end

function Telephone:CancelTween()
	if self.completed then
		self.completed:Disconnect()
	end
	if self.tween then
		self.tween:Cancel()
	end
	self.completed, self.tween, self.entering = nil, nil, false
end

function Telephone:Update()
	if not self.saved then
		return
	end
	local pointer = self.d.input.PreferredInput == Enum.PreferredInput.KeyboardAndMouse
			and self.d.input:GetMouseLocation()
		or nil
	local part = self:PickKey(pointer)
	if part and not self.highlight then
		local template = self.d.template()
		if template and template:IsA("Highlight") then
			self.highlight = template:Clone()
		end
	end
	if self.highlight then
		self.highlight.Enabled, self.highlight.Adornee, self.highlight.Parent = part ~= nil, part, part
	end
end

function Telephone:Close()
	self:CancelPress()
	self:CancelTween()
	if self.frame then
		self.frame:Disconnect()
		self.frame = nil
	end
	if self.characterParts then
		self.characterParts:Disconnect()
		self.characterParts = nil
	end
	for part, transparency in pairs(self.hidden or {}) do
		if part.Parent then
			part.LocalTransparencyModifier = transparency
		end
	end
	self.hidden = nil
	if self.highlight then
		self.highlight:Destroy()
		self.highlight = nil
	end
	local saved = self.saved
	self.saved, self.model = nil, nil
	if not saved then
		return
	end
	if self.label and self.label.Parent then
		self.label.Text = self.oldText
	end
	for _, spec in ipairs(self.visible) do
		if spec[1].Parent then
			spec[1][spec[2]] = spec[3]
		end
	end
	self.label, self.visible = nil, nil
	if saved.Camera.CameraType == Enum.CameraType.Scriptable then
		saved.Camera.CFrame, saved.Camera.Focus, saved.Camera.FieldOfView = saved.CFrame, saved.Focus, saved.FOV
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

function Telephone:Destroy()
	self.destroyed = true
	self:Close()
	for _, connection in ipairs(self.connections) do
		connection:Disconnect()
	end
end

return Telephone
