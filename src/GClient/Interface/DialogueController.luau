-- Server-timed prototype dialogue presented by the authored subtitle/portrait view.
local DialogueView = require(script.Parent.DialogueView)
local View = {}
View.__index = View
function View.new(gui, deps)
	local playerGui = deps.player:FindFirstChild("PlayerGui") or gui.Parent
	local nodes = assert(
		DialogueView.Find(playerGui, gui),
		"[DPU] Missing authored DPU_PrototypeHUD.DialogueSubtitles (or HUD.Subtitles): Title, Paragraph and CharacterViewPort.ViewportFrame, optionally inside Frame"
	)
	local self = setmetatable({ d = deps, panel = nodes.root, speaker = nodes.title, line = nodes.paragraph }, View)
	-- PrototypeView already owns the main HUD binding. Only capture our own
	-- lifecycle property; releasing the whole HUD would reset unrelated controls.
	self.hud, self.resetOnSpawn = nodes.hud, nodes.hud.ResetOnSpawn
	self.hud.ResetOnSpawn = false
	self.view = DialogueView.new(nodes, deps)
	local old = gui:FindFirstChild("DialogueSubtitles")
	if old == nodes.root then
		local hud = playerGui:FindFirstChild("HUD")
		old = hud and hud:FindFirstChild("Subtitles")
	end
	if old and old ~= nodes.root and old:IsA("GuiObject") then
		self.legacy, self.legacyVisible = old, old.Visible
		old.Visible = false
	end
	return self
end
function View:Hide()
	if self.frame then
		self.frame:Disconnect()
		self.frame = nil
	end
	if not self.hidden then
		self.hidden = true
		self.view:Transition(false)
	end
end
function View:_tick()
	if not self.current or self.d.clock() >= self.current.ExpiresAt then
		self:Hide()
		return
	end
	local elapsed = math.max(0, self.d.clock() - self.started)
	local reduced = self.d.reduced()
	self.speaker.MaxVisibleGraphemes = reduced and -1 or math.floor(elapsed * 32)
	self.line.MaxVisibleGraphemes = reduced and -1 or math.floor(elapsed * 32)
end
function View:Update(state, blocked)
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
	if dialogue.Id ~= self.lastId or self.hidden then
		self.lastId, self.current, self.started = dialogue.Id, dialogue, dialogue.StartedAt or self.d.clock()
		self.hidden = false
		local you = dialogue.UserId == self.d.player.UserId or dialogue.Speaker == "You"
		-- Identity changes between different customers also transition the card.
		local identity = tostring(dialogue.UserId or dialogue.AppearanceId or dialogue.Speaker)
		if identity ~= self.identity then
			self.view.speaker = nil
		end
		self.identity = identity
		self.view:Line({
			Speaker = you and "You" or "Customer",
			Text = dialogue.Text,
			Animation = dialogue.Animation or "HappyIdle",
			DisplayName = dialogue.Speaker,
			AppearanceId = dialogue.AppearanceId,
		}, function()
			self:_tick()
		end)
	end
	self:_tick()
	if not self.frame then
		self.frame = self.d.render.RenderStepped:Connect(function()
			self:_tick()
		end)
	end
end
function View:Destroy()
	if self.frame then
		self.frame:Disconnect()
		self.frame = nil
	end
	self.view:Destroy()
	self.hud.ResetOnSpawn = self.resetOnSpawn
	if self.legacy then
		self.legacy.Visible = self.legacyVisible
	end
end
return View
