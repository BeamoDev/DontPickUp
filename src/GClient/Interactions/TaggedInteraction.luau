-- One bounded hover query, reused by the cursor pulse; no pointer-stream remotes.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("GShared", 30)
local Tags = require(Shared:WaitForChild("Interactions", 30):WaitForChild("InteractionTags", 30))
local Interaction = {}
Interaction.__index = Interaction

function Interaction.new(deps)
	local self =
		setmetatable({ d = deps, connections = {}, focused = true, raycast = RaycastParams.new() }, Interaction)
	local function connect(signal, callback)
		table.insert(self.connections, signal:Connect(callback))
	end
	connect(deps.input.InputBegan, function(input, processed)
		if self.d.throw and self.d.throw:Busy() then
			if not processed and (input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.ButtonB) then
				self.d.throw:Cancel()
			end
			return
		end
		if
			not processed
			and self:Viewing()
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
				return
			end
			self.press, self.start, self.started = input, input.Position, os.clock()
			self.target = self:Pick(Vector2.new(input.Position.X, input.Position.Y))
			if self.target and Tags.Kind(self.d.collection, self.target) == "throw" then
				self:Activate(self.target, input)
				self:Cancel()
				return
			end
			self.revision = self.target and self.target:GetAttribute("DPU_ContainerRevision")
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
	connect(deps.input.InputEnded, function(input, processed)
		if self.d.throw then
			self.d.throw:Release(input, processed)
		end
		if input ~= self.press then
			return
		end
		local target, revision = self.target, self.revision
		local tapped = (input.Position - self.start).Magnitude <= 18 and os.clock() - self.started <= 0.6
		self:Cancel()
		if
			not processed
			and not self:Blocked()
			and tapped
			and target
			and self:Pick(Vector2.new(input.Position.X, input.Position.Y)) == target
		then
			self:Send(target, revision)
		end
	end)
	connect(deps.input.WindowFocusReleased, function()
		if self.d.throw then
			self.d.throw:Cancel()
		end
		self.focused = false
		self:CloseView()
		self:Update()
	end)
	connect(deps.input.WindowFocused, function()
		self.focused = true
	end)
	connect(deps.player.CharacterAdded, function()
		if self.d.throw then
			self.d.throw:Cancel()
		end
		self:CloseView()
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
		self:Send(item, item:GetAttribute("DPU_ContainerRevision"))
	end
end

function Interaction:Viewing()
	return self.d.inspection and self.d.inspection.saved ~= nil
end

function Interaction:CloseView()
	self:Cancel()
	if self.d.inspection then
		self.d.inspection:Close()
	end
	self.boxes, self.selected = {}, 1
	if self.highlight then
		self.highlight.Adornee, self.highlight.Parent, self.highlight.Enabled = nil, nil, false
	end
	self.d.hover(false)
end

function Interaction:Cancel()
	self.press, self.target, self.start, self.revision = nil, nil, nil, nil
end

function Interaction:Blocked()
	local character = self.d.player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return self.destroyed
		or (self.d.throw and self.d.throw:Busy())
		or self.pending
		or (self.d.inspection and self.d.inspection.entering)
		or not self.focused
		or self.d.blocked()
		or self.d.input:GetFocusedTextBox() ~= nil
		or not humanoid
		or humanoid.Health <= 0
		or humanoid.Sit
end

function Interaction:Pointer()
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
	if self.d.locked() and not viewing then
		position = nil
	end
	local ray = position and camera:ScreenPointToRay(position.X, position.Y)
		or camera:ViewportPointToRay(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
	if self.character ~= character then
		self.character = character
		self.raycast.FilterType, self.raycast.FilterDescendantsInstances = Enum.RaycastFilterType.Exclude, { character }
	end
	local hit = self.d.workspace:Raycast(ray.Origin, ray.Direction * 40, self.raycast)
	local item = hit and hit.Instance
	local tagged, kind = Tags.Resolve(self.d.collection, self.d.workspace, item)
	local nearby = hit and (root.Position - (hit.Position or item.Position)).Magnitude <= Tags.Distance
	if tagged and kind == "throw" and nearby and not viewing then
		return tagged:GetAttribute("DPU_ThrowId") and not tagged:GetAttribute("DPU_ThrowHeld") and tagged or nil
	end
	if tagged and kind == "Drink" and nearby and (not viewing or tagged:IsDescendantOf(folder)) then
		return tagged:GetAttribute("DPU_DrinkId") and not tagged:GetAttribute("DPU_DrinkBusy") and tagged or nil
	end
	if viewing then
		return self:ValidBox(item, folder, root) and item or nil
	end
	if tagged and nearby and (kind == "Container" or kind == "Fax") then
		return tagged
	end
	return nil
end

function Interaction:ValidBox(item, folder, root)
	return item
		and item:IsA("BasePart")
		and item.Parent == folder
		and item:GetAttribute("DPU_ContainerId") ~= nil
		and not item:GetAttribute("DPU_ContainerBusy")
		and (root.Position - item.Position).Magnitude <= self.d.config.Distance
end

function Interaction:Send(item, revision)
	if self:Blocked() or not item:IsDescendantOf(self.d.workspace) then
		return
	end
	local kind = Tags.Kind(self.d.collection, item)
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
	self.pending = true
	self:Cancel()
	if self.highlight then
		self.highlight.Adornee, self.highlight.Parent, self.highlight.Enabled = nil, nil, false
	end
	task.spawn(function()
		-- Never retry a toggle automatically: the server may have already accepted it.
		local ok, response = pcall(self.d.remote.InvokeServer, self.d.remote, action, payload)
		self.pending = false
		if not self.destroyed and not ok then
			warn("[DPU][Interactions] Connection failed", response)
		elseif not self.destroyed and type(response) == "table" and response.Ok ~= true then
			warn("[DPU][Interactions] Click rejected:", item.Name, response.Code or "Unknown")
		end
	end)
end

function Interaction:Update()
	local blocked = self:Blocked()
	if blocked then
		self:Cancel()
	end
	local item = not blocked and self:Pick(self:Pointer()) or nil
	if item and not self.highlight then
		local template = self.d.template()
		if template and template:IsA("Highlight") then
			self.highlight = template:Clone()
			if self.highlight.Destroying then
				self.highlight.Destroying:Connect(function()
					self.highlight = nil
				end)
			end
		end
	end
	if self.highlight then
		self.highlight.Adornee = item
		self.highlight.Enabled = item ~= nil
		self.highlight.Parent = item -- Model outside inspection; individual Box inside it.
	end
	self.d.hover(item ~= nil)
end

function Interaction:Destroy()
	self.destroyed = true
	if self.d.throw then
		self.d.throw:Destroy()
	end
	self:CloseView()
	for _, connection in ipairs(self.connections) do
		connection:Disconnect()
	end
	self.d.hover(false)
	if self.highlight then
		self.highlight:Destroy()
	end
end

return Interaction
