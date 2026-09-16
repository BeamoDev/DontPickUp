local Shared = game:GetService("ReplicatedStorage"):WaitForChild("GShared", 30)
local Tags = require(Shared.Interactions.InteractionTags)
local Config = require(Shared.Interactions.ThrowConfig)
local Effects = require(script.Parent.ThrowEffects)
local Throws = {}
Throws.__index = Throws

function Throws.new(services, eligible, visible)
	return setmetatable(
		{ s = services, eligible = eligible, visible = visible, items = {}, ids = {}, holds = {}, cooldowns = {} },
		Throws
	)
end
function Throws:Add(item)
	if self.closed or self.items[item] then
		return
	end
	local record = { item = item, id = self.s.HttpService:GenerateGUID(false), welds = {}, revision = 0 }
	self.items[item], self.ids[record.id] = record, record
	item:SetAttribute("DPU_ThrowId", record.id)
	item:SetAttribute("DPU_ThrowHeld", false)
	item:SetAttribute("DPU_ThrowRevision", 0)
end
function Throws:Alive(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local head = character and character:FindFirstChild("Head")
	if player.Parent == self.s.Players and humanoid and humanoid.Health > 0 and not humanoid.Sit and root and head then
		return character, root, head
	end
	return nil
end
function Throws:Rig(item)
	local parts, set = {}, {}
	if item:IsA("BasePart") then
		table.insert(parts, item)
		set[item] = true
	end
	for _, part in ipairs(item:GetDescendants()) do
		if part:IsA("BasePart") then
			table.insert(parts, part)
			set[part] = true
		end
	end
	if #parts == 0 or #parts > Config.MaxParts then
		return nil
	end
	local _, size
	if item:IsA("Model") then
		_, size = item:GetBoundingBox()
	else
		size = item.Size
	end
	if size.Magnitude > Config.MaxSize then
		return nil
	end
	for _, part in ipairs(parts) do
		for _, connected in ipairs(part:GetConnectedParts(true)) do
			if not set[connected] then
				return nil
			end -- Never grab a prop welded to a cabinet/player.
		end
	end
	return parts, item:IsA("Model") and (item.PrimaryPart or parts[1]) or item
end
function Throws:Begin(player, payload)
	if self.holds[player] then
		return { Ok = false, Code = "AlreadyHolding" }
	end
	if os.clock() < (self.cooldowns[player] or 0) then
		return { Ok = false, Code = "PleaseWait" }
	end
	self.cooldowns[player] = os.clock() + 0.2
	local record = type(payload.Id) == "string" and self.ids[payload.Id]
	if
		not record
		or record.hold
		or not record.item:IsDescendantOf(self.s.Workspace)
		or Tags.Kind(self.s.CollectionService, record.item) ~= "throw"
	then
		return { Ok = false, Code = "Unavailable" }
	end
	local character, root, head = self:Alive(player)
	if not character then
		return { Ok = false, Code = "Unavailable" }
	end
	local parts, body = self:Rig(record.item)
	if not parts then
		return { Ok = false, Code = "InvalidProp" }
	end
	local accessible = false
	for _, part in ipairs(parts) do
		if
			part.CanQuery
			and (root.Position - part.Position).Magnitude <= Config.Distance
			and self.visible(character, head, part, record.item)
		then
			accessible = true
			break
		end
	end
	if not accessible then
		return { Ok = false, Code = "OutOfReach" }
	end
	local hold = {
		player = player,
		record = record,
		character = character,
		root = root,
		head = head,
		body = body,
		parts = parts,
		pivot = record.item:GetPivot(),
		original = {},
		started = os.clock(),
		token = self.s.HttpService:GenerateGUID(false),
	}
	for _, part in ipairs(parts) do
		hold.original[part] =
			{ frame = part.CFrame, anchored = part.Anchored, collide = part.CanCollide, touch = part.CanTouch }
	end
	if record.effects then
		record.effects()
		record.effects = nil
	end
	self.holds[player], record.hold = hold, hold
	record.revision += 1
	record.item:SetAttribute("DPU_ThrowRevision", record.revision)
	record.item:SetAttribute("DPU_ThrowHeld", true)
	for _, part in ipairs(parts) do
		part.Anchored, part.CanCollide, part.CanTouch = true, false, false
		part.AssemblyLinearVelocity, part.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
	end
	if not self:Position(hold, 1) then
		self:Cancel(hold)
		return { Ok = false, Code = "Blocked" }
	end
	if not self.heartbeat then
		self.heartbeat = self.s.RunService.Heartbeat:Connect(function(dt)
			self:Tick(dt)
		end)
	end
	return { Ok = true, Token = hold.token, Revision = record.revision }
end
function Throws:Position(hold, alpha)
	local target = hold.root.CFrame * CFrame.new(Config.HoldOffset)
	local ray = RaycastParams.new()
	ray.FilterType, ray.FilterDescendantsInstances =
		Enum.RaycastFilterType.Exclude, { hold.character, hold.record.item }
	local obstruction = self.s.Workspace:Raycast(hold.head.Position, target.Position - hold.head.Position, ray)
	if obstruction then
		return false
	end
	hold.record.item:PivotTo(hold.record.item:GetPivot():Lerp(target, alpha))
	return true
end
function Throws:Clear(hold)
	self.holds[hold.player], hold.record.hold = nil, nil
	hold.record.revision += 1
	hold.record.item:SetAttribute("DPU_ThrowRevision", hold.record.revision)
	hold.record.item:SetAttribute("DPU_ThrowHeld", false)
	if not next(self.holds) and self.heartbeat then
		self.heartbeat:Disconnect()
		self.heartbeat = nil
	end
end
function Throws:Cancel(hold)
	self:Clear(hold)
	if hold.record.item.Parent then
		hold.record.item:PivotTo(hold.pivot)
	end
	for part, saved in pairs(hold.original) do
		if part.Parent then
			part.CFrame, part.Anchored, part.CanCollide, part.CanTouch =
				saved.frame, saved.anchored, saved.collide, saved.touch
			part.AssemblyLinearVelocity, part.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
		end
	end
end
function Throws:Launch(hold, direction)
	local record, body = hold.record, hold.body
	local elapsed = os.clock() - hold.started
	-- Own only generated welds; loose model pieces stay together without editing authored joints.
	if #record.welds == 0 then
		for _, part in ipairs(hold.parts) do
			if part ~= body then
				local weld = Instance.new("WeldConstraint")
				weld.Name, weld.Part0, weld.Part1, weld.Parent = "DPU_ThrowWeld", body, part, body
				table.insert(record.welds, weld)
			end
		end
	end
	for part, saved in pairs(hold.original) do
		part.Anchored, part.CanCollide, part.CanTouch = false, saved.collide, saved.touch
	end
	if body:CanSetNetworkOwnership() then
		body:SetNetworkOwner(nil)
	end
	body.AssemblyLinearVelocity = direction * Config.Speed(elapsed)
	body.AssemblyAngularVelocity = Vector3.new(3, 7, -4)
	record.effects = Effects(body, Config.Charge(elapsed), hold.parts, hold.character)
	self:Clear(hold)
end
function Throws:Request(player, action, payload)
	if self.closed or not self.eligible(player) then
		return { Ok = false, Code = "NotReady" }
	end
	if type(payload) ~= "table" then
		return { Ok = false, Code = "InvalidRequest" }
	end
	if action == "GrabThrow" then
		return self:Begin(player, payload)
	end
	local hold = self.holds[player]
	if not hold or type(payload.Token) ~= "string" or payload.Token ~= hold.token then
		return { Ok = false, Code = "Changed" }
	end
	if action == "CancelThrow" then
		self:Cancel(hold)
		return { Ok = true }
	end
	if action ~= "ReleaseThrow" then
		return { Ok = false, Code = "UnknownAction" }
	end
	local direction = Config.Direction(payload)
	if not direction then
		return { Ok = false, Code = "InvalidRequest" }
	end
	local character = self:Alive(player)
	if
		character ~= hold.character
		or os.clock() - hold.started > Config.MaxHoldSeconds
		or not self:Position(hold, 1)
	then
		self:Cancel(hold)
		return { Ok = false, Code = "Unavailable" }
	end
	self:Launch(hold, direction)
	return { Ok = true }
end
function Throws:Tick(dt)
	for player, hold in pairs(self.holds) do
		local character = self:Alive(player)
		local valid = character == hold.character
			and self.eligible(player)
			and os.clock() - hold.started <= Config.MaxHoldSeconds
			and hold.record.item:IsDescendantOf(self.s.Workspace)
		for _, part in ipairs(hold.parts) do
			if part ~= hold.record.item and not part:IsDescendantOf(hold.record.item) then
				valid = false
			end
		end
		if not valid or not self:Position(hold, 1 - math.exp(-22 * dt)) then
			self:Cancel(hold)
		end
	end
end
function Throws:Drop(item)
	local record = self.items[item]
	if not record then
		return
	end
	if record.hold then
		self:Cancel(record.hold)
	end
	if record.effects then
		record.effects()
	end
	for _, weld in ipairs(record.welds) do
		weld:Destroy()
	end
	self.items[item], self.ids[record.id] = nil, nil
	item:SetAttribute("DPU_ThrowId", nil)
	item:SetAttribute("DPU_ThrowHeld", nil)
	item:SetAttribute("DPU_ThrowRevision", nil)
end
function Throws:Remove(player)
	if self.holds[player] then
		self:Cancel(self.holds[player])
	end
	self.cooldowns[player] = nil
end
function Throws:Shutdown()
	self.closed = true
	for item in pairs(self.items) do
		self:Drop(item)
	end
	table.clear(self.cooldowns)
end
return Throws
