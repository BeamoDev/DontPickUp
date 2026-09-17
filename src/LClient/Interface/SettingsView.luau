-- Maintained in common/CommonClient/Interface/SettingsView.luau. Deploy with tools/SyncCommon.ps1.
local View = {}
View.__index = View
local keys = { Music = "MusicEnabled", SFX = "SFXEnabled", CameraShake = "CameraShake" }
function View.Resolve(frame)
	if not frame:IsA("GuiObject") or frame.Name ~= "Settings" then
		return nil
	end
	local content, close = frame:FindFirstChild("Frame"), frame:FindFirstChild("Close")
	if not content or not close or not close:IsA("GuiButton") then
		return nil
	end
	local rows = {}
	for name, key in pairs(keys) do
		local row = content:FindFirstChild(name)
		local toggle = row and row:FindFirstChild("Toggle")
		local ball = toggle and toggle:FindFirstChild("Ball")
		local title = toggle and toggle:FindFirstChild("Title")
		local stroke = toggle and toggle:FindFirstChildWhichIsA("UIStroke")
		if
			not toggle
			or not toggle:IsA("GuiButton")
			or not ball
			or not ball:IsA("GuiObject")
			or not title
			or not title:IsA("TextLabel")
			or not stroke
		then
			return nil
		end
		rows[key] = { toggle = toggle, ball = ball, title = title, stroke = stroke }
	end
	return { frame = frame, close = close, rows = rows }
end
function View.new(nodes, deps)
	local self = setmetatable({ n = nodes, d = deps, connections = {}, saved = {}, tweens = {}, values = {} }, View)
	self.position = nodes.frame.Position
	local function capture(item, properties)
		local record = {}
		for _, property in ipairs(properties) do
			record[property] = item[property]
		end
		self.saved[item] = record
	end
	for key, row in pairs(nodes.rows) do
		capture(row.toggle, { "BackgroundColor3", "AutoButtonColor", "Active" })
		if row.toggle:IsA("ImageButton") then
			self.saved[row.toggle].ImageColor3 = row.toggle.ImageColor3
		end
		capture(row.ball, { "Position" })
		capture(row.title, { "Text", "TextXAlignment" })
		capture(row.stroke, { "Color" })
		row.toggle.AutoButtonColor = false
		table.insert(
			self.connections,
			row.toggle.Activated:Connect(function()
				if self.ready and self:IsOpen() and not self.closing then
					deps.toggle(key)
				end
			end)
		)
	end
	table.insert(
		self.connections,
		nodes.close.Activated:Connect(function()
			self:Close()
		end)
	)
	local ancestor = nodes.frame
	while ancestor and ancestor ~= deps.playerGui do
		local property = ancestor:IsA("GuiObject") and "Visible" or ancestor:IsA("ScreenGui") and "Enabled"
		if property then
			table.insert(
				self.connections,
				ancestor:GetPropertyChangedSignal(property):Connect(function()
					if not self:IsOpen() then
						self:_cancelClose()
						nodes.frame.Position = self.position
					end
					deps.visibility(self:IsOpen())
				end)
			)
		end
		ancestor = ancestor.Parent
	end
	deps.visibility(self:IsOpen())
	return self
end
function View:IsOpen()
	local item = self.n.frame
	if not item:IsDescendantOf(self.d.playerGui) then
		return false
	end
	while item and item ~= self.d.playerGui do
		if item:IsA("GuiObject") and not item.Visible or item:IsA("ScreenGui") and not item.Enabled then
			return false
		end
		item = item.Parent
	end
	return true
end
function View:IsValid()
	if not self.n.frame:IsDescendantOf(self.d.playerGui) then
		return false
	end
	local nodes = View.Resolve(self.n.frame)
	if not nodes or nodes.close ~= self.n.close then
		return false
	end
	for key, row in pairs(nodes.rows) do
		local old = self.n.rows[key]
		if row.toggle ~= old.toggle or row.ball ~= old.ball or row.title ~= old.title or row.stroke ~= old.stroke then
			return false
		end
	end
	return true
end
function View:_tween(item, goal, animate)
	if self.tweens[item] then
		self.tweens[item]:Cancel()
		self.tweens[item] = nil
	end
	if not animate or self.d.reduced() then
		for property, value in pairs(goal) do
			item[property] = value
		end
	else
		local tween =
			self.d.tweens:Create(item, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
		self.tweens[item] = tween
		tween:Play()
	end
end
function View:Render(values, ready, animate)
	self.ready = ready
	for key, row in pairs(self.n.rows) do
		row.toggle.Active = ready
		local enabled = values[key] ~= false
		if self.values[key] ~= enabled then
			self.values[key] = enabled
			row.title.Text = enabled and "ON" or "OFF"
			row.title.TextXAlignment = enabled and Enum.TextXAlignment.Left or Enum.TextXAlignment.Right
			local color = enabled and Color3.fromRGB(85, 171, 84) or Color3.fromRGB(85, 85, 85)
			local goal = { BackgroundColor3 = color }
			if row.toggle:IsA("ImageButton") then
				goal.ImageColor3 = color
			end
			self:_tween(row.toggle, goal, animate)
			self:_tween(row.ball, { Position = UDim2.fromScale(enabled and 0.8 or 0.2, 0.5) }, animate)
			self:_tween(
				row.stroke,
				{ Color = enabled and Color3.fromRGB(121, 255, 114) or Color3.fromRGB(121, 121, 121) },
				animate
			)
		end
	end
end
function View:_cancelClose()
	self.closing = false
	if self.closeConnection then
		self.closeConnection:Disconnect()
		self.closeConnection = nil
	end
	if self.closeTween then
		self.closeTween:Cancel()
		self.closeTween = nil
	end
end
function View:Close()
	if self.closing or not self:IsOpen() then
		return
	end
	self.position = self.n.frame.Position
	self.closing = true
	local function finish()
		self:_cancelClose()
		self.n.frame.Visible = false
		self.n.frame.Position = self.position -- Ready for the owner's next Visible=true.
		self.d.visibility(false)
	end
	if self.d.reduced() then
		finish()
		return
	end
	-- Kingdom Wars' 0.44s Back/In and 18px drop; no scale/layout change.
	self.closeTween = self.d.tweens:Create(
		self.n.frame,
		TweenInfo.new(0.44, Enum.EasingStyle.Back, Enum.EasingDirection.In),
		{ Position = self.position + UDim2.fromOffset(0, 18) }
	)
	self.closeConnection = self.closeTween.Completed:Connect(function(state)
		if state == Enum.PlaybackState.Completed and not self.dead then
			finish()
		end
	end)
	self.closeTween:Play()
end
function View:Destroy()
	if self.dead then
		return
	end
	self.dead = true
	self:_cancelClose()
	for _, connection in ipairs(self.connections) do
		connection:Disconnect()
	end
	for _, tween in pairs(self.tweens) do
		tween:Cancel()
	end
	for item, record in pairs(self.saved) do
		for property, value in pairs(record) do
			item[property] = value
		end
	end
	self.n.frame.Position = self.position
	self.d.visibility(false)
end
return View
