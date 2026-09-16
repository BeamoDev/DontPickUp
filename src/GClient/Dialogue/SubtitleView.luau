-- One restrained dialogue channel; typing is local and never delays gameplay.
local View = {}
View.__index = View
local function pages(text)
	local result, line = {}, ""
	for word in text:gmatch("%S+") do
		if #line > 0 and #line + #word + 1 > 70 then
			table.insert(result, line)
			line = ""
		end
		line ..= (line == "" and "" or " ") .. word
	end
	if line ~= "" then
		table.insert(result, line)
	end
	return #result > 0 and result or { "" }
end
function View.new(gui, deps)
	local self = setmetatable({ d = deps }, View)
	local panel = Instance.new("Frame")
	panel.Name, panel.BackgroundColor3, panel.BackgroundTransparency = "DialogueSubtitles", Color3.new(0, 0, 0), 0.5
	panel.BorderSizePixel, panel.Visible, panel.ZIndex = 0, false, 22
	panel.Parent, self.panel = gui, panel
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize, limit.Parent = Vector2.new(760, 100), panel
	local function label(name, y, height, size, color)
		local object = Instance.new("TextLabel")
		object.Name, object.Position, object.Size = name, UDim2.fromOffset(12, y), UDim2.new(1, -24, 0, height)
		object.BackgroundTransparency, object.TextColor3 = 1, color
		object.Font, object.TextSize = Enum.Font.Gotham, size
		object.TextWrapped, object.RichText, object.Text = true, false, ""
		object.TextXAlignment, object.TextYAlignment, object.ZIndex =
			Enum.TextXAlignment.Center, Enum.TextYAlignment.Top, 23
		object.Parent = panel
		return object
	end
	self.speaker = label("Speaker", 6, 18, 13, Color3.fromRGB(175, 166, 152))
	self.line = label("Line", 26, 54, 19, Color3.fromRGB(234, 230, 222))
	return self
end
function View:_disconnect()
	if self.frame then
		self.frame:Disconnect()
		self.frame = nil
	end
end
function View:Hide()
	self.panel.Visible = false
	self:_disconnect()
end
function View:_tick()
	if not self.current or self.d.clock() >= self.current.ExpiresAt then
		self:Hide()
		return
	end
	local elapsed, page = math.max(0, self.d.clock() - self.started), 1
	while page < #self.pages do
		local duration = (utf8.len(self.pages[page]) or #self.pages[page]) / 32 + 1.5
		if elapsed < duration then
			break
		end
		elapsed -= duration
		page += 1
	end
	local text = self.pages[page]
	if self.line.Text ~= text then
		self.line.Text = text
	end
	local length = utf8.len(text) or #text
	local count = self.d.reduced() and -1 or math.min(length, math.floor(elapsed * 32))
	if self.line.MaxVisibleGraphemes ~= count then
		self.line.MaxVisibleGraphemes = count
	end
end
function View:Update(state, blocked, physicalRepair)
	if state.RunId ~= self.run then
		self.run, self.current, self.lastId = state.RunId, nil, nil
		self:Hide()
	end
	local dialogue = state.Dialogue
	if
		blocked
		or state.Phase == "Results"
		or not state.Alive
		or state.Inspection
		or (self.d.enabled and not self.d.enabled())
		or not dialogue
		or self.d.clock() >= dialogue.ExpiresAt
	then
		self:Hide()
		return
	end
	local camera = self.d.workspace.CurrentCamera
	local small = camera and camera.ViewportSize.Y < 500
	local focused = state.Work and state.Work.Puzzle or state.Focus
	self.panel.AnchorPoint = Vector2.new(0.5, focused and 0 or 1)
	self.panel.Position = focused and UDim2.new(0.5, 0, 0, small and 54 or 72) or UDim2.new(0.5, 0, 1, -112)
	self.panel.Size = UDim2.new(0.92, 0, 0, small and 52 or 84)
	self.speaker.Position, self.speaker.TextSize = UDim2.fromOffset(12, small and 2 or 6), small and 11 or 13
	self.line.Position, self.line.Size, self.line.TextSize =
		UDim2.fromOffset(12, small and 17 or 26), UDim2.new(1, -24, 0, small and 34 or 54), small and 14 or 19
	if camera and camera.ViewportSize.X < 600 and not small then
		self.line.TextSize = 16
	end
	if focused and small and not physicalRepair then
		-- Landscape phones have free space beside the right-aligned task panel.
		self.panel.AnchorPoint = Vector2.new(0, 0.5)
		self.panel.Position, self.panel.Size = UDim2.fromScale(0.02, 0.5), UDim2.new(0.34, 0, 0, 100)
		self.line.Size = UDim2.new(1, -24, 0, 76)
	end
	if dialogue.Id ~= self.lastId then
		self.lastId, self.current, self.started = dialogue.Id, dialogue, dialogue.StartedAt or self.d.clock()
		self.pages = pages(dialogue.Text)
		self.speaker.Text, self.line.Text =
			self.d.player and dialogue.UserId == self.d.player.UserId and "You" or dialogue.Speaker, self.pages[1]
		self.line.MaxVisibleGraphemes = self.d.reduced() and -1 or 0
	end
	self.panel.Visible = true
	self:_tick()
	if not self.frame then
		self.frame = self.d.render.RenderStepped:Connect(function()
			self:_tick()
		end)
	end
end
function View:Destroy()
	self:Hide()
	self.panel:Destroy()
end
return View
