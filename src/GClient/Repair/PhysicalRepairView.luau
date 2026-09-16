-- Local 3D task pieces. Only completed gestures send revision-scoped puzzle moves.
local Tasks = require(script.Parent.PhysicalRepairTasks)
local View = {}
View.__index = View
local function make(class, parent, props)
	local object = Instance.new(class)
	for key, value in pairs(props) do
		object[key] = value
	end
	object.Parent = parent
	return object
end
local function pointer(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end
function View.new(gui, send, deps)
	local self = setmetatable({ d = deps, send = send, nodes = {}, connections = {}, tweens = {} }, View)
	self.hint = make("TextLabel", gui, {
		Name = "PhysicalRepairHint",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.new(0.92, 0, 0, 76),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.5,
		BorderSizePixel = 0,
		TextColor3 = Color3.fromRGB(234, 230, 222),
		Font = Enum.Font.Gotham,
		TextSize = 15,
		TextWrapped = true,
		Visible = false,
		ZIndex = 18,
	})
	make("UISizeConstraint", self.hint, { MaxSize = Vector2.new(620, 76) })
	self.mode = make("TextButton", gui, {
		Name = "RepairControlMode",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(0.98, 0, 0, 72),
		Size = UDim2.fromOffset(132, 38),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.5,
		BorderSizePixel = 0,
		TextColor3 = Color3.fromRGB(234, 230, 222),
		Font = Enum.Font.Gotham,
		TextSize = 13,
		Text = "USE BUTTONS",
		Visible = false,
		ZIndex = 18,
	})
	table.insert(
		self.connections,
		self.mode.Activated:Connect(function()
			self.fallback = not self.fallback
			self:Clear()
		end)
	)
	table.insert(
		self.connections,
		deps.input.InputBegan:Connect(function(input, processed)
			if not processed and pointer(input) then
				self:Begin(input)
			end
		end)
	)
	table.insert(
		self.connections,
		deps.input.InputChanged:Connect(function(input)
			local drag = self.drag
			if
				drag
				and (input == drag.Input or (drag.Mouse and input.UserInputType == Enum.UserInputType.MouseMovement))
			then
				drag.Screen = input.Position
			end
		end)
	)
	table.insert(
		self.connections,
		deps.input.InputEnded:Connect(function(input)
			local drag = self.drag
			if
				drag
				and (input == drag.Input or (drag.Mouse and input.UserInputType == Enum.UserInputType.MouseButton1))
			then
				self:Finish(input.Position)
			end
		end)
	)
	if deps.input.WindowFocusReleased then
		table.insert(
			self.connections,
			deps.input.WindowFocusReleased:Connect(function()
				self:CancelDrag()
			end)
		)
	end
	return self
end
function View:_canInput()
	local s, work = self.state, self.work
	local character = self.d.player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return self.folder
		and self.phone.Parent
		and s
		and s.Alive
		and not s.Event
		and not self.busy
		and not self.submitted
		and work
		and s.Seated
		and humanoid
		and humanoid.Health > 0
		and humanoid.Sit
		and self.d.cameraReady()
		and not self.d.menuOpen()
		and not (self.d.isBusy and self.d.isBusy())
end
-- Intersect the pointer ray with the phone plane; no physics or network drag simulation.
function View:Point(position)
	local camera = self.d.workspace.CurrentCamera
	if not camera or not self.frameOfPhone then
		return nil
	end
	local ray = camera:ScreenPointToRay(position.X, position.Y)
	local origin = self.frameOfPhone:PointToObjectSpace(ray.Origin)
	local direction = self.frameOfPhone:VectorToObjectSpace(ray.Direction)
	if math.abs(direction.Y) < 0.0001 then
		return nil
	end
	local distance = (0.15 - origin.Y) / direction.Y
	if distance < 0 then
		return nil
	end
	local hit = origin + direction * distance
	return Vector3.new(math.clamp(hit.X, -3.2, 3.2), 0.15, math.clamp(hit.Z, -1.8, 1.8))
end
function View:Hit(point, role)
	if not point then
		return nil
	end
	local nearest, distance
	for _, node in pairs(self.nodes) do
		local spec = node.Spec
		if not spec.Hidden and not spec.Disabled and not spec.Done and (not role or spec.Role == role) then
			local delta = point - spec.Position
			if math.abs(delta.X) <= spec.Size.X / 2 + 0.12 and math.abs(delta.Z) <= spec.Size.Z / 2 + 0.12 then
				local magnitude = delta.Magnitude
				if not distance or magnitude < distance then
					nearest, distance = node, magnitude
				end
			end
		end
	end
	return nearest
end
function View:_pose(node, point)
	return self.frameOfPhone * CFrame.new(point or node.Spec.Position) * CFrame.Angles(0, node.Spec.Rotation or 0, 0)
end
function View:_wire(node)
	if not node.Wire then
		return
	end
	local start = self.frameOfPhone:PointToWorldSpace(node.Spec.Wire)
	local finish = node.Part.CFrame.Position
	local length = (finish - start).Magnitude
	if length > 0.01 then
		node.Wire.Size = Vector3.new(0.06, 0.06, length)
		node.Wire.CFrame = CFrame.lookAt((start + finish) / 2, finish)
	end
end
function View:_moveHome(node)
	if self.tweens[node] then
		self.tweens[node]:Cancel()
	end
	local goal = self:_pose(node)
	if self.d.reduced() or node.Wire then
		node.Part.CFrame = goal
		self:_wire(node)
	else
		local tween = self.d.tweens:Create(
			node.Part,
			TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ CFrame = goal }
		)
		self.tweens[node] = tween
		tween:Play()
	end
