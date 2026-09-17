local Shared = game:GetService("ReplicatedStorage"):WaitForChild("GShared", 30)
local Definition = require(Shared:WaitForChild("Repair", 30):WaitForChild("RepairDefinition", 30))
local Query = require(Shared:WaitForChild("Interaction", 30):WaitForChild("InteractionQuery", 30))
local Drag = {}
Drag.__index = Drag
function Drag.new(owner, deps)
	local self = setmetatable({ owner = owner, d = deps, raycast = RaycastParams.new(), stick = Vector2.zero }, Drag)
	local line = Instance.new("Frame")
	line.Name, line.AnchorPoint, line.BorderSizePixel = "RepairWireDrag", Vector2.new(0.5, 0.5), 0
	line.BackgroundColor3, line.Active, line.Visible, line.Parent =
		Color3.fromRGB(160, 219, 130), false, false, deps.gui
	self.line = line
	local target = Instance.new("TextLabel")
	target.Name, target.Size, target.AnchorPoint = "RepairDropTarget", UDim2.fromOffset(90, 24), Vector2.new(0.5, 0.5)
	target.BackgroundTransparency, target.TextSize, target.Font = 0.4, 13, Enum.Font.Code
	target.BackgroundColor3, target.TextColor3 = Color3.fromRGB(12, 20, 12), Color3.fromRGB(160, 219, 130)
	target.Active, target.Visible, target.Parent = false, false, deps.gui
	self.target = target
	local cursor = Instance.new("Frame")
	cursor.Name, cursor.Size, cursor.AnchorPoint = "RepairGamepadCursor", UDim2.fromOffset(5, 5), Vector2.new(0.5, 0.5)
	cursor.BorderSizePixel, cursor.BackgroundColor3, cursor.Active = 0, Color3.new(1, 1, 1), false
	cursor.Visible, cursor.Parent = false, deps.gui
	self.cursor = cursor
	return self
end
function Drag:Pointer()
	if self.gesture and self.gesture.input.UserInputType == Enum.UserInputType.Touch then
		local p = self.gesture.input.Position
		return Vector2.new(p.X, p.Y)
	end
	if self.d.input.PreferredInput == Enum.PreferredInput.Gamepad then
		return self.pad or self.d.workspace.CurrentCamera.ViewportSize / 2
	end
	return self.d.input:GetMouseLocation()
end
function Drag:Coordinates(position)
	local s, camera = self.owner.session, self.d.workspace.CurrentCamera
	if not s or not s.reply or not camera then
		return nil
	end
	local ray = camera:ViewportPointToRay(position.X, position.Y)
	local plane, half = s.reply.Plane, s.reply.Half
	local g = self.gesture
	local origin = g and g.wireHeight and Vector3.new(plane.Position.X, g.wireHeight, plane.Position.Z)
		or plane.Position
	local normal = g and g.wireHeight and Vector3.yAxis or plane.UpVector
	local denominator = ray.Direction:Dot(normal)
	if math.abs(denominator) < 0.001 then
		return nil
	end
	local distance = (origin - ray.Origin):Dot(normal) / denominator
	if distance < 0 then
		return nil
	end
	local point = plane:PointToObjectSpace(ray.Origin + ray.Direction * distance)
	local x, y = math.clamp(point.X / half.X, -1, 1), math.clamp(point.Z / half.Y, -1, 1)
	local worldPoint = plane:PointToWorldSpace(Vector3.new(x * half.X, point.Y, y * half.Y))
	return x, y, worldPoint
end
-- Match the visible socket under the pointer, then send its installed planar
-- centre. This avoids depth/projection error and tiny world-space hit circles.
function Drag:WireDrop(position)
	local g, camera = self.gesture, self.d.workspace.CurrentCamera
	local pair = g and Definition.Pair(g.key)
	if not pair or not camera then
		return nil
	end
	local s = g.session
	local radius = self.d.input.PreferredInput == Enum.PreferredInput.Touch and 26 or 18
	local nearest, best = radius, nil
	local choices = {}
	for _, candidate in ipairs(Definition.Pairs) do
		choices[s.rig.keys[candidate.To]] = candidate.To
	end
	local ray = camera:ViewportPointToRay(position.X, position.Y)
	local _, hitKey = Query.Cast(
		self.d.workspace,
		self.d.collection,
		ray.Origin,
		ray.Direction * 80,
		self.raycast,
		{ self.d.player.Character },
		function(part)
			return choices[part]
		end,
		s.model
	)
	if hitKey then
		best, nearest = hitKey, -1
	end
	for _, candidate in ipairs(Definition.Pairs) do
		local slot = s.reply.Slots[candidate.To]
		local pixel, visible = camera:WorldToViewportPoint(slot.Position)
		local distance = (Vector2.new(pixel.X, pixel.Y) - position).Magnitude
		if visible and pixel.Z > 0 and distance < nearest then
			nearest, best = distance, candidate.To
		end
	end
	if best ~= pair.To then
		return nil
	end
	local slot = s.reply.Slots[best]
	if
		Query.Cast(
			self.d.workspace,
			self.d.collection,
			camera.CFrame.Position,
			slot.Position - camera.CFrame.Position,
			self.raycast,
			{ self.d.player.Character, s.model }
		)
	then
		return nil
	end
	local point = s.reply.Plane:PointToObjectSpace(slot.Position)
	return point.X / s.reply.Half.X, point.Z / s.reply.Half.Y, slot.Position
