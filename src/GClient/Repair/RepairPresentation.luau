local UI = require(script.Parent.Parent.Interface.AuthoredUI)
local SceneStorage = game:GetService("ReplicatedStorage"):WaitForChild("GShared", 30)
local Scene = require(SceneStorage:WaitForChild("World", 30):WaitForChild("SceneReferences", 30))
-- Local-only, pooled repair presentation. No gameplay authority or movement locks.
local Presentation = {}
Presentation.__index = Presentation
local ACCENT = Color3.fromRGB(220, 213, 200)
local EVENT_TARGET = { Blackout = "Fuse", Call = "Phone", Inspection = "Records", Visitor = "Shelter" }

local function cameraFrame(camera, marker, focus, originalFOV)
	local viewSize = camera.ViewportSize
	local aspect = viewSize and viewSize.X / math.max(1, viewSize.Y) or 1.5
	local frame = marker.WorldCFrame
	local fov = math.min(originalFOV, 45)
	if aspect < 1 then
		local offset = frame.Position - focus.WorldCFrame.Position
		local retreat = math.min(1.25, 1 / math.max(0.4, aspect))
		-- Keep the camera below the shop ceiling; widen portrait FOV instead of backing through it.
		frame = CFrame.lookAt(focus.WorldCFrame.Position + offset * retreat, focus.WorldCFrame.Position, frame.UpVector)
		fov = math.min(85, math.deg(2 * math.atan(math.tan(math.rad(fov / 2)) / (math.max(0.4, aspect) * retreat))))
	end
	return frame, fov
end

function Presentation.new(deps, gui)
	local self = setmetatable({ d = deps, connections = {}, state = {} }, Presentation)
	self.highlight = UI.Highlight(deps.workspace:FindFirstChild("Prototype"), "DPU_RepairFocus", {
		DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
		FillTransparency = 1,
		FillColor = ACCENT,
		OutlineColor = ACCENT,
	})
	self.card = UI.Bind("Frame", gui, "RepairProgress", { Visible = false })
	UI.Bind("UISizeConstraint", self.card, nil)
	self.label = UI.Bind("TextLabel", self.card, "Step", { Text = "" })
	local track = UI.Bind("Frame", self.card, "Track")
	self.track = track
	self.fill = UI.Bind("Frame", track, "Fill")
	self.exit = UI.Bind("TextButton", self.card, "LeaveCloseUp", { Text = "STAND UP [Q / B]", Visible = false })
	table.insert(
		self.connections,
		self.exit.Activated:Connect(function()
			self:Dismiss()
		end)
	)
	table.insert(
		self.connections,
		deps.input.InputBegan:Connect(function(input, processed)
			if not processed and (input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.ButtonB) then
				self:Dismiss()
			end
		end)
	)
	return self
end

function Presentation:_cancelTween()
	if self.completed then
		self.completed:Disconnect()
		self.completed = nil
	end
	if self.tween then
		self.tween:Cancel()
		self.tween = nil
	end
end

function Presentation:_showCharacter()
	if self.characterAdded then
		self.characterAdded:Disconnect()
		self.characterAdded = nil
	end
	for object, value in pairs(self.hidden or {}) do
		if object.Parent then
			object[value.Property] = value.Value
		end
	end
	self.hidden, self.hiddenCharacter = nil, nil
end

function Presentation:_hideCharacter(character)
	if self.hiddenCharacter == character then
		return
	end
	self:_showCharacter()
	if not character then
		return
	end
	self.hidden, self.hiddenCharacter = {}, character
	local function hide(object)
		local property = object:IsA("BasePart") and "LocalTransparencyModifier"
			or (object:IsA("Decal") or object:IsA("Texture")) and "Transparency"
		if property and not self.hidden[object] then
			self.hidden[object] = { Property = property, Value = object[property] or 0 }
			object[property] = 1
		end
	end
	for _, object in ipairs(character:GetDescendants()) do
		hide(object)
	end
	self.characterAdded = character.DescendantAdded:Connect(hide)
end

function Presentation:_restore()
	self:_showCharacter()
	self:_cancelTween()
	if self.frame then
		self.frame:Disconnect()
		self.frame = nil
	end
	local saved = self.saved
	self.saved = nil
	self.exit.Visible = false
	if not saved then
		return
	end
	local camera = saved.Camera
	-- Another camera controller can take over without being reset by a late callback.
	if camera.CameraType == Enum.CameraType.Scriptable then
		camera.CFrame, camera.Focus, camera.FieldOfView = saved.CFrame, saved.Focus, saved.FOV
		camera.CameraSubject, camera.CameraType = saved.Subject, saved.Type
	end
end