end
function View:CancelDrag()
	local drag = self.drag
	self.drag = nil
	if drag and drag.Node.Part.Parent then
		self:_moveHome(drag.Node)
	end
end
function View:Submit(move)
	if not self:_canInput() then
		return false
	end
	self.submitted = { Key = self.revision, At = self.d.workspace:GetServerTimeNow(), SawBusy = false }
	self.selected = nil
	self.send("PuzzleInput", {
		WorkId = self.work.Id,
		OrderId = self.work.OrderId,
		PuzzleRevision = self.work.Puzzle.Revision,
		Move = move,
	})
	return true
end
function View:Begin(input)
	if not self:_canInput() then
		return
	end
	local point = self:Point(input.Position)
	local node = self:Hit(point)
	if not node then
		self.selected = nil
		return
	end
	if node.Spec.Role == "Drop" then
		if self.selected then
			self:Submit(self.selected.Spec.Index * 10 + node.Spec.Index)
		end
		return
	end
	if self.tweens[node] then
		self.tweens[node]:Cancel()
		self.tweens[node] = nil
	end
	self.drag = {
		Input = input,
		Mouse = input.UserInputType == Enum.UserInputType.MouseButton1,
		Node = node,
		Screen = input.Position,
		Start = point,
		Last = point,
		Travel = 0,
		Revision = self.revision,
	}
end
function View:Move()
	local drag = self.drag
	if not drag then
		return
	end
	if not self:_canInput() or drag.Revision ~= self.revision then
		self:CancelDrag()
		return
	end
	local point = self:Point(drag.Screen)
	if not point then
		return
	end
	local spec = drag.Node.Spec
	drag.Travel += (point - drag.Last).Magnitude
	drag.Last = point
	if spec.Role == "Drag" then
		drag.Node.Part.CFrame = self:_pose(drag.Node, point + Vector3.new(0, 0.12, 0))
		self:_wire(drag.Node)
	elseif spec.Role == "Turn" then
		local turn = math.clamp((point.X - drag.Start.X) * 5, -math.pi / 2, math.pi / 2)
		drag.Node.Part.CFrame = self:_pose(drag.Node) * CFrame.Angles(0, turn, 0)
	elseif spec.Role == "Scrub" then
		drag.Node.Part.Transparency = math.clamp((spec.Alpha or 0) + drag.Travel * 0.45, 0, 0.9)
	end