end
function Drag:Allowed(key)
	local s = self.owner.session
	if not s then
		return false
	end
	local wires, screws = {}, {}
	local wireMask, screwMask =
		s.model:GetAttribute("DPU_RepairWires") or 0, s.model:GetAttribute("DPU_RepairScrews") or 0
	for index = 1, 4 do
		wires[index] = bit32.band(wireMask, 2 ^ (index - 1)) ~= 0
		screws[index] = bit32.band(screwMask, 2 ^ (index - 1)) ~= 0
	end
	return Definition.Allowed(s.model:GetAttribute("DPU_RepairStage"), key, wires, screws)
end
function Drag:Pick(position)
	local s, camera = self.owner.session, self.d.workspace.CurrentCamera
	if not self.owner:Ready() or self.d.uiBlocked(position) then
		return nil
	end
	local choices = {}
	for key, part in pairs(s.rig.keys) do
		if self:Allowed(key) then
			choices[part] = key
		end
	end
	local ray = camera:ViewportPointToRay(position.X, position.Y)
	local _, picked = Query.Cast(
		self.d.workspace,
		self.d.collection,
		ray.Origin,
		ray.Direction * 80,
		self.raycast,
		{ self.d.player.Character },
		function(part)
			return choices[part]
		end,
		s.model
	)
	if picked then
		return picked
	end
	-- Small authored endpoints/screws get a modest screen-space hit radius.
	local radius = self.d.input.PreferredInput == Enum.PreferredInput.Touch and 26 or 16
	local best, nearest = nil, radius
	for part, key in pairs(choices) do
		local point, visible = camera:WorldToViewportPoint(part.Position)
		local distance = (Vector2.new(point.X, point.Y) - position).Magnitude
		if visible and point.Z > 0 and distance < nearest then
			local obstruction = Query.Cast(
				self.d.workspace,
				self.d.collection,
				camera.CFrame.Position,
				part.Position - camera.CFrame.Position,
				self.raycast,
				{ self.d.player.Character, s.model }
			)
			if not obstruction then
				best, nearest = key, distance
			end
		end
	end
	return best
end
function Drag:Cancel()
	self.cursor.Visible = false
	local g = self.gesture
	if not g then
		return
	end
	g.cancelled = true
	self.gesture = nil
	self.line.Visible, self.target.Visible = false, false
	if g.token and not g.sent then
		g.sent = true
		self.d.move:FireServer(g.token)
	end
end
function Drag:Drop(g)
	if not g.token or g.sent then
		return
	end
	if g.cancelled or self.gesture ~= g then
		g.sent = true
		self.d.move:FireServer(g.token)
		return
	end
	if not g.ended then
		return
	end
	g.sent = true
	self.line.Visible, self.target.Visible = false, false
	task.spawn(function()
		local ok, result = pcall(
			self.d.remote.InvokeServer,
			self.d.remote,
			"RepairDrop",
			{ Token = g.token, Revision = g.revision, X = g.x, Y = g.y }
		)
		if self.owner.session == g.session then
			if ok and type(result) == "table" and result.Ok then
				g.session.revision = result.Revision
				g.session.settling = os.clock() + (Definition.Pair(g.key) and 0 or 0.5)
			else
				local message = type(result) == "table"
						and result.Code == "Blocked"
						and "The socket is blocked. Clear the view and try again."
					or "Not connected. Release on the highlighted socket."
				self.owner:Hint(message, 1.5)
				self.d.move:FireServer(g.token)
			end
		end
		if self.gesture == g then
			self.gesture = nil
		end
	end)
end
function Drag:Begin(input, key, position)
	local s = self.owner.session
	local g = { input = input, key = key, session = s, revision = s.revision, started = os.clock() }
	self.gesture = g
	local pair = Definition.Pair(key)
	if pair then
		self.line.BackgroundColor3 = s.rig.wireParts[pair.Wire].Color
		self.target.TextColor3 = self.line.BackgroundColor3
		g.wireHeight = s.reply.Slots[key].Position.Y
		local _, _, start = self:Coordinates(position or self:Pointer())
		if not start then
			self:Cancel()
			return
		end
		g.startWorld = start
	end
	task.spawn(function()
		local ok, result = pcall(
			self.d.remote.InvokeServer,
			self.d.remote,
			"RepairGrab",
			{ Token = s.token, Key = key, Revision = g.revision }
		)
		if not ok or type(result) ~= "table" or not result.Ok then
			if self.gesture == g then
				self:Cancel()
			end
			return
		end
		g.token = result.Token
		self:Drop(g) -- Handles release/cancel before the grab reply.
	end)
