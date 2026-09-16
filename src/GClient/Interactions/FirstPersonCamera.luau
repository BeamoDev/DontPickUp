-- Owns cursor policy only; Roblox and the station adapters still own the camera shot.
local FirstPersonCamera = {}
FirstPersonCamera.__index = FirstPersonCamera
local BINDING = "DPU_GameCursor"

function FirstPersonCamera.new(parent, player, input, deps)
	local self = setmetatable({
		player = player,
		input = input,
		d = deps,
		connections = {},
		focused = true,
		manualFree = false,
		previousMode = player.CameraMode,
		previousMouseIcon = input.MouseIconEnabled,
		previousMouseBehavior = input.MouseBehavior,
	}, FirstPersonCamera)
	local overlay = Instance.new("ScreenGui")
	overlay.Name = "DPU_Cursor"
	overlay.ResetOnSpawn = false
	overlay.IgnoreGuiInset = true
	overlay.DisplayOrder = 100
	overlay.Parent = parent.Parent
	self.overlay = overlay
	local dot = Instance.new("Frame")
	dot.Name = "Dot"
	dot.Size = UDim2.fromOffset(6, 6)
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.BackgroundColor3 = Color3.new(1, 1, 1)
	dot.BackgroundTransparency = 0.45
	dot.BorderSizePixel = 0
	dot.Active = false
	dot.Parent = overlay
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = dot
	self.dot = dot
	local toggle = Instance.new("TextButton")
	toggle.Name = "MouseControl"
	toggle.AnchorPoint = Vector2.new(1, 0)
	toggle.Position = UDim2.new(1, -12, 0, 72)
	toggle.Size = UDim2.fromOffset(200, 26)
	toggle.BackgroundColor3 = Color3.new(0, 0, 0)
	toggle.BackgroundTransparency = 0.5
	toggle.BorderSizePixel = 0
	toggle.TextColor3 = Color3.fromRGB(230, 230, 230)
	toggle.TextSize = 13
	toggle.Font = Enum.Font.Code
	toggle.AutoButtonColor = false
	toggle.Selectable = false
	toggle.Parent = parent
	self.toggle = toggle
	local function connect(signal, callback)
		table.insert(self.connections, signal:Connect(callback))
	end
	connect(toggle.Activated, function()
		self:Toggle()
	end)
	connect(input.InputBegan, function(key, processed)
		if not processed and key.KeyCode == Enum.KeyCode.V then
			self:Toggle()
		end
	end)
	connect(input.WindowFocusReleased, function()
		self.focused = false
		self:Step()
	end)
	connect(input.WindowFocused, function()
		self.focused = true
		self:Step()
	end)
	connect(player.CharacterAdded, function()
		self.manualFree = false
		self:Step()
	end)
	player.CameraMode = Enum.CameraMode.LockFirstPerson
	-- Run after Roblox's camera so it cannot relock a repair/menu cursor.
	-- This is one small cursor update: no remotes, raycasts or scene scans.
	deps.render:BindToRenderStep(BINDING, Enum.RenderPriority.Camera.Value + 1, function()
		self:Step()
	end)
	self:Step()
	return self
end

function FirstPersonCamera:Toggle()
	if self.destroyed then
		return
	end
	self:Step()
	if self.keyboardMouse and not self.systemUI and not self.autoFree then
		self.manualFree = not self.manualFree
		self:Step()
	end
end

function FirstPersonCamera:Step()
	if self.destroyed then
		return
	end
	local input = self.input
	local mouse = input.PreferredInput == Enum.PreferredInput.KeyboardAndMouse
	self.systemUI = not self.focused or self.d.menuOpen() or input:GetFocusedTextBox() ~= nil
	self.autoFree = self.d.needsPointer() == true
	self.locked = mouse and not self.systemUI and not self.autoFree and not self.manualFree
	self.toggle.Visible = mouse and not self.systemUI
	self.toggle.Active = self.toggle.Visible and not self.autoFree
	self.toggle.Modal = mouse and not self.locked and not self.systemUI
	self.toggle.Text = self.autoFree and "MOUSE FREE FOR THIS TASK"
		or self.manualFree and "V - LOCK MOUSE"
		or "V - UNLOCK MOUSE"
	self.dot.Visible = mouse and not self.systemUI
	local hovering = self.hovered and self.dot.Visible and not self.autoFree
	if hovering then
		local elapsed = (self.d.clock or os.clock)() - self.hoverStarted
		self.dot.BackgroundTransparency = self.reduceHover and 0.2 or 0.3 + 0.15 * math.cos(elapsed * math.pi * 2 / 1.2)
	else
		self.dot.BackgroundTransparency = 0.45
	end
	if mouse then
		input.MouseBehavior = self.locked and Enum.MouseBehavior.LockCenter or Enum.MouseBehavior.Default
		input.MouseIconEnabled = self.systemUI
		if self.locked then
			self.dot.Position = UDim2.fromScale(0.5, 0.5)
		else
			local position = input:GetMouseLocation()
			self.dot.Position = UDim2.fromOffset(position.X, position.Y)
		end
	elseif self.keyboardMouse then
		-- Hand camera input back to native touch/controller controls.
		input.MouseBehavior = Enum.MouseBehavior.Default
		input.MouseIconEnabled = self.previousMouseIcon
		self.manualFree = false
	end
	self.keyboardMouse = mouse
end

function FirstPersonCamera:IsLocked()
	return self.locked == true
end

function FirstPersonCamera:SetHover(hovered, reduced)
	if hovered and not self.hovered then
		self.hoverStarted = (self.d.clock or os.clock)()
	end
	self.hovered, self.reduceHover = hovered == true, reduced == true
end

function FirstPersonCamera:Destroy()
	if self.destroyed then
		return
	end
	self.destroyed = true
	self.d.render:UnbindFromRenderStep(BINDING)
	for _, connection in ipairs(self.connections) do
		connection:Disconnect()
	end
	self.toggle:Destroy()
	self.overlay:Destroy()
	if self.player.CameraMode == Enum.CameraMode.LockFirstPerson then
		self.player.CameraMode = self.previousMode
	end
	self.input.MouseIconEnabled = self.previousMouseIcon
	self.input.MouseBehavior = self.previousMouseBehavior
end

return FirstPersonCamera
