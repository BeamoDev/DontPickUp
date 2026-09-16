local Shared = game:GetService("ReplicatedStorage"):WaitForChild("GShared", 30)
local Config = require(Shared:WaitForChild("Containers", 30):WaitForChild("ContainerConfig", 30))
local Containers = {}
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
	box:SetAttribute("DPU_ContainerId", record.id)
	box:SetAttribute("DPU_ContainerRevision", 0)
	box:SetAttribute("DPU_ContainerOpen", false)
	box:SetAttribute("DPU_ContainerBusy", false)
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
	for _, name in ipairs({ "DPU_ContainerId", "DPU_ContainerRevision", "DPU_ContainerOpen", "DPU_ContainerBusy" }) do
		box:SetAttribute(name, nil)
	end
end

function Containers:Bind(folder)
	if self.folders[folder] or self.closed or not folder:IsA("Model") then
		return
	end
	local connections = {}
	self.folders[folder] = connections
	connections[1] = folder.ChildAdded:Connect(function(box)
		self:Add(box)
	end)
	connections[2] = folder.ChildRemoved:Connect(function(box)
		self:Drop(box)
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
	local ray = RaycastParams.new()
	ray.FilterType, ray.FilterDescendantsInstances = Enum.RaycastFilterType.Exclude, { character }
	-- A lid can hide the center of a drawer while its front is clearly visible.
	-- Test just inside each face so the ray terminates in the actual box surface.
	local half = box.Size * 0.5
	local x, y, z = math.max(half.X - 0.01, 0), math.max(half.Y - 0.01, 0), math.max(half.Z - 0.01, 0)
	for _, point in ipairs({
		Vector3.zero,
		Vector3.new(0, 0, -z),
		Vector3.new(0, 0, z),
		Vector3.new(-x, 0, 0),
		Vector3.new(x, 0, 0),
		Vector3.new(0, y, 0),
		Vector3.new(0, -y, 0),
	}) do
		local destination = box.CFrame:PointToWorldSpace(point)
		local hit = self.s.Workspace:Raycast(head.Position, destination - head.Position, ray)
		if not hit or hit.Instance == box or (group and hit.Instance:IsDescendantOf(group)) then
			return true
		end
	end
	return false
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
	local distance = (root.Position - box.Position).Magnitude
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
		box:SetAttribute("DPU_ContainerBusy", false)
	end)
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
