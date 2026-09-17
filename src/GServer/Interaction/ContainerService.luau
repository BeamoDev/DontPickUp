local Shared = game:GetService("ReplicatedStorage"):WaitForChild("GShared", 30)
local Query = require(Shared:WaitForChild("Interaction", 30):WaitForChild("InteractionQuery", 30))
local Config = require(Shared:WaitForChild("Interaction", 30):WaitForChild("ContainerConfig", 30))
local Containers = {}
local Contents = require(script.Parent.DrawerContents)
Containers.__index = Containers

function Containers.new(services, eligible)
	local self = setmetatable(
		{ s = services, eligible = eligible, boxes = {}, ids = {}, cooldowns = {}, folders = {} },
		Containers
	)
	return self
end

function Containers:Add(box)
	if self.boxes[box] or not self.folders[box.Parent] or not Config.IsBox(box) then
		return
	end
	if not box.Anchored then
		warn("[DPU][Containers] Anchor this sliding box:", box:GetFullName())
		return
	end
	local record = {
		box = box,
		folder = box.Parent,
		closed = box.CFrame,
		id = self.s.HttpService:GenerateGUID(false),
		revision = 0,
		open = false,
	}
	self.boxes[box], self.ids[record.id] = record, record
	self:PairLabel(record)
	Contents.Pair(record)
	box:SetAttribute("DPU_ContainerId", record.id)
	box:SetAttribute("DPU_ContainerRevision", 0)
	box:SetAttribute("DPU_ContainerOpen", false)
	box:SetAttribute("DPU_ContainerBusy", false)
end

function Containers:ClearLabel(record)
	if record.labelTween then
		record.labelTween:Cancel()
	end
	if record.label and record.label.Parent then
		-- Restore the label before restoring its original physics state.
		record.label.CFrame = record.labelClosed
		if record.labelAnchored ~= nil then
			record.label.Anchored = record.labelAnchored
		end
	end
	record.label, record.labelClosed, record.labelAnchored, record.labelTween = nil, nil, nil, nil
end

function Containers:PairLabel(record)
	local suffix = record.box.Name:match("^Box(%d*)$")
	local label = suffix and record.folder:FindFirstChild("Label" .. suffix)
	if label and not label:IsA("BasePart") then
		label = nil
	end
	if label == record.label then
		return
	end
	self:ClearLabel(record)
	if label then
		record.label = label
		record.labelClosed = record.closed * record.box.CFrame:ToObjectSpace(label.CFrame)
	end
end

function Containers:Drop(box)
	local record = self.boxes[box]
	if not record then
		return
	end
	self.boxes[box], self.ids[record.id] = nil, nil
	if record.completed then
		record.completed:Disconnect()
	end
	if record.tween then
		record.tween:Cancel()
	end
	box.CFrame = record.closed
	self:ClearLabel(record)
	for _, name in ipairs({ "DPU_ContainerId", "DPU_ContainerRevision", "DPU_ContainerOpen", "DPU_ContainerBusy" }) do
		box:SetAttribute(name, nil)
	end
	Contents.Clear(record)
end

function Containers:Bind(folder)
	if self.folders[folder] or self.closed or not folder:IsA("Model") then
		return
	end
	local connections = {}
	self.folders[folder] = connections
	connections[1] = folder.ChildAdded:Connect(function(box)
		self:Add(box)
		local suffix = box.Name:match("^Label(%d*)$")
		local record = suffix and self.boxes[folder:FindFirstChild("Box" .. suffix)]
		if record then
			self:PairLabel(record)
		end
		for _, entry in pairs(self.boxes) do
			if entry.folder == folder then
				Contents.Pair(entry)
			end
		end
	end)
	connections[2] = folder.ChildRemoved:Connect(function(box)
		self:Drop(box)
		for _, record in pairs(self.boxes) do
			if record.label == box then
				self:ClearLabel(record)
			end
			if record.folder == folder then
				Contents.Pair(record)
			end
		end
	end)
	for _, box in ipairs(folder:GetChildren()) do
		self:Add(box)
	end
end