end
function View:Finish(position)
	local drag = self.drag
	if not drag then
		return
	end
	drag.Screen = position
	self:Move()
	if not self.drag then
		return
	end
	local spec, move = drag.Node.Spec, nil
	local point = self:Point(position)
	if spec.Role == "Drag" then
		local target = self:Hit(point, "Drop")
		if target then
			move = spec.Index * 10 + target.Spec.Index
		elseif drag.Travel < 0.12 then
			self.selected = drag.Node
		end
	elseif spec.Role == "Click" and self:Hit(point) == drag.Node then
		move = spec.Index
	elseif spec.Role == "Turn" and point and math.abs(point.X - drag.Start.X) >= 0.25 then
		move = spec.Index
	elseif spec.Role == "Scrub" and drag.Travel >= 0.45 then
		move = spec.Index
	end
	self:CancelDrag()
	if spec.Role == "Scrub" then
		drag.Node.Part.Transparency = spec.Alpha or 0
	end
	if move then
		self:Submit(move)
	end
end
function View:Clear()
	self:CancelDrag()
	if self.render then
		self.render:Disconnect()
		self.render = nil
	end
	for _, tween in pairs(self.tweens) do
		tween:Cancel()
	end
	for part, alpha in pairs(self.hidden or {}) do
		if part.Parent then
			part.LocalTransparencyModifier = alpha
		end
	end
	if self.folder then
		self.folder:Destroy()
	end
	self.folder, self.phone, self.frameOfPhone, self.identity, self.revision, self.submitted, self.selected =
		nil, nil, nil, nil, nil, nil, nil
	self.nodes, self.tweens, self.hidden = {}, {}, {}
	self.hint.Visible = false
end
function View:_sync(puzzle)
	local specs, hint = Tasks.Build(puzzle)
	local keep = {}
	for _, spec in ipairs(specs) do
		keep[spec.Id] = true
		local node = self.nodes[spec.Id]
		if not node then
			local part = make("Part", self.folder, {
				Name = spec.Id,
				Anchored = true,
				CanCollide = false,
				CanTouch = false,
				CanQuery = false,
				CastShadow = false,
				Material = Enum.Material.SmoothPlastic,
				Size = spec.Size,
			})
			local surface = make("SurfaceGui", part, {
				Face = Enum.NormalId.Top,
				SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
				PixelsPerStud = 140,
				LightInfluence = 0,
				AlwaysOnTop = false,
			})
			local label = make("TextLabel", surface, {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				TextScaled = true,
				TextWrapped = true,
				Font = Enum.Font.GothamBold,
				TextColor3 = Color3.fromRGB(22, 21, 19),
			})
			node = { Part = part, Label = label }
			self.nodes[spec.Id] = node
			if spec.Wire then
				node.Wire = make("Part", self.folder, {
					Name = spec.Id .. "Cable",
					Anchored = true,
					CanCollide = false,
					CanTouch = false,
					CanQuery = false,
					CastShadow = false,
					Color = spec.Color,
				})
			end
		end
		local wasDone = node.Spec and node.Spec.Done
		node.Spec = spec
		node.Part.Size, node.Part.Color = spec.Size, spec.Color
		node.Part.Transparency = (spec.Hidden or (spec.Done and spec.Remove)) and 1
			or spec.Ghost and 0.65
			or spec.Alpha
			or 0
		node.Label.Text, node.Label.Visible = spec.Text, not spec.Hidden and not (spec.Done and spec.Remove)
		if spec.Done and spec.Destination then
			for _, destination in ipairs(specs) do
				if destination.Id == spec.Destination then
					spec.Position = destination.Position + Vector3.new(0, 0.12, 0)
				end
			end
		end
		if spec.Done and not wasDone then
			self:_moveHome(node)
		else
			node.Part.CFrame = self:_pose(node)
		end
		self:_wire(node)
	end
	for id, node in pairs(self.nodes) do
		if not keep[id] then
			if self.tweens[node] then
				self.tweens[node]:Cancel()
				self.tweens[node] = nil
			end
			node.Part:Destroy()
			if node.Wire then
				node.Wire:Destroy()
			end
			self.nodes[id] = nil
		end
	end
	self.hint.Text = puzzle.Title
		.. "\n"
		.. hint
		.. "\n"
		.. (puzzle.Feedback or "Tap a part, then its slot also works.")
