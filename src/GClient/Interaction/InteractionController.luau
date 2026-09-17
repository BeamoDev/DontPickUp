-- One bounded hover query, reused by the cursor pulse; no pointer-stream remotes.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("GShared", 30)
local Tags = require(Shared:WaitForChild("Interaction", 30):WaitForChild("InteractionTags", 30))
local Query = require(Shared:WaitForChild("Interaction", 30):WaitForChild("InteractionQuery", 30))
local Selection = require(script.Parent.SelectionHighlight)
local Interaction = {}
Interaction.__index = Interaction

function Interaction.new(deps)
	local self =
		setmetatable({ d = deps, connections = {}, focused = true, raycast = RaycastParams.new() }, Interaction)
	self.selection = deps.selection or Selection.new(deps.workspace, deps.template)
	local function connect(signal, callback)
		table.insert(self.connections, signal:Connect(callback))
	end
	connect(deps.input.InputBegan, function(input, processed)
		-- One event owner: a repair/fax drag or close never falls through.
		if self.d.repair and self.d.repair:Busy() then
			self.d.repair:InputBegan(input, processed)
			return
		end
		if self.d.telephone and self.d.telephone.saved then
			self.d.telephone:InputBegan(input, processed)
			return
		end
		if input.UserInputType == Enum.UserInputType.Touch and self.press and input ~= self.press then
			self:Cancel()
			return
		end
		if self.d.throw and self.d.throw:Busy() then
			if processed or not self.focused or self.d.blocked() or self.d.input:GetFocusedTextBox() then
				return
			end
			if input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.ButtonB then
				self.d.throw:Cancel()
			elseif input.UserInputType == Enum.UserInputType.Touch then
				self.press, self.start, self.started, self.throwTap = input, input.Position, os.clock(), true
			elseif
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.KeyCode == Enum.KeyCode.ButtonR2
				or input.KeyCode == Enum.KeyCode.E
			then
				if not self.d.uiBlocked or not self.d.uiBlocked(self:Pointer()) then
					self.d.throw:Release()
				end
			end
			return
		end
		if
			not processed
			and (self:Viewing() or self:Watching())
			and (input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.ButtonB)
		then
			self:CloseView()
			return
		end
		if processed or self:Blocked() then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			-- Mouse clicks are discrete; only touch needs release/drag recognition.
			local item = self:Pick(self:Pointer())
			if item then
				self:Activate(item, input)
			end
		elseif input.UserInputType == Enum.UserInputType.Touch then
			if self.press then
				self:Cancel()
				return
			end
			self.press, self.start, self.started = input, input.Position, os.clock()
			self.target = self:Pick(Vector2.new(input.Position.X, input.Position.Y))
			self.revision = self:Revision(self.target)
			self.identity = self:Identity(self.target)
		elseif
			self:Viewing() and (input.KeyCode == Enum.KeyCode.DPadLeft or input.KeyCode == Enum.KeyCode.DPadRight)
		then
			if #self.boxes > 0 then
				self.selected = (self.selected - 1 + (input.KeyCode == Enum.KeyCode.DPadRight and 1 or -1))
						% #self.boxes
					+ 1
				self:Update()
			end
		elseif
			input.KeyCode == Enum.KeyCode.ButtonR2
			or input.KeyCode == Enum.KeyCode.E
			or (self:Viewing() and input.KeyCode == Enum.KeyCode.ButtonA)
		then
			local item = self:Pick(self:Pointer())
			if item then
				self:Activate(item, input)
			end
		end
	end)
	connect(deps.input.InputChanged, function(input)
		if self.d.repair and self.d.repair:Busy() then
			self.d.repair:InputChanged(input)
			return
		end
		if self.d.telephone then
			self.d.telephone:InputChanged(input)
		end
		if input == self.press and (input.Position - self.start).Magnitude > 18 then
			self:Cancel()
		end
	end)
	connect(deps.input.InputEnded, function(input, processed)
		if self.d.repair and self.d.repair:Busy() then
			self.d.repair:InputEnded(input, processed)
			self:Cancel()
			return
		end
		if self.d.telephone and self.d.telephone.saved then
			self.d.telephone:InputEnded(input, processed)
			self:Cancel()
			return
		end
		if input ~= self.press then
			return
		end
		local target, revision, identity, throwTap = self.target, self.revision, self.identity, self.throwTap
		local tapped = (input.Position - self.start).Magnitude <= 18 and os.clock() - self.started <= 0.6
		self:Cancel()
		if throwTap then
			local position = Vector2.new(input.Position.X, input.Position.Y)
			if
				not processed
				and tapped
				and self.focused
				and not self.d.blocked()
				and not self.d.input:GetFocusedTextBox()
				and (not self.d.uiBlocked or not self.d.uiBlocked(position))
			then
				self.d.throw:Release()
			end
			return
		end
		if
			not processed
			and not self:Blocked()
			and tapped
			and target
			and self:Identity(target) == identity
			and self:Pick(Vector2.new(input.Position.X, input.Position.Y)) == target
		then
			if Tags.Kind(self.d.collection, target) == "throw" then
				self:Activate(target, input)
			else
				self:Send(target, revision)
			end
		end
	end)
	connect(deps.input.WindowFocusReleased, function()
		if self.d.throw then
			self.d.throw:Cancel()
		end
		self.focused = false
		if self.d.telephone then
			self.d.telephone.focused = false
			self.d.telephone:Close()
		end
		self:CloseView()
		self:Update()
	end)
	connect(deps.input.WindowFocused, function()
		self.focused = true
		if self.d.telephone then
			self.d.telephone.focused = true
		end
	end)
	connect(deps.player.CharacterAdded, function()
		if self.d.throw then
			self.d.throw:Cancel()
		end
		self:CloseView(true)
		if self.d.telephone then
			self.d.telephone:Close(true)
		end
	end)
	return self