function Containers:Unbind(folder)
	for _, connection in ipairs(self.folders[folder] or {}) do
		connection:Disconnect()
	end
	self.folders[folder] = nil
	for box, record in pairs(self.boxes) do
		if record.folder == folder then
			self:Drop(box)
		end
	end
end

function Containers:Visible(character, head, box, group)
	return Query.Visible(self.s.Workspace, self.s.CollectionService, character, head, box, group, function(candidate)
		return not group and Config.ResolveBox(candidate, box.Parent) == box
	end)
end

function Containers:Request(player, payload)
	local function reject(code)
		return { Ok = false, Code = code }
	end
	if self.closed or player.Parent ~= self.s.Players or not self.eligible(player) then
		return reject("NotReady")
	end
	if type(payload) ~= "table" or type(payload.Id) ~= "string" or type(payload.Revision) ~= "number" then
		return reject("InvalidRequest")
	end
	if os.clock() < (self.cooldowns[player] or 0) then
		return reject("PleaseWait")
	end
	self.cooldowns[player] = os.clock() + 0.15
	local record = self.ids[payload.Id]
	if
		not record
		or record.box.Parent ~= record.folder
		or not self.folders[record.folder]
		or not record.folder:IsDescendantOf(self.s.Workspace)
	then
		return reject("Unavailable")
	end
	if record.revision ~= payload.Revision then
		return reject("Changed")
	end
	if record.tween then
		return reject("PleaseWait")
	end
	local box, character = record.box, player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local head = character and character:FindFirstChild("Head")
	if
		not humanoid
		or humanoid.Health <= 0
		or humanoid.Sit
		or not root
		or not head
		or not box.Anchored
		or not box.CanQuery
	then
		return reject("Unavailable")
	end
	local distance = Query.Distance(box, root.Position)
	if distance ~= distance or distance > Config.Distance then
		return reject("TooFar")
	end
	if not self:Visible(character, head, box) then
		return reject("Blocked")
	end
	record.open, record.revision = not record.open, record.revision + 1
	box:SetAttribute("DPU_ContainerOpen", record.open)
	box:SetAttribute("DPU_ContainerRevision", record.revision)
	box:SetAttribute("DPU_ContainerBusy", true)
	local target = record.open and record.closed + Config.OpenOffset or record.closed
	self:PairLabel(record)
	local label, labelTarget = record.label, nil
	if label then
		labelTarget = record.open and record.labelClosed + Config.OpenOffset or record.labelClosed
		-- An unanchored welded label already follows the box; a second CFrame tween would fight its assembly.
		local followsBox = not label.Anchored and table.find(label:GetConnectedParts(true), box) ~= nil
		if not followsBox then
			if record.labelAnchored == nil then
				record.labelAnchored = label.Anchored
			end
			label.Anchored = true
			record.labelTween = self.s.TweenService:Create(
				label,
				TweenInfo.new(Config.TweenSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
				{ CFrame = labelTarget }
			)
		end
	end
	local tween = self.s.TweenService:Create(
		box,
		TweenInfo.new(Config.TweenSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
		{ CFrame = target }
	)
	record.tween = tween
	record.completed = tween.Completed:Connect(function()
		if self.boxes[box] ~= record or record.tween ~= tween then
			return
		end
		record.completed:Disconnect()
		record.completed, record.tween = nil, nil
		box.CFrame = target
		Contents.Finish(record)
		if record.label == label and record.labelTween then
			record.labelTween:Cancel()
			record.labelTween = nil
			if label.Parent == record.folder then
				label.CFrame = labelTarget
			end
		end
		box:SetAttribute("DPU_ContainerBusy", false)
	end)
	if record.labelTween then
		record.labelTween:Play()
	end
	Contents.Tween(record, self.s, Config)
	tween:Play()
	return { Ok = true }
end

function Containers:Remove(player)
	self.cooldowns[player] = nil
end

function Containers:Shutdown()
	self.closed = true
	for folder in pairs(self.folders) do
		self:Unbind(folder)
	end
	table.clear(self.cooldowns)
end

return Containers
