local Mugshot = require(script.Parent.Mugshot)
local Panels = {}
Panels.__index = Panels

local function child(parent, name, class)
	local value = parent and parent:FindFirstChild(name)
	return value and value:IsA(class) and value or nil
end

local function lowered(position)
	return position + UDim2.fromScale(0, 0.1)
end

local function smaller(size)
	return UDim2.new(size.X.Scale * 0.88, size.X.Offset * 0.88, size.Y.Scale * 0.88, size.Y.Offset * 0.88)
end

function Panels.new(playerGui, options)
	local hud = child(playerGui, "HUD", "ScreenGui")
	local frames = child(hud, "Frames", "GuiObject")
	if not frames then
		return nil -- Older authored places keep their existing briefing/results.
	end
	local self = setmetatable({
		hud = hud,
		frames = frames,
		options = options,
		panels = {},
		connections = {},
		originals = {},
		state = {},
		busy = false,
		background = frames.BackgroundTransparency,
	}, Panels)
	local function remember(object, key)
		table.insert(self.originals, { object, key, object[key] })
	end
	remember(hud, "Enabled")
	remember(hud, "ResetOnSpawn")
	remember(frames, "Visible")
	remember(frames, "BackgroundTransparency")
	hud.ResetOnSpawn = false
	local function bind(name, required)
		local object = child(frames, name, "GuiObject")
		local fields = {}
		for key, class in pairs(required) do
			fields[key] = child(object, key, class)
			if not fields[key] then
				warn("[DPU] Missing HUD.Frames." .. name .. "." .. key .. "; keeping the legacy panel.")
				return nil
			end
		end
		for _, key in ipairs({ "Size", "Position", "Visible" }) do
			remember(object, key)
		end
		for _, field in pairs(fields) do
			if field:IsA("TextLabel") then
				remember(field, "Text")
			elseif field:IsA("GuiButton") then
				remember(field, "Active")
				remember(field, "Selectable")
			end
		end
		local panel =
			{ object = object, fields = fields, size = object.Size, position = object.Position, wanted = false }
		object.Visible = false
		self.panels[name] = panel
		return panel
	end
	self.rules = bind(
		"TonightsRules",
		{ Understood = "GuiButton", Section1 = "TextLabel", Section2 = "TextLabel", Section3 = "TextLabel" }
	)
	self.loss = bind("GameLost", {
		Lobby = "GuiButton",
		Retry = "GuiButton",
		Mugshot = "ImageLabel",
		Nights = "TextLabel",
		PhonesFixed = "TextLabel",
		TimeWorked = "TextLabel",
	})
	local function activate(panel, key, callback)
		table.insert(
			self.connections,
			panel.fields[key].Activated:Connect(function()
				if not self.destroyed and panel.wanted and not self.busy and panel.fields[key].Active then
					callback()
				end
			end)
		)
	end
	if self.rules then
		activate(self.rules, "Understood", function()
			options.understood()
		end)
	end
	if self.loss then
		self.mugshot = Mugshot.new(self.loss.fields.Mugshot, options.userId, options.assets)
		activate(self.loss, "Retry", function()
			if self.state.CanReplay then
				options.act("Replay")
			end
		end)
		activate(self.loss, "Lobby", function()
			if self.state.CanReturn then
				options.act("ReturnLobby")
			end
		end)
	end
	return self
end

function Panels:_cancel(panel)
	if panel.completed then
		panel.completed:Disconnect()
		panel.completed = nil
	end
	if panel.tween then
		panel.tween:Cancel()
		panel.tween = nil
	end
end

function Panels:_show(panel, wanted)
	if not panel or panel.wanted == wanted then
		return
	end
	panel.wanted = wanted
	self:_cancel(panel)
	local object = panel.object
	if wanted then
		self.hud.Enabled, self.frames.Visible = true, true
		if not object.Visible then
			object.Size, object.Position = smaller(panel.size), lowered(panel.position)
		end
		object.Visible = true
	end
	local goals = {
		Size = wanted and panel.size or smaller(panel.size),
		Position = wanted and panel.position or lowered(panel.position),
	}
	local function finish()
		object.Visible = panel.wanted
		if not panel.wanted then
			object.Size, object.Position = panel.size, panel.position
		end
	end
	if self.options.reduced() then
		object.Size, object.Position = goals.Size, goals.Position
		finish()
	else
		panel.tween = self.options.tweens:Create(
			object,
			TweenInfo.new(wanted and 0.35 or 0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
			goals
		)
		panel.completed = panel.tween.Completed:Connect(function()
			self:_cancel(panel)
			finish()
			if self.options.changed then
				self.options.changed()
			end
		end)
		panel.tween:Play()
	end
end

function Panels:Update(state, busy, rulesOpen)
	self.state, self.busy = state, busy == true
	local lost = state.Outcome == "Died"
	self:_show(self.loss, lost)
	self:_show(self.rules, rulesOpen == true and not lost)
	local background = lost and self.loss and 0.2 or self.background
	if self.backgroundGoal ~= background then
		self.backgroundGoal = background
		if self.backgroundTween then
			self.backgroundTween:Cancel()
		end
		if self.options.reduced() then
			self.frames.BackgroundTransparency = background
		else
			self.backgroundTween =
				self.options.tweens:Create(self.frames, TweenInfo.new(0.3), { BackgroundTransparency = background })
			self.backgroundTween:Play()
		end
	end
	local function enable(button, enabled)
		button.Active, button.Selectable = enabled, enabled
	end
	if self.rules then
		enable(self.rules.fields.Understood, not self.busy and self.rules.wanted)
		for index, text in ipairs(state.RuleSections or {}) do
			local label = self.rules.fields["Section" .. index]
			if label then
				label.Text = index .. ". " .. text
			end
		end
	end
	if self.loss then
		local fields = self.loss.fields
		enable(fields.Retry, lost and not self.busy and state.CanReplay == true)
		enable(fields.Lobby, lost and not self.busy and state.CanReturn == true)
		fields.Retry:SetAttribute(
			"DPU_Status",
			state.Replay and "Waiting for team" or state.CanReplay and "Retry" or "Wait for the run to end"
		)
		if lost then
			local stats = state.LossStats or {}
			local seconds = math.max(0, math.floor(stats.TimeWorked or 0))
			fields.Nights.Text = "NIGHTS    " .. tostring(stats.Nights or 0)
			fields.PhonesFixed.Text = "PHONES FIXED    " .. tostring(stats.PhonesFixed or 0)
			fields.TimeWorked.Text = string.format("TIME WORKED    %02d:%02d", math.floor(seconds / 60), seconds % 60)
			self.mugshot:Show()
		end
	end
	return self.rules ~= nil, self.loss ~= nil and lost
end

function Panels:IsOpen()
	for _, panel in pairs(self.panels) do
		if panel.object.Visible then
			return true -- Include the exit tween in input ownership.
		end
	end
	return false
end

function Panels:Destroy()
	self.destroyed = true
	for _, connection in ipairs(self.connections) do
		connection:Disconnect()
	end
	for _, panel in pairs(self.panels) do
		self:_cancel(panel)
	end
	if self.backgroundTween then
		self.backgroundTween:Cancel()
	end
	if self.mugshot then
		self.mugshot:Destroy()
		self.loss.fields.Retry:SetAttribute("DPU_Status", nil)
	end
	for _, entry in ipairs(self.originals) do
		entry[1][entry[2]] = entry[3]
	end
end

return Panels
