-- Local authored keypad and easter-egg calls; no real phone/network service.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("GShared", 30)
local Tags = require(Shared:WaitForChild("Interaction", 30):WaitForChild("InteractionTags", 30))
local Query = require(Shared:WaitForChild("Interaction", 30):WaitForChild("InteractionQuery", 30))
local Selection = require(script.Parent.Parent.Interaction.SelectionHighlight)
local Calls = require(script.Parent.TelephoneCalls)
local ReceiverMotion = require(script.Parent.ReceiverMotion)
local Telephone = {}
local InspectionCamera = require(script.Parent.Parent.Camera.InspectionCamera)
Telephone.__index = function(self, key)
	if key == "saved" or key == "entering" then
		return self.camera and self.camera[key]
	end
	return Telephone[key]
end

function Telephone.new(deps)
	local self = setmetatable({ d = deps, focused = true, digits = "", raycast = RaycastParams.new() }, Telephone)
	self.receiver = ReceiverMotion.new(deps)
	self.selection = deps.selection or Selection.new(deps.workspace, deps.template)
	self.camera = InspectionCamera.new({
		returning = deps.returning,
		player = deps.player,
		input = deps.input,
		workspace = deps.workspace,
		config = deps.config,
		tweens = deps.tweens,
		render = deps.render,
		reduced = deps.reduced,
		valid = function(model)
			return self:IsTelephone(model)
		end,
		blocked = function()
			return not self.focused or deps.menuOpen() or deps.modalOpen()
		end,
		active = function(active)
			if not active then
				self:RestoreScreen()
			end
			deps.active(active)
		end,
	})
	return self
end

function Telephone:InputBegan(input, processed)
	if input.UserInputType == Enum.UserInputType.Touch and self.press and input ~= self.press then
		self:CancelPress()
		return
	end
	if processed or not self.saved then
		return
	end
	if input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.ButtonB then
		self:Close()
		return
	end
	if not self:Ready() then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		self:Activate(self:PickKey(self.d.input:GetMouseLocation()))
	elseif input.UserInputType == Enum.UserInputType.Touch then
		if self.press then
			self:CancelPress()
			return
		end
		self.press, self.start, self.started = input, input.Position, os.clock()
		self.key = self:PickKey(Vector2.new(input.Position.X, input.Position.Y))
	elseif
		input.KeyCode == Enum.KeyCode.DPadLeft
		or input.KeyCode == Enum.KeyCode.DPadRight
		or input.KeyCode == Enum.KeyCode.DPadUp
		or input.KeyCode == Enum.KeyCode.DPadDown
	then
		local step = (input.KeyCode == Enum.KeyCode.DPadLeft and -1)
			or (input.KeyCode == Enum.KeyCode.DPadRight and 1)
			or (input.KeyCode == Enum.KeyCode.DPadUp and -3)
			or 3
		self.selected = (self.selected - 1 + step) % #self.d.config.ControlOrder + 1
		self:Update()
	elseif input.KeyCode == Enum.KeyCode.ButtonR2 or input.KeyCode == Enum.KeyCode.ButtonA then
		self:Activate(self:PickKey())
	else
		local digits = {
			Zero = "0",
			One = "1",
			Two = "2",
			Three = "3",
			Four = "4",
			Five = "5",
			Six = "6",
			Seven = "7",
			Eight = "8",
			Nine = "9",
		}
		local value = digits[(input.KeyCode.Name:gsub("^Keypad", ""))]
		if value then
			self:Enter(value)
		elseif input.KeyCode == Enum.KeyCode.Backspace then
			self:Enter("Backspace")
		elseif input.KeyCode == Enum.KeyCode.Delete then
			self:Enter("Clear")
		elseif input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.KeypadEnter then
			self:Enter("Dial")
		end
	end
end

function Telephone:InputChanged(input)
	if input == self.press and (input.Position - self.start).Magnitude > 18 then
		self:CancelPress()
	end
end

