local Config = require(script.Parent.DialogueConfig)
local View = require(script.Parent.DialogueView)
local Controller = {}
Controller.__index = Controller
local function graphemes(text)
	local count = 0
	for _ in utf8.graphemes(text) do
		count += 1
	end
	return count
end
function Controller.new(deps)
	local self = setmetatable({ d = deps, connections = {}, serial = 0 }, Controller)
	deps.reduced = deps.reduced
		or function()
			local data = deps.player:FindFirstChild("PlayerData")
			local settings = data and data:FindFirstChild("Settings")
			local reduced = settings and settings:FindFirstChild("ReducedFlashes")
			return deps.guiService.ReducedMotionEnabled or (reduced ~= nil and reduced.Value == true)
		end
	task.spawn(function()
		local playerGui = deps.player:WaitForChild("PlayerGui", 20)
		if not playerGui or self.destroyed then
			return
		end
		self.playerGui = playerGui
		table.insert(
			self.connections,
			playerGui.DescendantAdded:Connect(function()
				self:Bind()
			end)
		)
		self:Bind()
	end)
	if Config.TestEnabled then
		local delay = math.max(0, Config.TestDelay - (os.clock() - (deps.joinedAt or os.clock())))
		self.testTimer = task.delay(delay, function()
			self.testTimer = nil
			if not self.destroyed then
				self:Play(Config.TestConversation)
			end
		end)
	end
	return self
end
function Controller:Bind()
	if self.destroyed or self.binding or not self.playerGui then
		return
	end
	if self.view and self.view.nodes.root:IsDescendantOf(self.playerGui) then
		return
	end
	local nodes = View.Find(self.playerGui)
	if not nodes then
		if self.pending and not self.warned then
			self.warned = true
			warn(
				"[DPU][Dialogue] Waiting for HUD.Subtitles or DPU_PrototypeHUD.DialogueSubtitles with Title, Paragraph and CharacterViewPort.ViewportFrame"
			)
		end
		return
	end
	self.binding = true
	self.view = View.new(nodes, self.d)
	self.binding = false
	self.ancestry = nodes.root.AncestryChanged:Connect(function()
		if not nodes.root:IsDescendantOf(self.playerGui) then
			self:Stop(false)
			self.ancestry:Disconnect()
			self.ancestry = nil
			self.view:Destroy()
			self.view = nil
			self:Bind()
		end
	end)
	if self.pending then
		local pending = self.pending
		self.pending = nil
		self:Play(pending)
	end
end
function Controller:Enabled()
	local data = self.d.player:FindFirstChild("PlayerData")
	local settings = data and data:FindFirstChild("Settings")
	local subtitles = settings and settings:FindFirstChild("Subtitles")
	return subtitles == nil or subtitles.Value ~= false
end
-- Presentation only. Future story/call systems provide their own authorised lines.
-- Play replaces the current conversation; it never grants progress or sends remotes.
function Controller:Play(lines)
	if self.destroyed or not self:Enabled() or type(lines) ~= "table" or #lines == 0 or #lines > 32 then
		return false
	end
	local copy = {}
	for _, line in ipairs(lines) do
		if
			type(line) ~= "table"
			or not Config.Speaker(line.Speaker)
			or type(line.Text) ~= "string"
			or #line.Text > 500
			or not utf8.len(line.Text)
		then
			return false
		end
		if
			line.Animation ~= nil and (type(line.Animation) ~= "string" or not Config.IsNPCAnimation(line.Animation))
		then
			return false
		end
		if
			line.DisplayName ~= nil
			and (type(line.DisplayName) ~= "string" or #line.DisplayName > 80 or not utf8.len(line.DisplayName))
		then
			return false
		end
		if line.AppearanceId ~= nil and (type(line.AppearanceId) ~= "string" or #line.AppearanceId > 80) then
			return false
		end
		table.insert(copy, {
			Speaker = line.Speaker,
			Text = line.Text,
			Animation = line.Animation,
			DisplayName = line.DisplayName,
			AppearanceId = line.AppearanceId,
		})
	end
	if not self.view then
		self.pending = copy
		self:Bind()
		return true
	end
	self.serial += 1
	self.lines, self.index = copy, 1
	self:NextLine()
	if not self.frame then
		self.frame = self.d.render.RenderStepped:Connect(function(dt)
			self:Step(dt)
		end)
	end
	return true
end
function Controller:NextLine()
	local line = self.lines and self.lines[self.index]
	if not line then
		self:Stop()
		return
	end
	self.phase, self.elapsed = "transition", 0
	local serial = self.serial
	self.view:Line(line, function(changed, title)
		if self.destroyed or serial ~= self.serial then
			return
		end
		self.titleCount, self.textCount = graphemes(title), graphemes(line.Text)
		self.phase, self.elapsed = changed and "title" or "text", 0
	end)
end
function Controller:Step(dt)
	if self.destroyed or not self.lines or not self.view then
		return
	end
	if not self:Enabled() then
		self:Stop()
		return
	end
	self.elapsed += dt
	local reduced = self.d.reduced()
	if self.phase == "title" then
		local count = reduced and self.titleCount
			or math.min(self.titleCount, math.floor(self.elapsed * Config.TitleCharactersPerSecond))
		if self.view.nodes.title.MaxVisibleGraphemes ~= count then
			self.view.nodes.title.MaxVisibleGraphemes = count
		end
		if count == self.titleCount then
			self.phase, self.elapsed = "text", 0
		end
	elseif self.phase == "text" then
		local count = reduced and self.textCount
			or math.min(self.textCount, math.floor(self.elapsed * Config.CharactersPerSecond))
		if self.view.nodes.paragraph.MaxVisibleGraphemes ~= count then
			self.view.nodes.paragraph.MaxVisibleGraphemes = count
		end
		if count == self.textCount then
			self.phase, self.elapsed = "reading", 0
		end
	elseif self.phase == "reading" then
		local duration = math.max(Config.ReadSeconds, self.textCount / 18)
		if self.elapsed >= duration then
			self.index += 1
			self:NextLine()
		end
	end
end
function Controller:Stop(animate)
	self.serial += 1
	self.lines, self.pending, self.phase = nil, nil, nil
	if self.frame then
		self.frame:Disconnect()
		self.frame = nil
	end
	if self.view then
		if animate == false then
			self.view:Transition(false, nil, true)
		else
			self.view:Transition(false)
		end
	end
end
function Controller:Destroy()
	if self.destroyed then
		return
	end
	self.destroyed = true
	if self.testTimer then
		task.cancel(self.testTimer)
		self.testTimer = nil
	end
	self:Stop(false)
	for _, connection in ipairs(self.connections) do
		connection:Disconnect()
	end
	if self.ancestry then
		self.ancestry:Disconnect()
	end
	if self.view then
		self.view:Destroy()
		self.view = nil
	end
end
return Controller
