-- Bounded aim query; only a station name is sent. Range and actions remain server-owned.
local Interaction = {}
Interaction.__index = Interaction
function Interaction.new(gui, deps)
	local self =
		setmetatable({ d = deps, connections = {}, blocked = true, raycast = RaycastParams.new() }, Interaction)
	self.highlight = Instance.new("Highlight")
	self.highlight.Name, self.highlight.FillTransparency = "DPU_InteractFocus", 0.9
	self.highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	self.highlight.OutlineColor = Color3.fromRGB(235, 230, 214)
	self.highlight.Enabled, self.highlight.Parent = false, deps.workspace
	self.hint = Instance.new("TextLabel")
	self.hint.Name, self.hint.AnchorPoint = "ObjectAction", Vector2.new(0.5, 0.5)
	self.hint.Position, self.hint.Size = UDim2.fromScale(0.5, 0.66), UDim2.new(0.8, 0, 0, 34)
	self.hint.BackgroundTransparency, self.hint.TextColor3 = 1, Color3.fromRGB(235, 230, 214)
	self.hint.Font, self.hint.TextSize, self.hint.TextWrapped = Enum.Font.Code, 16, true
	self.hint.Visible, self.hint.Parent = false, gui
	table.insert(
		self.connections,
		deps.input.InputBegan:Connect(function(input, processed)
			if processed or self.blocked then
				return
			end
			if
				(
					input.UserInputType == Enum.UserInputType.Touch
					or input.UserInputType == Enum.UserInputType.MouseButton1
				) and not self.touch
			then
				self.touch, self.touchStart = input, input.Position
				self.touchTarget = self:Pick(Vector2.new(input.Position.X, input.Position.Y))
			end
		end)
	)
	table.insert(
		self.connections,
		deps.input.InputEnded:Connect(function(input, processed)
			local tap = input == self.touch and (input.Position - self.touchStart).Magnitude <= 18
			local target = self.touchTarget
			if input == self.touch then
				self.touch, self.touchStart, self.touchTarget = nil, nil, nil
			end
			if processed or self.blocked then
				return
			end
			if tap and target then
				local position = Vector2.new(input.Position.X, input.Position.Y)
				if self:Pick(position) == target then
					self:Activate(position)
				end
			elseif input.KeyCode == Enum.KeyCode.ButtonR2 then
				self:Activate()
			end
		end)
	)
	table.insert(
		self.connections,
		deps.input.WindowFocusReleased:Connect(function()
			self.touch, self.touchStart, self.touchTarget = nil, nil, nil
		end)
	)
	return self
end
function Interaction:Pick(position)
	local camera, character = self.d.workspace.CurrentCamera, self.d.player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not camera or not root then
		return nil
	end
	local ray = position and camera:ScreenPointToRay(position.X, position.Y)
		or camera:ViewportPointToRay(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
	if self.character ~= character then
		self.character = character
		self.raycast.FilterType, self.raycast.FilterDescendantsInstances = Enum.RaycastFilterType.Exclude, { character }
	end
	local hit = self.d.workspace:Raycast(ray.Origin, ray.Direction * 35, self.raycast)
	local item = hit and hit.Instance
	if
		item
		and item:GetAttribute("DPU_Direct")
		and item:GetAttribute("DPU_Enabled")
		and (root.Position - item.Position).Magnitude <= (item:GetAttribute("DPU_Range") or 5)
	then
		return item
	end
	return nil
end
function Interaction:Activate(position)
	local item = self:Pick(position)
	if item then
		self.d.send("Interact", { Station = item:GetAttribute("DPU_Direct") })
	end
end
function Interaction:Update(state, blocked)
	self.blocked = blocked
		or not state.Alive
		or state.Seated
		or state.Focus
		or state.Inspection
		or state.Phase == "Results"
	if self.blocked then
		self.touch, self.touchStart, self.touchTarget = nil, nil, nil
	end
	local gamepad = self.d.input:GetLastInputType().Name:match("^Gamepad") ~= nil
	local pointer = not gamepad and self.d.input:GetMouseLocation() or nil
	local item = not self.blocked and self:Pick(pointer) or nil
	self.highlight.Enabled, self.highlight.Adornee = item ~= nil, item
	self.hint.Visible = item ~= nil
	if item then
		self.hint.Text = (gamepad and "[RT] " or self.d.input.TouchEnabled and "TAP: " or "CLICK: ")
			.. (item:GetAttribute("DPU_Label") or "Use")
	end
end
function Interaction:Destroy()
	for _, connection in ipairs(self.connections) do
		connection:Disconnect()
	end
	self.highlight:Destroy()
	self.hint:Destroy()
end
return Interaction