function Telephone:InputEnded(input, processed)
	if input ~= self.press then
		return
	end
	local key = self.key
	local tapped = (input.Position - self.start).Magnitude <= 18 and os.clock() - self.started <= 0.6
	self:CancelPress()
	if
		not processed
		and tapped
		and self:Ready()
		and key == self:PickKey(Vector2.new(input.Position.X, input.Position.Y))
	then
		self:Activate(key)
	end
end

function Telephone:CancelPress()
	self.press, self.start, self.key = nil, nil, nil
end

function Telephone:IsTelephone(model)
	if self.d.isTelephone then
		return self.d.isTelephone(model)
	end
	return model
		and model:IsA("Model")
		and Tags.Kind(self.d.collection, model) == "Fax"
		and model:IsDescendantOf(self.d.workspace)
end

function Telephone:Target(hit, root)
	local part = hit and hit.Instance
	if not part or (root.Position - hit.Position).Magnitude > self.d.config.Distance then
		return nil
	end
	local model = part.Parent
	while model and model ~= self.d.workspace do
		if self:IsTelephone(model) then
			return model
		end
		model = model.Parent
	end
	return nil
end

function Telephone:Ready()
	return self.saved
		and not self.entering
		and not self.camera.exiting
		and self.focused
		and not self.d.menuOpen()
		and not self.d.input:GetFocusedTextBox()
		and not self.d.modalOpen()
end

