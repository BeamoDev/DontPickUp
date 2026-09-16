local FirstPersonCamera = {}
FirstPersonCamera.__index = FirstPersonCamera

function FirstPersonCamera.new(parent, player, input)
	local self = setmetatable({
		player = player,
		input = input,
		previousMode = player.CameraMode,
		previousMouseIcon = input.MouseIconEnabled,
		previousMouseBehavior = input.MouseBehavior,
	}, FirstPersonCamera)
	-- A visible Modal button lets Roblox release the cursor in first person.
	-- Keep it transparent and non-interactive; never cover the world or task UI.
	local cursor = Instance.new("TextButton")
	cursor.Name = "FreeCursor"
	cursor.Size = UDim2.fromOffset(1, 1)
	cursor.BackgroundTransparency = 1
	cursor.BorderSizePixel = 0
	cursor.Text = ""
	cursor.AutoButtonColor = false
	cursor.Active = false
	cursor.Selectable = false
	cursor.Visible = true
	cursor.Parent = parent
	self.cursor = cursor
	local function updateInput()
		cursor.Modal = input.PreferredInput == Enum.PreferredInput.KeyboardAndMouse
		if cursor.Modal then
			input.MouseBehavior = Enum.MouseBehavior.Default
		end
	end
	self.connection = input:GetPropertyChangedSignal("PreferredInput"):Connect(updateInput)
	player.CameraMode = Enum.CameraMode.LockFirstPerson
	input.MouseIconEnabled = true
	updateInput()
	-- CameraType/CFrame remain owned by Roblox or the station close-up adapters.
	return self
end

function FirstPersonCamera:Destroy()
	if self.destroyed then
		return
	end
	self.destroyed = true
	self.connection:Disconnect()
	self.cursor:Destroy()
	if self.player.CameraMode == Enum.CameraMode.LockFirstPerson then
		self.player.CameraMode = self.previousMode
	end
	self.input.MouseIconEnabled = self.previousMouseIcon
	self.input.MouseBehavior = self.previousMouseBehavior
end

return FirstPersonCamera
