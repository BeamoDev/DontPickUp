local UI = require(script.Parent.Parent.Interface.AuthoredUI)
local SceneStorage = game:GetService("ReplicatedStorage"):WaitForChild("GShared", 30)
local Scene = require(SceneStorage:WaitForChild("World", 30):WaitForChild("SceneReferences", 30))
-- Timeclock inspection owns a short-lived close-up, released on every interruption.
local Interaction = {}
Interaction.__index = Interaction
function Interaction.new(deps, gui)
	local self = setmetatable({ d = deps, connections = {}, panels = deps.panels }, Interaction)
	if self.panels and self.panels.clock then
		self.panel = self.panels.clock.object
		if gui:FindFirstChild("Timecard") then
			self.legacy = UI.Bind("Frame", gui, "Timecard", { Visible = false })
		end
	else
		self.panels = nil
		self.panel = UI.Bind("Frame", gui, "Timecard", { Visible = false })
		for _, spec in ipairs({ { "CLOCK IN", "ClockIn" }, { "CLOSE [Q / B]", "CloseFocus" } }) do
			local button = UI.Bind("TextButton", self.panel, spec[2], { Text = spec[1] })
			table.insert(
				self.connections,
				button.Activated:Connect(function()
					self:Submit(spec[2])
				end)
			)
		end
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
function Interaction:Submit(action)
	if
		not self.focus
		or self.dismissed == self.focus.Id
		or not self.panel.Visible
		or self.busy
		or (self.d.isBusy and self.d.isBusy())
	then
		return
	end
	if action == "CloseFocus" then
		self:Dismiss()
		return
	end
	if action == "ClockIn" then
		self.d.send(action, { FocusId = self.focus.Id })
	end
end
function Interaction:SetVisible(visible)
	if self.panels then
		self.panels:UpdateClock(self.state, self.busy, visible)
	else
		self.panel.Visible = visible
	end
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
	self:SetVisible(false)
end
function Interaction:Dismiss()
	if self.focus then
		self.dismissed = self.focus.Id
		self.d.send("CloseFocus", { FocusId = self.focus.Id })
	end
	self:Release()
end
function Interaction:Update(state, busy)
	self.state, self.focus, self.busy = state, state.Focus, busy
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
	local world = Scene.Find(self.d.workspace)
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
		or (state.WorkBlocked == true or state.WorkBlocked == nil and state.Event ~= nil)
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
	self:SetVisible(true)
	if self.d.reduced() then
		if self.saved then
			self:Release()
			self:SetVisible(true)
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
	if self.legacy then
		UI.Release(self.legacy)
	end
	if not self.panels then
		UI.Release(self.panel)
	end
end
return Interaction