function Telephone:Write()
	if self.label and self.label.Parent then
		self.label.Text = self.status
			or (#self.digits > 0 and self.digits)
			or (self.d.emptyText and self.d.emptyText())
			or ""
	end
end

function Telephone:Enter(value)
	if not self:Ready() then
		return
	end
	if value == "Close" then
		self:Close()
		return
	end
	if self.d.acceptKey and not self.d.acceptKey(value) then
		return
	end
	if value == "End" then
		if self.d.hangup then
			self.d.hangup()
		end
		self:EndCall()
		self.digits, self.status = "", nil
	elseif self.call then
		return -- A connected call owns the keypad until End or Close.
	elseif value == "Clear" then
		self.digits, self.status = "", nil
	elseif value == "Backspace" then
		self.digits, self.status = self.digits:sub(1, -2), nil
	elseif value == "Dial" then
		if self.receiver.lowering then
			return
		end
		if self.d.dial then
			self.d.dial(self.digits)
			return
		end
		local route = Calls[self.digits]
		if route then
			self.callSerial = (self.callSerial or 0) + 1
			self.call = {
				Number = self.digits,
				Route = route,
				Started = os.clock(),
				Phase = "Dialing",
				SessionId = self.callSerial,
			}
			self.status = "DIALING " .. self.digits
			self.receiver:Raise(self.model, self.saved.Camera)
			self:NotifyCall("Dialing")
		else
			self.status = #self.digits == 0 and "ENTER NUMBER" or "NOT CONNECTED"
		end
	elseif type(value) == "string" and value:match("^[%d*#]$") and #self.digits < self.d.config.MaxDigits then
		self.status = nil
		self.digits ..= value
	end
	self:Write()
end

function Telephone:ConnectPickup(number, message)
	if not self:Ready() then
		return
	end
	self:EndCall(true)
	self.callSerial = (self.callSerial or 0) + 1
	self.call = {
		Number = number,
		Started = os.clock(),
		Phase = "Dialing",
		SessionId = self.callSerial,
		Route = { Id = "CustomerPickup", DialSeconds = 0.65 },
		ConnectedText = message,
	}
	self.status = "DIALING " .. number
	self.receiver:Raise(self.model, self.saved.Camera)
	self:Write()
end

function Telephone:NotifyCall(phase)
	local call = self.call
	if call and self.d.callChanged then
		self.d.callChanged({
			Phase = phase,
			Number = call.Number,
			Id = call.Route.Id,
			SubtitleKey = call.Route.SubtitleKey,
			SessionId = call.SessionId,
		})
	end
end

function Telephone:EndCall(immediate)
	if self.call then
		self:NotifyCall("Ended")
	end
	self.call = nil
	self.receiver:Lower(immediate)
end

function Telephone:Activate(part)
	if part then
		self:Enter(self.d.config.Key(part.Name))
	end
end

function Telephone:PickKey(position)
	if not self:Ready() then
		return nil
	end
	if self.d.input.PreferredInput == Enum.PreferredInput.Gamepad then
		local key = self.model:FindFirstChild(self.d.config.ControlOrder[self.selected], true)
		return key and key:IsA("BasePart") and key or nil
	end
	local camera = self.saved.Camera
	if self.d.uiBlocked and self.d.uiBlocked(position) then
		return nil
	end
	local ray = position and camera:ViewportPointToRay(position.X, position.Y)
		or camera:ViewportPointToRay(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
	local _, key = Query.Cast(
		self.d.workspace,
		self.d.collection,
		ray.Origin,
		ray.Direction * 40,
		self.raycast,
		{ self.d.player.Character },
		function(part)
			while part and part ~= self.model and part:IsDescendantOf(self.model) do
				if part:IsA("BasePart") and self.d.config.Key(part.Name) then
					return part
				end
				part = part.Parent
			end
			return nil
		end,
		self.model
	)
	return key
end

function Telephone:Open(model)
	if
		self.saved
		or self.destroyed
		or not self:IsTelephone(model)
		or not self.focused
		or self.d.menuOpen()
		or self.d.modalOpen()
	then
		return
	end
	if not self.camera:Open(model) then
		return
	end
	self.model, self.digits, self.status, self.selected = model, "", nil, 1
	-- Use only the authored label/ancestor chain; no replacement phone screen is generated.
	local inputArea = model:FindFirstChild("InputArea")
	local surface = inputArea and inputArea:FindFirstChild("SurfaceGui")
	local frame = surface and surface:FindFirstChild("Frame")
	local label = frame and frame:FindFirstChild("TextLabel")
	self.visible = {}
	if label and label:IsA("TextLabel") then
		self.label, self.oldText = label, label.Text
		self.visible = {
			{ surface, "Enabled", surface.Enabled },
			{ frame, "Visible", frame.Visible },
			{ label, "Visible", label.Visible },
		}
		for _, spec in ipairs(self.visible) do
			spec[1][spec[2]] = true
		end
		self:Write()
	else
		warn("[DPU][Telephone] Expected InputArea.SurfaceGui.Frame.TextLabel in", model:GetFullName())
	end
end

function Telephone:Check()
	self.camera:Check()
end

function Telephone:Update()
	self.receiver:Update()
	if
		self.call
		and self.call.Phase == "Dialing"
		and self:Ready()
		and os.clock() - self.call.Started >= self.call.Route.DialSeconds
	then
		self.call.Phase, self.status = "Connected", self.call.ConnectedText or "CONNECTED " .. self.call.Number
		self:Write()
		self:NotifyCall("Connected")
	end
	if not self.saved then
		return
	end
	local pointer = self.d.input.PreferredInput == Enum.PreferredInput.KeyboardAndMouse
			and self.d.input:GetMouseLocation()
		or nil
	if self.press then
		pointer = Vector2.new(self.press.Position.X, self.press.Position.Y)
	end
	local part = self:PickKey(pointer)
	self.highlight = self.selection:Set(part)
end

function Telephone:RestoreScreen()
	self:EndCall()
	self:CancelPress()
	if self.highlight then
		self.selection:Set(nil)
	end
	if self.label and self.label.Parent then
		self.label.Text = self.oldText
	end
	for _, spec in ipairs(self.visible or {}) do
		if spec[1].Parent then
			spec[1][spec[2]] = spec[3]
		end
	end
	self.label, self.visible, self.model = nil, nil, nil
end

function Telephone:Close(immediate)
	self:EndCall(immediate)
	self.camera:Close(immediate)
end

function Telephone:Destroy()
	self.destroyed = true
	self.camera:Destroy()
	self:EndCall(true)
	self.receiver:Clear()
	if not self.d.selection then
		self.selection:Destroy()
	end
end

return Telephone