end
function View:Update(state, busy, blocked)
	self.state, self.work, self.busy = state, state.Work, busy
	local work = state.Work
	local eligible = work
		and Tasks.Supports(work.Puzzle)
		and state.Alive
		and state.Seated
		and state.Phase ~= "Results"
		and not state.NeedsRules
		and not state.Event
		and not blocked
		and not self.d.menuOpen()
		and (work.Station == "Bench" or work.Station == "Bench2")
		and (not state.SeatStation or state.SeatStation == work.Station)
		and (not work.UserId or work.UserId == self.d.player.UserId)
	self.mode.Visible = eligible == true
	local lastInput = self.d.input:GetLastInputType()
	local controller = lastInput == Enum.UserInputType.Gamepad1
	local available = eligible and self.d.cameraReady() and not self.fallback and not controller
	self.mode.Text = self.fallback and "USE 3D" or "USE BUTTONS"
	self.mode.AnchorPoint = Vector2.new(1, available and 1 or 0)
	self.mode.Position = available and UDim2.new(0.98, 0, 1, -12) or UDim2.new(0.98, 0, 0, 72)
	if not available then
		self:Clear()
		return false
	end
	local camera = self.d.workspace.CurrentCamera
	local narrow = camera and camera.ViewportSize.X < 500
	local short = camera and camera.ViewportSize.Y < 500
	self.hint.AnchorPoint = Vector2.new(narrow and 0.5 or 0, 1)
	self.hint.Position = narrow and UDim2.new(0.5, 0, 1, -58) or UDim2.new(0.02, 0, 1, -12)
	self.hint.Size = UDim2.new(narrow and 0.92 or 0.70, 0, 0, short and 54 or 76)
	self.hint.TextSize = short and 12 or 15
	local world = self.d.workspace:FindFirstChild("DPU_Prototype")
	local phone = world and world:FindFirstChild(state.PhoneName or "RepairPhone")
	local body = phone and phone:FindFirstChild("Body", true)
	if not body or not body:IsA("BasePart") then
		self:Clear()
		return false
	end
	local identity = table.concat(
		{ state.RunId, work.Id, work.OrderId, work.Puzzle.Kind, tostring(work.Puzzle.TaskIndex or 1) },
		":"
	)
	if self.identity ~= identity or self.phone ~= phone then
		self:Clear()
		self.identity, self.phone = identity, phone
		self.frameOfPhone = body.CFrame * CFrame.new(0, body.Size.Y / 2 + 0.08, 0)
		self.folder = make("Folder", self.d.workspace, { Name = "DPU_PhysicalRepair" })
		for _, component in ipairs(phone:GetDescendants()) do
			if component:IsA("BasePart") and component ~= body then
				self.hidden[component] = component.LocalTransparencyModifier or 0
				component.LocalTransparencyModifier = 1
			end
		end
		self.render = self.d.render.RenderStepped:Connect(function()
			if not self.d.cameraReady() or self.d.menuOpen() or not self.phone.Parent then
				self:Clear()
				return
			end
			self:Move()
		end)
	end
	local revision = identity .. ":" .. work.Puzzle.Revision
	if self.submitted then
		self.submitted.SawBusy = self.submitted.SawBusy or busy
		if
			self.submitted.Key ~= revision
			or (self.submitted.SawBusy and not busy)
			or self.d.workspace:GetServerTimeNow() - self.submitted.At > 12
		then
			self.submitted = nil
		end
	end
	if self.revision ~= revision then
		self:CancelDrag()
		self.selected, self.revision = nil, revision
		self:_sync(work.Puzzle)
	end
	self.hint.Visible = true
	return true
end
function View:Destroy()
	self:Clear()
	for _, connection in ipairs(self.connections) do
		connection:Disconnect()
	end
	self.hint:Destroy()
	self.mode:Destroy()
end
return View
