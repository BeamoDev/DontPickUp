local Shared = game:GetService("ReplicatedStorage"):WaitForChild("GShared", 30)
local Definition = require(Shared:WaitForChild("Repair", 30):WaitForChild("RepairDefinition", 30))
local Rig = require(Shared:WaitForChild("Repair", 30):WaitForChild("RepairRig", 30))
local Query = require(Shared:WaitForChild("Interaction", 30):WaitForChild("InteractionQuery", 30))
local Motion = require(script.Parent.RepairMotion)
local Service = {}
Service.__index = Service
function Service.new(services, eligible)
	return setmetatable({ s = services, eligible = eligible, items = {}, ids = {}, sessions = {} }, Service)
end
function Service:Add(model)
	if self.closed or self.items[model] then
		return
	end
	local id = self.s.HttpService:GenerateGUID(false)
	local record = { model = model, id = id }
	self.items[model], self.ids[id] = record, record
	model:SetAttribute("DPU_RepairId", id)
	model:SetAttribute("DPU_RepairStage", "Idle")
	model:SetAttribute("DPU_RepairOwner", nil)
end
function Service:Alive(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local head = character and character:FindFirstChild("Head")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if
		player.Parent == self.s.Players
		and root
		and head
		and humanoid
		and humanoid.Health > 0
		and not humanoid.Sit
		and self.eligible(player)
	then
		return character, root, head
	end
	return nil
end
function Service:Stage(session, stage)
	session.stage = stage
	session.record.model:SetAttribute("DPU_RepairStage", stage)
end
function Service:Valid(session)
	local character, root = self:Alive(session.player)
	if
		character ~= session.character
		or not session.record.model:IsDescendantOf(self.s.Workspace)
		or self.items[session.record.model] ~= session.record
		or os.clock() - session.started > Definition.SessionSeconds
	then
		return false
	end
	if (root.Position - session.origin).Magnitude > Definition.Distance then
		return false
	end
	for part in pairs(session.motion.saved) do
		if not part:IsDescendantOf(session.record.model) then
			return false
		end
	end
	return true
end
function Service:Finish(session, completed)
	if self.sessions[session.player] ~= session then
		return
	end
	self.sessions[session.player], session.record.session = nil, nil
	session.motion:Restore(completed)
	session.record.complete = completed == true
	self:Stage(session, completed and "Complete" or "Idle")
	session.record.model:SetAttribute("DPU_RepairOwner", nil)
	session.record.model:SetAttribute("DPU_RepairDrag", nil)
	if not next(self.sessions) and self.heartbeat then
		self.heartbeat:Disconnect()
		self.heartbeat = nil
	end
	if completed and self.completed then
		self.completed(session.record.model)
	end
end
-- Server-only integration: order completion is tied to this exact binding.
function Service:SetCompletionHandler(callback)
	self.completed = callback
end
function Service:IsComplete(model, id)
	local record = self.items[model]
	return record ~= nil and record.id == id and record.complete == true and model:IsDescendantOf(self.s.Workspace)
end
function Service:Begin(player, payload)
	local record = type(payload.Id) == "string" and self.ids[payload.Id]
	if not record or record.session or record.complete or self.sessions[player] then
		return { Ok = false, Code = "Unavailable" }
	end
	local character, root, head = self:Alive(player)
	if not character or not record.model:IsDescendantOf(self.s.Workspace) then
		return { Ok = false, Code = "Unavailable" }
	end
	local rig, reason = Rig.Read(record.model)
	if not rig then
		return { Ok = false, Code = reason }
	end
	if
		Query.Distance(rig.body, root.Position) > Definition.Distance
		or not Query.Visible(self.s.Workspace, self.s.CollectionService, character, head, rig.body, record.model)
	then
		return { Ok = false, Code = "OutOfReach" }
	end
	local motion, issue = Motion.new(rig, head)
	if not motion then
		return { Ok = false, Code = issue }
	end
	local session = {
		player = player,
		character = character,
		record = record,
		rig = rig,
		motion = motion,
		origin = root.Position,
		raycast = RaycastParams.new(),
		excluded = { character, record.model },
		started = os.clock(),
		token = self.s.HttpService:GenerateGUID(false),
		revision = 0,
		wires = {},
		screws = {},
	}
	self.sessions[player], record.session = session, session
	record.model:SetAttribute("DPU_RepairOwner", player.UserId)
	record.model:SetAttribute("DPU_RepairRevision", 0)
	record.model:SetAttribute("DPU_RepairWires", 0)
	record.model:SetAttribute("DPU_RepairScrews", 0)
	self:Stage(session, "Opening")
	motion:Prepare()
	if not self.heartbeat then
		self.heartbeat = self.s.RunService.Heartbeat:Connect(function(dt)
			self:Tick(dt)
		end)
	end
	return {
		Ok = true,
		Token = session.token,
		Revision = 0,
		Front = motion.frontView,
		Work = motion.workView,
		Plane = motion.plane,
		Half = motion.half,
		Snap = motion.snap,
		Slots = motion.slots,
	}
end
function Service:CancelDrag(session)
	local drag = session.drag
	if not drag then
		return
	end
	if not drag.wire and drag.part.Parent then
		drag.part.CFrame = session.motion.loose[drag.key]
	end
	session.drag = nil
	session.record.model:SetAttribute("DPU_RepairDrag", nil)
end
function Service:Drag(player, token, x, y)
	local session = self.sessions[player]
	if session and x == nil and y == nil then
		-- Cancellation is idempotent and bypasses the gameplay request bucket.
		if token == session.token then
			self:Finish(session, false)
		elseif session.drag and token == session.drag.token then
			self:CancelDrag(session)
		end
		return
	end
	local drag = session and session.drag
	if not drag or drag.token ~= token then
		return
	end
	local point = Definition.Point(session.motion.plane, session.motion.half, x, y)
	if point then
		drag.pending = point
	end -- One latest sample, applied at a bounded rate in Tick.
end
-- Inspection happens above the bench, not from the frozen first-person head.
-- Validate both legs so the desk lip cannot reject a visible socket while
-- intervening walls still block access to the work area.
function Service:WorkVisible(session, head, target)
	local origin = Vector3.new(target.X, math.max(head.Position.Y, target.Y + 2), target.Z)
	for _, segment in ipairs({ { head.Position, origin }, { origin, target } }) do
		if
			Query.Cast(
				self.s.Workspace,
				self.s.CollectionService,
				segment[1],
				segment[2] - segment[1],
				session.raycast,
				session.excluded
			)
		then
			return false
		end
	end
	return true
end
function Service:Request(player, action, payload)
	if self.closed or type(payload) ~= "table" then
		return { Ok = false, Code = "InvalidRequest" }
	end
	if action == "BeginRepair" then
		return self:Begin(player, payload)
	end
	local session = self.sessions[player]
	if not session then
		return { Ok = false, Code = "Changed" }
	end
	if not self:Valid(session) then
		self:Finish(session, false)
		return { Ok = false, Code = "Unavailable" }
	end
	if action == "CancelRepair" and payload.Token == session.token then
		self:Finish(session, false)
		return { Ok = true }
	end
	if action == "RepairGrab" then
		local key = payload.Key
		if
			payload.Token ~= session.token
			or payload.Revision ~= session.revision
			or session.drag
			or session.install
			or not Definition.Allowed(session.stage, key, session.wires, session.screws)
		then
			return { Ok = false, Code = "WrongStep" }
		end
		local pair = Definition.Pair(key)
		local token = self.s.HttpService:GenerateGUID(false)
		session.drag = { token = token, key = key, part = session.rig.keys[key], wire = pair, started = os.clock() }
		session.record.model:SetAttribute("DPU_RepairDrag", key)
		return { Ok = true, Token = token }
	end
	local drag = session.drag
	if not drag or drag.token ~= payload.Token then
		return { Ok = false, Code = "Changed" }
	end
	if action == "RepairRelease" then
		self:CancelDrag(session)
		return { Ok = true }
	end
	if action ~= "RepairDrop" or payload.Revision ~= session.revision then
		return { Ok = false, Code = "Changed" }
	end
	local point = Definition.Point(session.motion.plane, session.motion.half, payload.X, payload.Y)
	local target = session.motion.slots[drag.wire and drag.wire.To or drag.key]
	local planar = point and session.motion.plane:VectorToObjectSpace(point - target.Position)
	local radius = session.motion.snap
	if drag.wire then
		for _, pair in ipairs(Definition.Pairs) do
			if pair.To ~= drag.wire.To then
				local delta =
					session.motion.plane:VectorToObjectSpace(session.motion.slots[pair.To].Position - target.Position)
				radius = math.min(radius, Vector2.new(delta.X, delta.Z).Magnitude * 0.45)
			end
		end
	end
	if not planar or Vector2.new(planar.X, planar.Z).Magnitude > radius then
		self:CancelDrag(session)
		return { Ok = false, Code = "WrongTarget" }
	end
	local _, _, head = self:Alive(player)
	local endpoint = session.rig.keys[drag.wire and drag.wire.To or drag.key]
	local destination = target.Position
	if drag.wire then
		destination = Query.SurfacePoint(endpoint, target.Position + Vector3.yAxis * 4) + Vector3.yAxis * 0.02
	end
	if not self:WorkVisible(session, head, destination) then
		self:CancelDrag(session)
		return { Ok = false, Code = "Blocked" }
	end
	session.drag = nil
	session.record.model:SetAttribute("DPU_RepairDrag", nil)
	session.revision += 1
	session.record.model:SetAttribute("DPU_RepairRevision", session.revision)
	if drag.wire then
		local _, index = Definition.Pair(drag.key)
		session.wires[index] = true
		session.rig.wireParts[drag.wire.Wire].Transparency = 0
		local mask = 0
		for i in pairs(session.wires) do
			mask += 2 ^ (i - 1)
		end
		session.record.model:SetAttribute("DPU_RepairWires", mask)
		if Definition.All(session.wires) then
			session.motion:Markers(false)
			self:Stage(session, "Battery")
		end
	else
		session.install =
			{ key = drag.key, part = drag.part, from = drag.part.CFrame, target = target, started = os.clock() }
	end
	return { Ok = true, Revision = session.revision }
end
function Service:Tick(dt)
	for _, session in pairs(self.sessions) do
		if not self:Valid(session) then
			self:Finish(session, false)
			continue
		end
		local now, motion = os.clock(), session.motion
		if session.stage == "Opening" then
			local elapsed = now - session.started
			local label = motion:Advance(elapsed)
			if session.label ~= label then
				session.label = label
				session.record.model:SetAttribute("DPU_RepairHint", label)
			end
			if elapsed >= motion.duration then
				motion:Markers(true)
				self:Stage(session, "Wires")
			end
		elseif session.stage == "Finishing" then
			local alpha = math.clamp((now - session.finishedAt) / 0.6, 0, 1)
			local eased = alpha * alpha * alpha * (alpha * (alpha * 6 - 15) + 10)
			local body = motion.rig.body
			local from = session.returnFrames[body]
			local target = motion.saved[body].frame
			local frame = from:Lerp(target, eased)
			for part, saved in pairs(motion.saved) do
				part.CFrame = frame
					* from:ToObjectSpace(session.returnFrames[part]):Lerp(target:ToObjectSpace(saved.frame), eased)
			end
			if alpha == 1 then
				self:Finish(session, true)
			end
		elseif session.install then
			local install = session.install
			local t = math.clamp((now - install.started) / 0.45, 0, 1)
			local a = t * t * t * (t * (t * 6 - 15) + 10)
			install.part.CFrame = install.from:Lerp(install.target, a)
			local index = tonumber(install.key:match("^Screw([1-4])$"))
			if index then
				install.part.CFrame *= CFrame.Angles(0, 0, (1 - a) * math.pi * 4)
			end
			if t == 1 then
				session.install = nil
				if install.key == "Battery" then
					self:Stage(session, "Cover")
				elseif install.key == "BackCover" then
					self:Stage(session, "Screws")
				else
					session.screws[index] = true
					local mask = 0
					for i in pairs(session.screws) do
						mask += 2 ^ (i - 1)
					end
					session.record.model:SetAttribute("DPU_RepairScrews", mask)
					if Definition.All(session.screws) then
						self:Stage(session, "Finishing")
						session.finishedAt, session.returnFrames = now, {}
						for part in pairs(motion.saved) do
							session.returnFrames[part] = part.CFrame
						end
					end
				end
			end
		elseif session.drag then
			local drag = session.drag
			if now - drag.started > Definition.DragSeconds then
				self:CancelDrag(session)
				continue
			end
			if drag.pending and now >= (drag.nextMove or 0) then
				local _, _, head = self:Alive(session.player)
				local hit = Query.Cast(
					self.s.Workspace,
					self.s.CollectionService,
					head.Position,
					drag.pending - head.Position,
					session.raycast,
					session.excluded
				)
				drag.target, drag.pending, drag.nextMove =
					not hit and drag.pending or nil, nil, now + Definition.DragInterval
			end
			if drag.target and not drag.wire then
				local target = CFrame.new(drag.target + Vector3.yAxis * 0.18) * motion.slots[drag.key].Rotation
				drag.part.CFrame = drag.part.CFrame:Lerp(target, 1 - math.exp(-24 * dt))
			end
		end
	end
end
function Service:Remove(player)
	if self.sessions[player] then
		self:Finish(self.sessions[player], false)
	end
end
function Service:Drop(model)
	local record = self.items[model]
	if not record then
		return
	end
	if record.session then
		self:Finish(record.session, false)
	end
	self.items[model], self.ids[record.id] = nil, nil
	for _, name in ipairs({ "Id", "Owner", "Stage", "Revision", "Wires", "Screws", "Hint", "Drag" }) do
		model:SetAttribute("DPU_Repair" .. name, nil)
	end
end
function Service:Shutdown()
	self.closed = true
	for model in pairs(self.items) do
		self:Drop(model)
	end
end
return Service