function Presentation:Release(immediate)
	self:_showCharacter()
	local saved = self.saved
	if not saved then
		return
	end
	if immediate or self.d.reduced() or self.d.workspace.CurrentCamera ~= saved.Camera then
		self:_restore()
		return
	end
	if saved.Returning then
		return
	end
	self:_cancelTween()
	saved.Returning = true
	self.exit.Visible = false
	local tween =
		self.d.tweens:Create(saved.Camera, TweenInfo.new(0.24, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = saved.CFrame,
			Focus = saved.Focus,
			FieldOfView = saved.FOV,
		})
	self.tween = tween
	self.completed = tween.Completed:Connect(function()
		if self.saved == saved and self.tween == tween then
			self:_restore()
		end
	end)
	tween:Play()
end

function Presentation:Dismiss()
	self.dismissed = self.workKey
	self:Release(true)
	if self.state.Seated and self.d.stand then
		self.d.stand()
	end
end

function Presentation:OwnsCamera()
	return self.saved ~= nil
end

function Presentation:_enter(bench, key)
	local camera, player = self.d.workspace.CurrentCamera, self.d.player
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local marker, focus = bench:FindFirstChild("RepairCamera"), bench:FindFirstChild("RepairFocus")
	local seat = bench.Parent and bench.Parent:FindFirstChild("RepairSeat")
	if
		not camera
		or camera.CameraType ~= Enum.CameraType.Custom
		or not root
		or not humanoid
		or humanoid.Health <= 0
		or not seat
		or humanoid.SeatPart ~= seat
		or not humanoid.Sit
		or humanoid.MoveDirection.Magnitude > 0.05
		or (root.Position - bench.Position).Magnitude > 13
		or not marker
		or not marker:IsA("Attachment")
		or not focus
		or not focus:IsA("Attachment")
	then
		return
	end
	self:Release(true)
	local saved = {
		Camera = camera,
		Type = camera.CameraType,
		Subject = camera.CameraSubject,
		CFrame = camera.CFrame,
		Focus = camera.Focus,
		FOV = camera.FieldOfView,
		Character = character,
		RootPosition = root.Position,
	}
	self.saved = saved
	self:_hideCharacter(character)
	camera.CameraType = Enum.CameraType.Scriptable
	self.exit.Visible = true
	saved.Viewport = camera.ViewportSize
	local targetFrame, targetFOV = cameraFrame(camera, marker, focus, saved.FOV)
	self.tween = self.d.tweens:Create(camera, TweenInfo.new(0.32, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		CFrame = targetFrame,
		Focus = focus.WorldCFrame,
		FieldOfView = targetFOV,
	})
	self.tween:Play()
	-- This one callback exists only during a close-up/return, never while idle.
	self.frame = self.d.render.RenderStepped:Connect(function()
		if
			self.d.workspace.CurrentCamera ~= camera
			or player.Character ~= character
			or not bench.Parent
			or not root.Parent
			or humanoid.Health <= 0
			or humanoid.SeatPart ~= seat
			or not humanoid.Sit
			or humanoid.MoveDirection.Magnitude > 0.05
			or (root.Position - saved.RootPosition).Magnitude > 1
			or self.d.reduced()
			or camera.CameraType ~= Enum.CameraType.Scriptable
			or self.d.menuOpen()
		then
			self:Dismiss()
			return
		end
		if not saved.Returning then
			camera.Focus = focus.WorldCFrame
			if camera.ViewportSize ~= saved.Viewport then
				saved.Viewport = camera.ViewportSize
				self:_cancelTween()
				camera.CFrame, camera.FieldOfView = cameraFrame(camera, marker, focus, saved.FOV)
			end
			for object, value in pairs(self.hidden or {}) do
				if object.Parent then
					object[value.Property] = 1
				end
			end
		end
	end)
end

