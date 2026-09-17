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

local function briefingText(text)
	-- Escape server copy before adding our own markup; leave authored TextScaled/layout alone.
	local result = text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
	for _, emphasis in ipairs({
		{ "Clock in", "#356342" },
		{ "read the rules", "#356342" },
		{ "Fix phones", "#356342" },
		{ "6 AM", "#925B25" },
		{ "government", "#8F3D35" },
		{ "Ministry", "#8F3D35" },
		{ "report", "#8F3D35" },
		{ "protect", "#356342" },
	}) do
		result = result:gsub(emphasis[1], '<font color="' .. emphasis[2] .. '"><b>%0</b></font>')
	end
	return result
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
	if child(frames, "ShiftComplete", "GuiObject") then
		self.complete = bind("ShiftComplete", {
			Lobby = "GuiButton",
			NextNight = "GuiButton",
			AnomaliesSpotted = "TextLabel",
			PhonesFixed = "TextLabel",
			TimeWorked = "TextLabel",
		})
		if self.complete then
			local nextLabel = child(self.complete.fields.NextNight, "Label", "TextLabel")
			if nextLabel then
				self.complete.nextLabel = nextLabel
				remember(nextLabel, "Text")
			end
			local nights = child(self.complete.object, "Nights", "TextLabel")
			if nights then
				self.complete.fields.Nights = nights
				remember(nights, "Text")
			end
		end
	end
	if child(frames, "Briefing", "GuiObject") then
		self.briefing = bind("Briefing", { Understood = "GuiButton", Section1 = "TextLabel", Title = "TextLabel" })
		if self.briefing then
			remember(self.briefing.fields.Section1, "RichText")
			self.briefing.fields.Section1.RichText = true
		end
	end
	if child(frames, "ClockIn", "GuiObject") then
		self.clock = bind("ClockIn", {
			Back = "GuiButton",
			Start = "GuiButton",
			Mugshot = "ImageLabel",
			Night = "TextLabel",
			EmployeeName = "TextLabel",
			EmployeeNumber = "TextLabel",
		})
	end
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
	if self.briefing then
		activate(self.briefing, "Understood", function()
			if self.notice and options.noticeUnderstood then
				options.noticeUnderstood()
			elseif options.introUnderstood then
				options.introUnderstood()
			end
		end)
	end
	if self.clock then
		self.clockMugshot = Mugshot.new(self.clock.fields.Mugshot, options.userId, options.assets)
		for key, action in pairs({ Start = "ClockIn", Back = "CloseFocus" }) do
			activate(self.clock, key, function()
				if options.clockAction then
					options.clockAction(action)
				end
			end)
		end
	end
	if self.rules then
		activate(self.rules, "Understood", function()
			options.understood()
		end)
	end
	if self.complete then
		activate(self.complete, "NextNight", function()
			if self.state.CanReplay and not self.state.Replay then
				options.act("Replay")
			end
		end)
		activate(self.complete, "Lobby", function()
			if self.state.CanReturn then
				options.act("ReturnLobby")
			end
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

-- The station controller owns focus/range/lifecycle; this module only presents the card.
function Panels:UpdateClock(state, busy, visible)
	if not self.clock then
		return
	end
	local fields, player = self.clock.fields, self.options.player
	local number = player and player:GetAttribute("DPU_EmployeeNumber")
	local ready = type(number) == "number" and number >= 1000 and number <= 9999 and number % 1 == 0
	fields.EmployeeName.Text = player and player.Name or ""
	fields.EmployeeNumber.Text = ready and string.format("%04d", number) or "----"
	fields.Night.Text = tostring(state and state.Night or 1)
	fields.Start.Active = visible == true and not busy and ready
	fields.Start.Selectable = fields.Start.Active
	fields.Back.Active = visible == true and not busy
	fields.Back.Selectable = fields.Back.Active
	self:_show(self.clock, visible == true)
	if visible then
		self.clockMugshot:Show()
	end
end

function Panels:Notice(message, busy)
	if not self.briefing then
		return
	end
	self.notice = message
	self:_show(self.briefing, message ~= nil)
	local fields = self.briefing.fields
	fields.Understood.Active = message ~= nil and not busy and not message.Disabled
	fields.Understood.Selectable = fields.Understood.Active
	if message then
		fields.Title.Text = message.Title
		fields.Section1.Text = briefingText(message.Text)
		self.briefingText = nil
	end
end
function Panels:Update(state, busy, rulesOpen, introOpen)
	self.state, self.busy = state, busy == true
	local lost = state.Outcome == "Died"
	local completed = self.complete ~= nil and state.Phase == "Results" and state.Outcome == "Survived"
	self:_show(self.complete, completed)
	self:_show(self.loss, lost)
	if not self.notice or introOpen or lost or completed or rulesOpen then
		self.notice = nil
		self:_show(
			self.briefing,
			introOpen == true and state.Intro ~= nil and not lost and not completed and not rulesOpen
		)
	end
	self:_show(self.rules, rulesOpen == true and not lost and not completed)
	local background = (lost and self.loss or completed) and 0.2 or self.background
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
	if self.briefing then
		local fields = self.briefing.fields
		enable(fields.Understood, not self.busy and self.briefing.wanted)
		if self.briefing.wanted and not self.notice then
			fields.Title.Text = state.Intro.Title
			if self.briefingText ~= state.Intro.Text then
				self.briefingText = state.Intro.Text
				fields.Section1.Text = briefingText(state.Intro.Text)
			end
		end
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
			fields.Nights.Text = tostring(stats.Nights or 0)
			fields.PhonesFixed.Text = "PHONES FIXED    " .. tostring(stats.PhonesFixed or 0)
			fields.TimeWorked.Text = string.format("TIME WORKED    %02d:%02d", math.floor(seconds / 60), seconds % 60)
			self.mugshot:Show()
		end
	end
	if self.complete then
		local fields = self.complete.fields
		enable(fields.NextNight, completed and not self.busy and state.CanReplay == true and not state.Replay)
		enable(fields.Lobby, completed and not self.busy and state.CanReturn == true)
		fields.NextNight:SetAttribute(
			"DPU_Status",
			state.Replay and "Waiting for team" or state.ContinueRun and "Next night" or "New run"
		)
		if self.complete.nextLabel and completed then
			self.complete.nextLabel.Text = state.Replay and "WAITING FOR TEAM"
				or not state.CanReplay and "PLEASE WAIT"
				or state.ContinueRun and "NEXT NIGHT"
				or "NEW RUN"
		end
		if completed then
			local stats = state.CompleteStats or {}
			local seconds = math.max(0, math.floor(stats.TimeWorked or 0))
			fields.AnomaliesSpotted.Text = tostring(stats.AnomaliesReported or 0)
			fields.PhonesFixed.Text = tostring(stats.PhonesFixed or 0)
			fields.TimeWorked.Text = string.format("%02d:%02d", math.floor(seconds / 60), seconds % 60)
			if fields.Nights then
				fields.Nights.Text = tostring(stats.Nights or 0)
			end
		end
	end
	return self.rules ~= nil, self.loss ~= nil and lost, self.briefing ~= nil, completed
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
	if self.complete then
		self.complete.fields.NextNight:SetAttribute("DPU_Status", nil)
	end
	if self.clockMugshot then
		self.clockMugshot:Destroy()
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
