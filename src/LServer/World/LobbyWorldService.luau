local QueueService = require(script.Parent.Parent.Matchmaking.QueueService)
local Geometry = require(script.Parent.QueueGeometry)
local Billboard = require(script.Parent.QueueBillboard)
local World = {}
World.__index = World

local function rig(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if root and root:IsA("BasePart") and humanoid and humanoid.Health > 0 then
		return character, root, humanoid
	end
	return nil
end

function World.new(services, config, data, party, network)
	local self = setmetatable({
		s = services,
		config = config,
		objects = {},
		byInstance = {},
		blocked = {},
		nextTry = {},
		errors = {},
		serial = 0,
		lastDiscovery = 0,
		closing = false,
	}, World)
	self.queues = QueueService.new({
		config = config,
		party = party,
		clock = function()
			return workspace:GetServerTimeNow()
		end,
		ready = function(player)
			return data:IsReady(player)
		end,
		present = function(player)
			return player.Parent == services.Players
		end,
		alive = function(player)
			return rig(player) ~= nil
		end,
		inside = function(player, id)
			return self:Inside(player, id)
		end,
		far = function(player, id)
			local _, root = rig(player)
			local object = self.objects[id]
			return not root
				or not object
				or (root.Position - object.EnterPos.Position).Magnitude > config.QueueMaxDistance
		end,
		move = function(...)
			return self:Move(...)
		end,
		exited = function(player)
			self.blocked[player] = true
			self.nextTry[player] = os.clock() + 0.5
		end,
		push = function(player, state)
			player:SetAttribute("DPU_WorldQueueId", state.Active and state.QueueId or nil)
			network:PushQueue(player, state)
		end,
		log = function(action, player, id)
			if services.RunService:IsStudio() then
				print("[DPU][Queue] " .. action, player.Name, id)
			end
		end,
	})
	-- Bind before the first maintenance tick so a new arrival can touch immediately.
	self:Discover()
	return self
end

function World:Inside(player, id)
	local _, root = rig(player)
	local object = self.objects[id]
	return root ~= nil and object ~= nil and Geometry.Contains(object.Enter.CFrame, object.Enter.Size, root.Position)
end

function World:ClosestEntry(player)
	local _, root = rig(player)
	if not root then
		return nil
	end
	local inside, closest = nil, math.huge
	for id, object in pairs(self.objects) do
		if self:Inside(player, id) then
			local distance = (root.Position - object.Enter.Position).Magnitude
			if distance < closest or (distance == closest and (not inside or id < inside)) then
				inside, closest = id, distance
			end
		end
	end
	return inside
end

function World:TryEnter(player, id)
	local object = self.objects[id]
	if
		self.closing
		or not object
		or player.Parent ~= self.s.Players
		or self.blocked[player]
		or self.queues.players[player]
		or self.queues.busy[player]
		or os.clock() < (self.nextTry[player] or 0)
		or object.Instance.Parent ~= workspace:FindFirstChild("Queues")
		or not object.Enter:IsDescendantOf(object.Instance)
		or not self:Inside(player, id)
	then
		return
	end
	-- Claim the retry window before admission can yield (Friends-only queues).
	self.nextTry[player] = os.clock() + 0.5
	local ok, reason = self.queues:Enter(player, id)
	if ok then
		self.errors[player] = nil
		self:Render()
	elseif
		not self.closing
		and player.Parent == self.s.Players
		and self:Inside(player, id)
		and not self.queues.players[player]
		and self.errors[player] ~= reason
	then
		self.errors[player] = reason
		self.queues:Feedback(player, reason)
		if self.s.RunService:IsStudio() then
			print("[DPU][Queue] Entry waiting:", player.Name, reason)
		end
	end
end

function World:Move(player, id, entering, slot)
	local object = self.objects[id]
	local character, root, humanoid = rig(player)
	if not object or not character then
		return false
	end
	local marker = entering and object.EnterPos or object.ExitPos
	-- Keep the first member on the marker; leave holes in place when somebody exits.
	-- Reuse these slots at ExitPos too, so a whole departing roster does not pile up.
	local offset = slot == 1 and Vector3.zero
		or Vector3.new((slot % 2 == 0 and -1 or 1) * 3, 0, math.ceil((slot - 1) / 2) * 3)
	humanoid.Sit = false
	character:PivotTo(
		marker.CFrame * CFrame.new(offset + Vector3.new(0, marker.Size.Y / 2 + humanoid.HipHeight + root.Size.Y / 2, 0))
	)
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	return true
end

function World:Discover()
	local folder = workspace:FindFirstChild("Queues")
	for id, object in pairs(self.objects) do
		if
			not folder
			or object.Instance.Parent ~= folder
			or not object.Enter:IsDescendantOf(object.Instance)
			or not object.EnterPos:IsDescendantOf(object.Instance)
			or not object.ExitPos:IsDescendantOf(object.Instance)
		then
			object.Touch:Disconnect()
			self.queues:Unregister(id)
			for _, member in pairs(object.Members) do
				member:Destroy()
			end
			self.byInstance[object.Instance] = nil
			self.errors[object.Instance] = nil
			self.objects[id] = nil
		end
	end
	if not folder then
		if not self.warnedFolder then
			warn("[DPU][Queue] Waiting for Workspace.Queues")
			self.warnedFolder = true
		end
		return
	end
	for _, queue in ipairs(folder:GetChildren()) do
		if self.byInstance[queue] then
			local object = self.objects[self.byInstance[queue]]
			local ui = queue:FindFirstChild("UI") or queue:FindFirstChild("UI", true)
			local board = ui and ui:FindFirstChildWhichIsA("BillboardGui", true)
			if board ~= object.Board then
				object.Board = board
				object.BoardView = board and Billboard.new(board) or nil
			end
			continue
		end
		local refs = queue:FindFirstChild("Refs") or queue:FindFirstChild("Refs", true)
		local enter = refs and refs:FindFirstChild("Enter")
		local enterPos = refs and refs:FindFirstChild("EnterPos")
		local exitPos = refs and refs:FindFirstChild("ExitPos")
		if
			not enter
			or not enter:IsA("BasePart")
			or not enterPos
			or not enterPos:IsA("BasePart")
			or not exitPos
			or not exitPos:IsA("BasePart")
		then
			if not self.errors[queue] then
				warn("[DPU][Queue] Missing BaseParts Refs.Enter/EnterPos/ExitPos:", queue:GetFullName())
				self.errors[queue] = true
			end
			continue
		end
		self.serial += 1
		local id = "Queue_" .. self.serial
		queue:SetAttribute("DPU_QueueId", id)
		local inQueue = queue:FindFirstChild("InQueue")
		if inQueue and not inQueue:IsA("Folder") then
			if not self.errors[queue] then
				warn("[DPU][Queue] InQueue must be a Folder:", queue:GetFullName())
				self.errors[queue] = true
			end
			continue
		end
		if not inQueue then
			inQueue = Instance.new("Folder")
			inQueue.Name = "InQueue"
			inQueue.Parent = queue
		end
		local ui = queue:FindFirstChild("UI") or queue:FindFirstChild("UI", true)
		local board = ui and ui:FindFirstChildWhichIsA("BillboardGui", true)
		self.objects[id] = {
			Instance = queue,
			Enter = enter,
			EnterPos = enterPos,
			ExitPos = exitPos,
			InQueue = inQueue,
			Board = board,
			BoardView = board and Billboard.new(board) or nil,
			Members = {},
		}
		self.byInstance[queue] = id
		self.queues:Register(id)
		-- Touched is the fast path; the bounds poll still covers missed physics contacts.
		enter.CanTouch = true
		self.objects[id].Touch = enter.Touched:Connect(function(hit)
			local character = hit.Parent
			if self.closing or not character or not character:IsA("Model") then
				return
			end
			local player = self.s.Players:GetPlayerFromCharacter(character)
			if
				player
				and player.Character == character
				and not self.blocked[player]
				and not self.queues.players[player]
				and not self.queues.busy[player]
			then
				local target = self:ClosestEntry(player)
				if target then
					self:TryEnter(player, target)
				end
			end
		end)
		print("[DPU][Queue] Bound " .. queue:GetFullName() .. " as " .. id)
		if not board then
			warn("[DPU][Queue] Missing UI.BillboardGui:", queue:GetFullName())
		end
	end
end

function World:Render()
	for id, object in pairs(self.objects) do
		local state = self.queues:Board(id)
		object.Instance:SetAttribute("DPU_QueueState", state.State)
		object.InQueue:SetAttribute("Count", state.Count)
		local present = {}
		for player, bay in pairs(self.queues.players) do
			if bay.Id ~= id then
				continue
			end
			present[player] = true
			if not object.Members[player] then
				local member = Instance.new("ObjectValue")
				member.Name = "DPU_" .. player.UserId
				member.Value = player
				member:SetAttribute("DPU_QueueMember", true)
				member.Parent = object.InQueue
				object.Members[player] = member
			end
		end
		for player, member in pairs(object.Members) do
			if not present[player] then
				member:Destroy()
				object.Members[player] = nil
			end
		end
		if object.BoardView then
			object.BoardView:Render(object.Instance, state, workspace:GetServerTimeNow())
		end
	end
end

function World:Tick()
	if self.closing then
		return
	end
	if os.clock() >= self.lastDiscovery then
		self.lastDiscovery = os.clock() + 2
		self:Discover()
	end
	self.queues:Tick()
	for _, player in ipairs(self.s.Players:GetPlayers()) do
		local inside = self:ClosestEntry(player)
		if not inside then
			self.blocked[player] = nil
			self.nextTry[player], self.errors[player] = nil, nil
		end
		if
			inside
			and not self.blocked[player]
			and not self.queues.players[player]
			and not self.queues.busy[player]
			and os.clock() >= (self.nextTry[player] or 0)
		then
			task.spawn(function()
				self:TryEnter(player, inside)
			end)
		end
	end
	self:Render()
end

function World:Remove(player)
	self.queues:Leave(player, true, false)
	self.blocked[player], self.nextTry[player], self.errors[player] = nil, nil, nil
end

function World:Shutdown()
	self.closing = true
	self.queues.closing = true
	for _, object in pairs(self.objects) do
		object.Touch:Disconnect()
	end
end

return World