function Presentation:Update(state, modalOpen)
	self.state = state
	local world = Scene.Find(self.d.workspace)
	local station = state.SeatStation or "Bench"
	local bench = world and world:FindFirstChild(station)
	local phone = world and world:FindFirstChild(state.PhoneName or "RepairPhone")
	local work, order = state.Work, state.Order
	local now = self.d.workspace:GetServerTimeNow()
	local active = state.Alive and not state.NeedsRules and state.Phase ~= "Results" and not modalOpen
	local own = active
		and state.Seated
		and order
		and not (state.WorkBlocked == true or state.WorkBlocked == nil and state.Event ~= nil)
		and bench
		and phone
	local key = own and table.concat({ state.RunId, order.Id, station, tostring(state.SeatVisit or 0) }, ":") or nil
	local changed = key ~= self.workKey
	self.workKey = key
	self.card.Visible = own ~= nil and own ~= false
	self.exit.Visible = self.card.Visible
	local working = own
		and work
		and not work.Interactive
		and work.UserId == self.d.player.UserId
		and work.Station == station
		and now < work.EndsAt
	-- Between steps and during puzzles, only the touch-friendly exit is needed.
	-- The objective/puzzle already explains the action; expand only for fitting.
	self.label.Visible, self.track.Visible = working == true, working == true
	self.card.Size = UDim2.new(0.8, 0, 0, working and 76 or 44)
	self.card.Position = UDim2.new(0.5, 0, 0, work and work.Puzzle and 8 or 72)
	self.exit.Position = UDim2.fromOffset(5, working and 40 or 0)
	self.exit.Size = UDim2.new(1, -10, 0, working and 32 or 44)
	local progressKey = working and (key .. work.Action .. tostring(work.StartedAt)) or nil
	if progressKey ~= self.progressKey then
		self.progressKey = progressKey
		if self.progress then
			self.progress:Cancel()
			self.progress = nil
		end
		if working then
			local duration = math.max(0.01, work.EndsAt - (work.StartedAt or now))
			self.fill.Size = UDim2.fromScale(math.clamp(1 - (work.EndsAt - now) / duration, 0, 1), 1)
			self.progress = self.d.tweens:Create(
				self.fill,
				TweenInfo.new(work.EndsAt - now, Enum.EasingStyle.Linear),
				{ Size = UDim2.fromScale(1, 1) }
			)
			self.progress:Play()
		else
			self.fill.Size = UDim2.fromScale(0, 1)
		end
	end
	if own then
		if not working then
			local fraction = order.Step == "Secure" and (order.Contacts or 0) / (order.RequiredContacts or 4) or 0
			local size = UDim2.fromScale(fraction, 1)
			if self.fill.Size ~= size then
				self.fill.Size = size
			end
		end
		local text = own and work and work.Interactive and "FOLLOW THE STEPS ON THE PHONE"
			or working and "PUTTING THE PART IN..."
			or order.Step == "Diagnose" and "REMOVE SCREWS, COVER AND BATTERY; THEN DIAGNOSE"
			or order.Step == "Collect" and ("NEEDED: " .. string.upper(order.Fault or "PART") .. " / STOCKROOM")
			or order.Step == "Repair" and not order.PartDelivered and ("WAITING FOR " .. string.upper(
				order.Fault or "PART"
			))
			or order.Step == "Secure" and "REINSTALL BATTERY, COVER AND FOUR SCREWS"
			or order.Step == "Install" and "OPEN THE CUSTOMER PHONE"
			or order.Step == "Test" and "CHECK THAT THE PHONE WORKS"
			or order.Step == "Return" and "GIVE THE PHONE BACK AT THE COUNTER"
			or "FOLLOW THE NEXT REPAIR STEP"
		if self.label.Text ~= text then
			self.label.Text = text
		end
	end
	if changed and self.saved then
		self:Release(
			(state.WorkBlocked == true or state.WorkBlocked == nil and state.Event ~= nil)
				or not state.Alive
				or modalOpen
		)
	end
	if key and key ~= self.dismissed and not self.d.reduced() and not self.d.menuOpen() then
		if not self.saved or self.saved.Returning then
			self:_enter(bench, key)
		end
	elseif self.saved and (self.d.reduced() or self.d.menuOpen()) then
		self:Dismiss()
	end
	local character = self.d.player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if own and humanoid and humanoid.Health > 0 and humanoid.Sit and not self.d.menuOpen() then
		self:_hideCharacter(character)
	else
		self:_showCharacter()
	end
	local target = (state.WorkBlocked == true or state.WorkBlocked == nil and state.Event ~= nil)
			and state.Event
			and EVENT_TARGET[state.Event.Kind]
		or state.Target
	if own then
		target = station
	end
	local adornee = active and world and target and Scene.Station(world, target) or nil
	local stockBox = Scene.StockBox(adornee)
	if stockBox and stockBox:GetAttribute("DPU_ContainerOpen") ~= true then
		adornee = stockBox
	end
	if not own and world and (target == "Bench" or target == "Bench2") then
		phone = world:FindFirstChild(state.PhoneName or "RepairPhone")
	end
	if active and (target == "Bench" or target == "Bench2") and phone and order then
		local name = (order.Step == "Repair" or order.Step == "Collect") and order.Fault or "Screen"
		if order.Step == "Secure" then
			name = (phone:GetAttribute("DPU_DeviceId") and "Screw" or "Contact") .. tostring((order.Contacts or 0) + 1)
		end
		local component = name and phone:FindFirstChild(name, true)
		adornee = component and component:IsA("BasePart") and component or phone
	end
	if self.highlight.Adornee ~= adornee then
		self.highlight.Adornee = adornee
	end
	local enabled = adornee ~= nil
	if self.highlight.Enabled ~= enabled then
		self.highlight.Enabled = enabled
	end
	local alpha = own and 0.82 or 1
	local color = own and (order.Step == "Collect" or order.Step == "Repair") and Color3.fromRGB(193, 155, 123)
		or ACCENT
	if self.highlight.OutlineColor ~= color then
		self.highlight.OutlineColor, self.highlight.FillColor = color, color
	end
	if self.highlight.FillTransparency ~= alpha then
		self.highlight.FillTransparency = alpha
	end
end

function Presentation:Destroy()
	self:Release(true)
	if self.progress then
		self.progress:Cancel()
	end
	for _, connection in ipairs(self.connections) do
		connection:Disconnect()
	end
	UI.Release(self.highlight)
	UI.Release(self.card)
end

return Presentation
