local Shared = game:GetService("ReplicatedStorage"):WaitForChild("GShared", 30)
local Rig = require(Shared:WaitForChild("Repair", 30):WaitForChild("RepairRig", 30))
local Definition = require(Shared:WaitForChild("Repair", 30):WaitForChild("RepairDefinition", 30))
local Inspection = require(script.Parent.Parent.Camera.InspectionCamera)
local Frame = require(script.Parent.Parent.Camera.InspectionFrame)
local Drag = require(script.Parent.RepairDragController)
local View = require(script.Parent.RepairViewConfig)
local Controller = {}
Controller.__index = Controller
function Controller.new(deps)
	local self = setmetatable({ d = deps }, Controller)
	self.label = Instance.new("TextLabel")
	self.label.Name, self.label.Size, self.label.Position =
		"PhoneRepairInstruction", UDim2.new(0.9, 0, 0, 44), UDim2.new(0.05, 0, 0, 90)
	self.label.BackgroundTransparency, self.label.BackgroundColor3 = 0.3, Color3.fromRGB(10, 18, 10)
	self.label.TextColor3, self.label.Font, self.label.TextSize = Color3.fromRGB(174, 223, 147), Enum.Font.Code, 17
	self.label.TextWrapped, self.label.Active, self.label.Visible, self.label.Parent = true, false, false, deps.gui
	local config =
		{ Distance = Definition.Distance, CameraSeconds = 0.55, TrackModel = false, IgnoreMovementInput = true }
	config.CameraFrame = function(_, _, _, viewport)
		if not self.view then
			local camera = deps.workspace.CurrentCamera
			return camera.CFrame, camera.Focus, camera.FieldOfView
		end
		if self.viewMode == "Wires" then
			return View.Frame(self.wiringView, viewport)
		end
		return Frame(
			self.view.Pivot,
			self.view.Bounds,
			self.view.Size,
			viewport,
			self.workView and Vector3.new(0, 5, 2.5) or Vector3.new(0, 0.15, -4),
			45
		)
	end
	self.config = config
	self.camera = Inspection.new({
		player = deps.player,
		input = deps.input,
		workspace = deps.workspace,
		render = deps.render,
		tweens = deps.tweens,
		reduced = deps.reduced,
		config = config,
		blocked = deps.blocked,
		returning = deps.returning,
		valid = function(model)
			return deps.collection:HasTag(model, Definition.Tag)
		end,
		active = function(active)
			if not active then
				self:Release()
			end
			self.label.Visible = active
			deps.active(active)
		end,
	})
	self.drag = Drag.new(self, deps)
	return self
end
function Controller:Busy()
	return self.session ~= nil or self.camera.saved ~= nil
end
function Controller:Hint(text, seconds)
	if seconds then
		self.hintUntil = os.clock() + seconds
	elseif os.clock() < (self.hintUntil or 0) then
		return
	end
	self.label.Text = text
end
function Controller:Ready()
	local s = self.session
	return s
		and s.token
		and self.workView
		and not self.camera.entering
		and not self.camera.exiting
		and os.clock() >= (s.settling or 0)
		and not self.d.blocked()
		and not self.d.input:GetFocusedTextBox()
		and s.model:GetAttribute("DPU_RepairOwner") == self.d.player.UserId
		and s.model:GetAttribute("DPU_RepairStage") ~= "Finishing"
end
function Controller:Open(model)
	if self:Busy() or self.destroyed then
		return
	end
	local rig, reason = Rig.Read(model)
	if not rig then
		warn("[DPU][Repair] Invalid Phone model:", reason)
		return
	end
	local id = model:GetAttribute("DPU_RepairId")
	if not id or model:GetAttribute("DPU_RepairOwner") or model:GetAttribute("DPU_RepairStage") == "Complete" then
		return
	end
	local s = { model = model, id = id, rig = rig, started = os.clock() }
	self.hintUntil = nil
	self.session, self.view, self.workView = s, nil, false
	self.viewMode, self.wiringView = "Front", nil
	if not self.camera:Open(model) then
		self.session = nil
		return
	end
	self:Hint("Picking up phone...")
	task.spawn(function()
		local ok, result = pcall(self.d.remote.InvokeServer, self.d.remote, "BeginRepair", { Id = id })
		if not ok or type(result) ~= "table" or not result.Ok then
			if self.session == s then
				self:Close()
			end
			warn("[DPU][Repair] Cannot start:", type(result) == "table" and result.Code or "Connection")
			return
		end
		if self.session ~= s or self.destroyed then
			self.d.move:FireServer(result.Token)
			return
		end
		s.token, s.revision, s.reply = result.Token, result.Revision, result
		self.view = result.Front
		self.wiringView = View.Wiring(result, rig)
		self:Reframe()
	end)
end
function Controller:Reframe()
	local saved = self.camera.saved
	if saved and not self.camera.exiting then
		local frame, focus, fov = self.config.CameraFrame(nil, nil, nil, saved.Camera.ViewportSize)
		self.camera:Transition(frame, focus, fov)
	end
end
function Controller:Release()
	self.drag:Cancel()
	local s = self.session
	self.session = nil
	self.d.selection:Set(nil)
	if s and s.token and not s.complete then
		self.d.move:FireServer(s.token)
	end
end
function Controller:Close(immediate)
	self.camera:Close(immediate)
end
function Controller:InputBegan(input, processed)
	if not processed and (input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.ButtonB) then
		self:Close()
		return
	end
	self.drag:InputBegan(input, processed)
end
function Controller:InputChanged(input)
	self.drag:InputChanged(input)
end
function Controller:InputEnded(input, processed)
	self.drag:InputEnded(input, processed)
end
function Controller:Update(dt)
	local s = self.session
	if not s then
		return
	end
	if self.d.blocked() or self.d.input:GetFocusedTextBox() then
		self:Close()
		return
	end
	if not s.token then
		if os.clock() - s.started > 8 then
			self:Close()
		end
		return
	end
	if s.model:GetAttribute("DPU_RepairId") ~= s.id then
		self:Close()
		return
	end
	local stage = s.model:GetAttribute("DPU_RepairStage")
	if stage == "Complete" then
		s.complete, s.completedAt = true, s.completedAt or os.clock()
		self:Hint("PHONE REPAIRED")
		if os.clock() - s.completedAt > 0.8 then
			self:Close()
		end
		return
	end
	if s.model:GetAttribute("DPU_RepairOwner") ~= self.d.player.UserId then
		-- Allow the Begin reply to precede its replicated attributes briefly.
		if os.clock() - s.started > 2 then
			self:Close()
		end
		return
	end
	local mode = stage == "Opening" and "Front" or stage == "Wires" and "Wires" or "Assembly"
	if mode ~= self.viewMode then
		self.viewMode = mode
		self.workView, self.view = mode ~= "Front", mode == "Front" and s.reply.Front or s.reply.Work
		self:Reframe()
	end
	if stage == "Opening" then
		self:Hint(s.model:GetAttribute("DPU_RepairHint") or "Opening phone...")
	elseif stage == "Wires" then
		self:Hint("Drag each ExitPoint to its matching EntryPoint")
	elseif stage == "Battery" then
		self:Hint("Drag the battery back into the phone")
	elseif stage == "Cover" then
		self:Hint("Drag the back cover into place")
	elseif stage == "Screws" then
		self:Hint("Drag all four screws back into their holes")
	elseif stage == "Finishing" then
		self:Hint("Putting the phone back...")
	end
	self.drag:Update(dt)
end
function Controller:Destroy()
	self.destroyed = true
	self.camera:Destroy()
	self.drag:Destroy()
	self.label:Destroy()
end
return Controller