end

function Interaction:Activate(item, input)
	if Tags.Kind(self.d.collection, item) == "throw" then
		if self.d.throw and not self:Viewing() then
			self.d.throw:Begin(item, input)
			self:Update()
		end
	else
		self:Send(item, self:Revision(item))
	end
end

function Interaction:Viewing()
	return self.d.inspection and self.d.inspection.saved ~= nil
end

function Interaction:Watching()
	return self.d.television and self.d.television.saved ~= nil
end

function Interaction:CloseView(immediate)
	if self.d.repair then
		self.d.repair:Close(immediate)
	end
	self:Cancel()
	if self.d.inspection then
		self.d.inspection:Close(immediate)
	end
	if self.d.television then
		self.d.television:Close(immediate)
	end
	self.boxes, self.selected = {}, 1
	if self.highlight then
		self.selection:Set(nil)
	end
	self.d.hover(false)
end

function Interaction:Identity(item)
	return item
		and (
			item:GetAttribute("DPU_ContainerId")
			or item:GetAttribute("DPU_DrinkId")
			or item:GetAttribute("DPU_ThrowId")
			or item:GetAttribute("DPU_RepairId")
			or item:GetAttribute("DPU_OrderId")
		)
end

function Interaction:Revision(item)
	return item and (item:GetAttribute("DPU_OrderRevision") or item:GetAttribute("DPU_ContainerRevision"))
end

function Interaction:Cancel()
	self.throwTap = nil
	self.press, self.target, self.start, self.revision, self.identity = nil, nil, nil, nil, nil
end

function Interaction:Blocked()
	local character = self.d.player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return self.destroyed
		or (self.d.repair and self.d.repair:Busy())
		or self:Watching()
		or (self.d.throw and self.d.throw:Busy())
		or self.pending
		or (self.d.inspection and (self.d.inspection.entering or self.d.inspection.exiting))
		or (self.d.telephone and self.d.telephone.saved ~= nil)
		or not self.focused
		or self.d.blocked()
		or self.d.input:GetFocusedTextBox() ~= nil
		or not humanoid
		or humanoid.Health <= 0
		or humanoid.Sit
end

function Interaction:Pointer()
	if self.press then
		return Vector2.new(self.press.Position.X, self.press.Position.Y)
	end
	if self.d.locked() and not self:Viewing() then
		return nil
	end
	if self.d.input.PreferredInput == Enum.PreferredInput.KeyboardAndMouse then
		return self.d.input:GetMouseLocation()
	end
	return nil
end

