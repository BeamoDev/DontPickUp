-- Timeclock inspection owns a short-lived close-up, released on every interruption.
local Interaction = {}
Interaction.__index = Interaction
function Interaction.new(deps, gui)
	local self = setmetatable({ d = deps, connections = {} }, Interaction)
	local panel = Instance.new("Frame")
	panel.Name, panel.Size, panel.Position = "Timecard", UDim2.fromOffset(280, 120), UDim2.new(0.5, -140, 1, -140)
	panel.BackgroundColor3, panel.Visible, panel.ZIndex, panel.Parent = Color3.fromRGB(0, 0, 0), false, 15, gui
	panel.BackgroundTransparency, panel.BorderSizePixel = 0.5, 0
	self.panel = panel
	for i, spec in ipairs({ { "CLOCK IN", "ClockIn" }, { "CLOSE [Q / B]", "CloseFocus" } }) do
		local button = Instance.new("TextButton")
		button.Name, button.Text, button.Size, button.Position =
			spec[2], spec[1], UDim2.new(1, -20, 0, 46), UDim2.fromOffset(10, 10 + (i - 1) * 54)
		button.Font, button.TextSize, button.TextColor3, button.BackgroundColor3 =
			Enum.Font.Code, 17, Color3.fromRGB(235, 235, 235), Color3.fromRGB(0, 0, 0)
		button.BackgroundTransparency, button.BorderSizePixel = 0.5, 0
		button.ZIndex, button.Parent = 16, panel
		table.insert(
			self.connections,
			button.Activated:Connect(function()
				if not self.focus or self.busy then
					return
				end
				local id = self.focus.Id
				if spec[2] == "CloseFocus" then
					self.dismissed = id
					self:Release()
				end
				deps.send(spec[2], { FocusId = id })
			end)
		)
	end
	table.insert(
		self.connections,
		deps.input.InputBegan:Connect(function(input, processed)
			if
				not processed
				and self.focus
				and (input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.ButtonB)
			then
				self:Dismiss()
			end
		end)
	)
	return self
end
function Interaction:Release()
	if self.tween then
		self.tween:Cancel()
		self.tween = nil
	end
	if self.frame then
		self.frame:Disconnect()
		self.frame = nil
	end
	local saved = self.saved
	self.saved = nil
	if saved and saved.Camera.CameraType == Enum.CameraType.Scriptable then
		saved.Camera.CFrame, saved.Camera.Focus, saved.Camera.FieldOfView = saved.CFrame, saved.Focus, saved.FOV
		saved.Camera.CameraSubject, saved.Camera.CameraType = saved.Subject, saved.Type
	end
	self.panel.Visible = false
end
function Interaction:Dismiss()
	if self.focus then
		self.dismissed = self.focus.Id
		self.d.send("CloseFocus", { FocusId = self.focus.Id })
	end
	self:Release()
end
function Interaction:Update(state, busy)
	self.focus, self.busy = state.Focus, busy
	local focus = self.focus
	if not focus then
		if self.saved or self.panel.Visible then
			self:Release()
		end
		return
	end
	local player, camera = self.d.player, self.d.workspace.CurrentCamera
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local world = self.d.workspace:FindFirstChild("DPU_Prototype")
	local station = world and focus and world:FindFirstChild(focus.Station)
	if focus and self.d.menuOpen() then
		self:Dismiss()
		return
	end
	if
		not focus
		or focus.Id == self.dismissed
		or not state.Alive
		or state.Phase == "Results"
		or state.Event
		or not station
		or not root
		or not humanoid
		or humanoid.Health <= 0
		or self.d.menuOpen()
		or self.d.workspace:GetServerTimeNow() >= focus.EndsAt
	then
		self:Release()
		return
	end
	if (root.Position - station.Position).Magnitude > 6 or humanoid.MoveDirection.Magnitude > 0.05 then
		self:Dismiss()
		return
	end
	if self.key ~= focus.Id then
		self:Release()
		self.key = focus.Id
	end
	self.panel.Visible = true
	if self.d.reduced() then
		if self.saved then
			self:Release()
			self.panel.Visible = true
		end
		return
	end
	if self.saved or not camera or camera.CameraType ~= Enum.CameraType.Custom then
		return
	end
	local marker = station:FindFirstChild("InteractionCamera")
	if not marker then
		return
	end
	self.saved = {
		Camera = camera,
		CFrame = camera.CFrame,
		Focus = camera.Focus,
		FOV = camera.FieldOfView,
		Subject = camera.CameraSubject,
		Type = camera.CameraType,
	}
	camera.CameraType = Enum.CameraType.Scriptable
	self.tween = self.d.tweens:Create(
		camera,
		TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ CFrame = marker.WorldCFrame, Focus = station.CFrame, FieldOfView = 48 }
	)
	self.tween:Play()
	self.frame = self.d.render.RenderStepped:Connect(function()
		if
			self.d.workspace.CurrentCamera ~= camera
			or player.Character ~= character
			or not root.Parent
			or not station.Parent
			or humanoid.Health <= 0
			or humanoid.MoveDirection.Magnitude > 0.05
			or self.d.menuOpen()
			or camera.CameraType ~= Enum.CameraType.Scriptable
		then
			self:Dismiss()
		end
	end)
end
function Interaction:Destroy()
	self:Release()
	for _, connection in ipairs(self.connections) do
		connection:Disconnect()
	end
	self.panel:Destroy()
end
return Interaction