end
function Drag:InputBegan(input, processed)
	if input.UserInputType == Enum.UserInputType.Touch and self.gesture and input ~= self.gesture.input then
		self:Cancel()
		return
	end
	if processed or not self.owner:Ready() then
		return
	end
	local press = input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
		or input.KeyCode == Enum.KeyCode.ButtonA
		or input.KeyCode == Enum.KeyCode.ButtonR2
		or input.KeyCode == Enum.KeyCode.E
	if not press or self.gesture then
		return
	end
	local position = input.UserInputType == Enum.UserInputType.Touch and Vector2.new(input.Position.X, input.Position.Y)
		or self:Pointer()
	local key = self:Pick(position)
	if key then
		self:Begin(input, key, position)
	end
end
function Drag:InputChanged(input)
	if input.KeyCode == Enum.KeyCode.Thumbstick1 then
		self.stick = Vector2.new(input.Position.X, -input.Position.Y)
	end
end
function Drag:InputEnded(input, processed)
	local g = self.gesture
	if not g then
		return
	end
	local same = input == g.input
		or (
			input.UserInputType ~= Enum.UserInputType.Touch
			and input.UserInputType == g.input.UserInputType
			and input.KeyCode == g.input.KeyCode
		)
	if not same then
		return
	end
	local position = input.UserInputType == Enum.UserInputType.Touch and Vector2.new(input.Position.X, input.Position.Y)
		or self:Pointer()
	local x, y = self:WireDrop(position)
	if not x then
		x, y = self:Coordinates(position)
	end
	if processed or self.d.blocked() or self.d.uiBlocked(position) or not x then
		self:Cancel()
		return
	end
	g.ended, g.x, g.y = true, x, y
	self:Drop(g)
end
function Drag:Update(dt)
	local camera, s = self.d.workspace.CurrentCamera, self.owner.session
	if not camera or not s then
		return
	end
	if self.d.input.PreferredInput == Enum.PreferredInput.Gamepad then
		local nextPoint = (self.pad or camera.ViewportSize / 2) + self.stick * math.min(dt or 0, 0.1) * 600
		self.pad = Vector2.new(
			math.clamp(nextPoint.X, 0, camera.ViewportSize.X),
			math.clamp(nextPoint.Y, 0, camera.ViewportSize.Y)
		)
	end
	local position, g = self:Pointer(), self.gesture
	self.cursor.Position = UDim2.fromOffset(position.X, position.Y)
	self.cursor.Visible = self.d.input.PreferredInput == Enum.PreferredInput.Gamepad and self.owner:Ready() == true
	if g and os.clock() - g.started > Definition.DragSeconds then
		self:Cancel()
		g = nil
	end
	if g then
		local pair = Definition.Pair(g.key)
		local slot = s.reply.Slots[pair and pair.To or g.key]
		local target, onScreen = camera:WorldToViewportPoint(slot.Position)
		self.target.Position, self.target.Text, self.target.Visible =
			UDim2.fromOffset(target.X, target.Y - 28), pair and pair.To or "DROP HERE", onScreen and not g.ended
		self.d.selection:Set(s.rig.keys[pair and pair.To or g.key])
		self.line.Visible = false
		if pair and not g.ended then
			local _, _, worldEnd = self:WireDrop(position)
			if worldEnd then
				worldEnd = Vector3.new(worldEnd.X, g.wireHeight, worldEnd.Z)
			else
				_, _, worldEnd = self:Coordinates(position)
			end
			if worldEnd then
				local start, startVisible = camera:WorldToViewportPoint(g.startWorld)
				local finish, endVisible = camera:WorldToViewportPoint(worldEnd)
				local a, b = Vector2.new(start.X, start.Y), Vector2.new(finish.X, finish.Y)
				local delta, midpoint = b - a, (a + b) / 2
				-- GUI rotation is around its centre regardless of AnchorPoint.
				-- Place the centre at the segment midpoint, not at the start socket.
				self.line.Position = UDim2.fromOffset(midpoint.X, midpoint.Y)
				self.line.Size = UDim2.fromOffset(delta.Magnitude, 8)
				self.line.Rotation = math.deg(math.atan2(delta.Y, delta.X))
				self.line.Visible = startVisible and endVisible and delta.Magnitude > 0.5
			end
		end
		if g.token and not g.ended and os.clock() >= (g.nextSend or 0) then
			local x, y = self:Coordinates(position)
			if x and (not g.last or (Vector2.new(x, y) - g.last).Magnitude > 0.002) then
				g.last, g.nextSend = Vector2.new(x, y), os.clock() + Definition.DragInterval
				self.d.move:FireServer(g.token, x, y)
			end
		end
	else
		self.line.Visible, self.target.Visible = false, false
		local key = self:Pick(position)
		self.d.selection:Set(key and s.rig.keys[key] or nil)
	end
end
function Drag:Destroy()
	self:Cancel()
	self.line:Destroy()
	self.target:Destroy()
	self.cursor:Destroy()
end
return Drag
