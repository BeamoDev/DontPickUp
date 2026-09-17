local Config = require(script.Parent.DialogueConfig)
local Portrait = require(script.Parent.DialoguePortrait)
local View = {}
View.__index = View
local function findCard(hud, name)
	local root = hud and hud:FindFirstChild(name)
	local title = root and root:FindFirstChild("Title", true)
	local paragraph = root and root:FindFirstChild("Paragraph", true)
	local portrait = root and root:FindFirstChild("CharacterViewPort", true)
	local viewport = portrait and portrait:FindFirstChildWhichIsA("ViewportFrame", true)
	if
		not hud
		or not hud:IsA("ScreenGui")
		or not root
		or not root:IsA("GuiObject")
		or not title
		or not title:IsA("TextLabel")
		or not paragraph
		or not paragraph:IsA("TextLabel")
		or not viewport
	then
		return nil
	end
	return { hud = hud, root = root, title = title, paragraph = paragraph, viewport = viewport }
end
function View.Find(playerGui, preferredHud)
	-- Prefer the migrated HUD card in both Game modes. Older authored
	-- places remain supported until their subtitle card has moved.
	return findCard(playerGui:FindFirstChild("HUD"), "Dialogue")
		or findCard(preferredHud, "DialogueSubtitles")
		or findCard(playerGui:FindFirstChild("HUD"), "Subtitles")
		or findCard(playerGui:FindFirstChild("DPU_PrototypeHUD"), "DialogueSubtitles")
end
function View.new(nodes, deps)
	local self = setmetatable({ d = deps, nodes = nodes, saved = {}, fades = {}, tweens = {}, serial = 0 }, View)
	local function capture(item, property, value)
		self.saved[item] = self.saved[item] or {}
		self.saved[item][property] = item[property]
		if value ~= nil then
			item[property] = value
		end
	end
	self.position = nodes.root.Position
	for _, name in ipairs({ "Visible", "Position" }) do
		capture(nodes.root, name)
	end
	capture(nodes.hud, "Enabled")
	for _, label in ipairs({ nodes.title, nodes.paragraph }) do
		for _, key in ipairs({
			"Text",
			"MaxVisibleGraphemes",
			"TextColor3",
		}) do
			capture(label, key)
		end
		label.Text, label.MaxVisibleGraphemes = "", 0
	end
	local descendants = nodes.root:GetDescendants()
	table.insert(descendants, nodes.root)
	for _, item in ipairs(descendants) do
		local properties = {}
		if item:IsA("GuiObject") then
			capture(item, "Active", false)
			properties.BackgroundTransparency = item.BackgroundTransparency
		end
		if item:IsA("TextLabel") or item:IsA("TextButton") then
			properties.TextTransparency, properties.TextStrokeTransparency =
				item.TextTransparency, item.TextStrokeTransparency
		elseif item:IsA("ImageLabel") or item:IsA("ImageButton") or item:IsA("ViewportFrame") then
			properties.ImageTransparency = item.ImageTransparency
		elseif item:IsA("UIStroke") then
			properties.Transparency = item.Transparency
		end
		if next(properties) then
			self.fades[item] = properties
			-- The first entrance should fade in just like later speaker transitions.
			for key in pairs(properties) do
				item[key] = 1
			end
		end
	end
	-- Reveal the actual label/portrait ancestor chains, without replacing authored UI.
	for _, leaf in ipairs({ nodes.title, nodes.paragraph, nodes.viewport }) do
		local item = leaf
		while item and item ~= nodes.hud do
			if item:IsA("GuiObject") and not (self.saved[item] and self.saved[item].Visible ~= nil) then
				capture(item, "Visible")
			end
			item = item.Parent
		end
	end
	nodes.root.Position, nodes.root.Visible = self.position + UDim2.fromOffset(0, 18), false
	self.portrait = Portrait.new(nodes.viewport, deps)
	return self
end
function View:CancelTween()
	self.serial += 1
	if self.completed then
		self.completed:Disconnect()
		self.completed = nil
	end
	for _, tween in ipairs(self.tweens) do
		tween:Cancel()
	end
	table.clear(self.tweens)
end
function View:Transition(show, done, forceImmediate)
	self:CancelTween()
	local serial = self.serial
	self.transitioning = true
	local root = self.nodes.root
	if show then
		self.nodes.hud.Enabled = true
		for item, saved in pairs(self.saved) do
			if saved.Visible ~= nil then
				item.Visible = true
			end
		end
		root.Visible = true
	end
	local goal = {
		Position = show and self.position or self.position + UDim2.fromOffset(0, 18),
	}
	local immediate = forceImmediate or self.d.reduced()
	local info = TweenInfo.new(
		show and Config.ShowSeconds or Config.HideSeconds,
		Enum.EasingStyle.Quart,
		show and Enum.EasingDirection.Out or Enum.EasingDirection.In
	)
	for item, original in pairs(self.fades) do
		local values = {}
		for key, value in pairs(original) do
			values[key] = show and value or 1
		end
		if immediate then
			for key, value in pairs(values) do
				item[key] = value
			end
		else
			local tween = self.d.tweens:Create(item, info, values)
			table.insert(self.tweens, tween)
			tween:Play()
		end
	end
	local function finish()
		if self.destroyed or serial ~= self.serial then
			return
		end
		self.transitioning = false
		if not show then
			root.Visible = false
			self.portrait:Clear()
			self.speaker = nil
		end
		if done then
			done()
		end
	end
	if immediate then
		for key, value in pairs(goal) do
			root[key] = value
		end
		finish()
	else
		local tween = self.d.tweens:Create(root, info, goal)
		table.insert(self.tweens, tween)
		self.completed = tween.Completed:Connect(function()
			if self.destroyed or serial ~= self.serial then
				return
			end
			if self.completed then
				self.completed:Disconnect()
				self.completed = nil
			end
			finish()
		end)
		tween:Play()
	end
end
function View:Line(line, done)
	local speaker, title = Config.Speaker(line.Speaker)
	if speaker ~= "You" and type(line.DisplayName) == "string" and line.DisplayName ~= "" then
		title = line.DisplayName
	end
	local changed = speaker ~= self.speaker
		or title ~= self.displayName
		or line.AppearanceId ~= self.appearanceId
		or self.transitioning
		or not self.nodes.root.Visible
	local function show()
		if self.destroyed then
			return
		end
		self.nodes.title.Text, self.nodes.paragraph.Text = title, line.Text
		self.nodes.title.TextColor3 = speaker == "You" and Config.YouColor or Config.CustomerColor
		self.nodes.title.MaxVisibleGraphemes = changed and 0 or -1
		self.nodes.paragraph.MaxVisibleGraphemes = 0
		if changed then
			self.portrait:Show(speaker, line.Animation, line.AppearanceId)
		else
			self.portrait:Animate(line.Animation)
		end
		self.speaker, self.appearanceId, self.displayName = speaker, line.AppearanceId, title
		if changed then
			self:Transition(true, function()
				done(changed, title)
			end)
		else
			done(false, title)
		end
	end
	if changed and self.nodes.root.Visible then
		self:Transition(false, show)
	else
		show()
	end
end
function View:Destroy()
	if self.destroyed then
		return
	end
	self.destroyed = true
	self:CancelTween()
	self.portrait:Destroy()
	for item, properties in pairs(self.fades) do
		for key, value in pairs(properties) do
			item[key] = value
		end
	end
	for item, properties in pairs(self.saved) do
		for key, value in pairs(properties) do
			item[key] = value
		end
	end
end
return View