function Interaction:Pick(position)
	if self:Blocked() then
		return nil
	end
	local camera, character = self.d.workspace.CurrentCamera, self.d.player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not camera or not root then
		return nil
	end
	local viewing = self:Viewing()
	local folder = viewing and self.d.inspection.saved.Model or nil
	if viewing and Tags.Kind(self.d.collection, folder) ~= "Container" then
		return nil
	end
	if viewing and self.d.input.PreferredInput == Enum.PreferredInput.Gamepad then
		local box = self.boxes[self.selected]
		return self:ValidBox(box, folder, root) and box or nil
	end
	if self.d.uiBlocked and self.d.uiBlocked(position) then
		return nil
	end
	local ray = position and camera:ViewportPointToRay(position.X, position.Y)
		or camera:ViewportPointToRay(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
	local hit = Query.Cast(
		self.d.workspace,
		self.d.collection,
		ray.Origin,
		ray.Direction * 40,
		self.raycast,
		{ character },
		function(part)
			local owner, kind = Tags.Resolve(self.d.collection, self.d.workspace, part)
			if viewing and owner == folder and kind == "Container" then
				return self:ResolveBox(part, folder)
			end
			return owner
		end,
		folder
	)
	local item = hit and hit.Instance
	local tagged, kind = Tags.Resolve(self.d.collection, self.d.workspace, item)
	local nearby = hit and (root.Position - (hit.Position or item.Position)).Magnitude <= Tags.Distance
	if tagged and kind == "Customer" and nearby and not viewing then
		local stage = tagged:GetAttribute("DPU_OrderStage")
		return tagged:GetAttribute("DPU_OrderId") and (stage == "Waiting" or stage == "Ready") and tagged or nil
	end
	if tagged and kind == "PhoneRepair" and nearby and not viewing then
		return tagged:GetAttribute("DPU_RepairId")
				and not tagged:GetAttribute("DPU_RepairOwner")
				and tagged:GetAttribute("DPU_RepairStage") ~= "Complete"
				and tagged
			or nil
	end
	if tagged and kind == "throw" and nearby and not viewing then
		return tagged:GetAttribute("DPU_ThrowId") and not tagged:GetAttribute("DPU_ThrowHeld") and tagged or nil
	end
	if tagged and kind == "Drink" and nearby and (not viewing or tagged:IsDescendantOf(folder)) then
		return tagged:GetAttribute("DPU_DrinkId") and not tagged:GetAttribute("DPU_DrinkBusy") and tagged or nil
	end
	if viewing then
		local box = self:ResolveBox(item, folder)
		return self:ValidBox(box, folder, root) and box or nil
	end
	if tagged and nearby and (kind == "Container" or kind == "Fax" or kind == "tv") then
		return tagged
	end
	return nil
end

function Interaction:ResolveBox(part, folder)
	return self.d.config.ResolveBox(part, folder)
end

function Interaction:ValidBox(item, folder, root)
	return item
		and item:IsA("BasePart")
		and item.Parent == folder
		and item:GetAttribute("DPU_ContainerId") ~= nil
		and not item:GetAttribute("DPU_ContainerBusy")
		and Query.Distance(item, root.Position) <= self.d.config.Distance
end

function Interaction:Send(item, revision)
	if self:Blocked() or not item:IsDescendantOf(self.d.workspace) then
		return
	end
	local kind = Tags.Kind(self.d.collection, item)
	if not self:Viewing() and kind == "Customer" then
		self:Request(item, "ServeCustomer", { Id = item:GetAttribute("DPU_OrderId"), Revision = revision })
		return
	end
	if not self:Viewing() and kind == "PhoneRepair" and self.d.repair then
		self:Cancel()
		self.selection:Set(nil)
		self.d.hover(false)
		self.d.repair:Open(item)
		return
	end
	if not self:Viewing() and kind == "tv" and self.d.television then
		self:Cancel()
		self.d.television:Open(item)
		self:Update()
		return
	end
	if kind == "Drink" then
		local id = item:GetAttribute("DPU_DrinkId")
		if type(id) == "string" and not item:GetAttribute("DPU_DrinkBusy") then
			self:Request(item, "Drink", { Id = id })
		end
		return
	end
	if not self:Viewing() and kind == "Fax" and self.d.telephone then
		self:Cancel()
		self.d.telephone:Open(item)
		self:Update()
		return
	end
	local folder = self:Viewing() and self.d.inspection.saved.Model or item
	if not self:Viewing() then
		if kind == "Container" and self.d.inspection and self.d.inspection:Open(folder) then
			self:Cancel()
			self.boxes, self.selected = {}, 1
			for _, box in ipairs(folder:GetChildren()) do
				if self.d.config.IsBox(box) then
					table.insert(self.boxes, box)
				end
			end
			table.sort(self.boxes, function(a, b)
				return a.Name < b.Name
			end)
			self:Update()
		end
		return -- Entering inspection never also toggles a drawer.
	end
	if item.Parent ~= self.d.inspection.saved.Model or item.Parent ~= folder then
		return
	end
	local id = item:GetAttribute("DPU_ContainerId")
	if type(id) ~= "string" or type(revision) ~= "number" then
		return
	end
	self:Request(item, "ToggleContainer", { Id = id, Revision = revision })
end

function Interaction:Request(item, action, payload)
	local pending = { deadline = os.clock() + 8 }
	self.pending = pending
	self:Cancel()
	if self.highlight then
		self.selection:Set(nil)
	end
	task.spawn(function()
		-- Never retry a toggle automatically: the server may have already accepted it.
		local ok, response = pcall(self.d.remote.InvokeServer, self.d.remote, action, payload)
		if not self.destroyed and action == "ServeCustomer" and self.d.orders then
			self.d.orders:Response(ok and response or { Ok = false, Code = "ConnectionFailed" })
		end
		if self.pending == pending then
			self.pending = nil
		end
		if not self.destroyed and not ok then
			warn("[DPU][Interactions] Connection failed", response)
		elseif not self.destroyed and type(response) == "table" and response.Ok ~= true then
			warn("[DPU][Interactions] Click rejected:", item.Name, response.Code or "Unknown")
		end
	end)
end

function Interaction:Update()
	if self.pending and os.clock() >= self.pending.deadline then
		self.pending = nil
	end
	local blocked = self:Blocked()
	if blocked and not (self.d.throw and self.d.throw:Busy() and self.press) then
		self:Cancel()
	end
	local item = not blocked and self:Pick(self:Pointer()) or nil
	self.highlight = self.selection:Set(item)
	self.d.hover(item ~= nil)
end

function Interaction:Destroy()
	self.destroyed = true
	if self.d.throw then
		self.d.throw:Destroy()
	end
	self:CloseView(true)
	for _, connection in ipairs(self.connections) do
		connection:Disconnect()
	end
	self.d.hover(false)
	if not self.d.selection then
		self.selection:Destroy()
	end
end

return Interaction
