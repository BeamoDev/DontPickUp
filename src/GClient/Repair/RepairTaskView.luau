local UI = require(script.Parent.Parent.Interface.AuthoredUI)
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("GShared", 30)
-- Pooled task surfaces; drag previews are local and send one discrete move on release.
local Extra = require(script.Parent.BenchTaskView)
local View = {}
View.__index = View
local ACCENT, WHITE, BLACK = Color3.fromRGB(220, 213, 200), Color3.fromRGB(235, 235, 235), Color3.new(0, 0, 0)
local Public = require(Shared:WaitForChild("Repair", 30):WaitForChild("RepairDefinitions", 30))
local KINDS = Public.TaskKinds
local NAMES = Public.PartNames
local MARKS = { "A / +", "B / -", "C / +" }
local COLORS = {
	Color3.fromRGB(240, 140, 105),
	Color3.fromRGB(125, 185, 245),
	Color3.fromRGB(225, 205, 115),
	Color3.fromRGB(135, 195, 140),
}
function View.Supports(puzzle)
	return puzzle and (KINDS[puzzle.Kind] == true or Extra.Supports(puzzle))
end
function View.new(parent, send, deps)
	local self = setmetatable({
		send = send,
		d = deps or {},
		connections = {},
		buttons = {},
		arms = {},
		lines = {},
		dials = {},
		needles = {},
		dialLabels = {},
	}, View)
	self.root = UI.Bind("Frame", parent, "TaskSurface", { Visible = false })
	for i = 1, 12 do
		local button = UI.Bind("TextButton", self.root, "Control" .. i, { Text = "" })
		UI.Bind("UIStroke", button, nil)
		self.buttons[i], self.arms[i] = button, {}
		if i <= 3 then
			local dial = UI.Bind("Frame", button, "Dial", { Visible = false })
			UI.Bind("UICorner", dial, nil)
			UI.Bind("UIStroke", dial, nil)
			self.dials[i] = dial
			local rotor = UI.Bind("Frame", dial, nil)
			UI.Bind("Frame", rotor, nil)
			self.needles[i] = rotor
			self.dialLabels[i] = UI.Bind("TextLabel", dial, nil)
		end
		for direction = 0, 3 do
			self.arms[i][direction + 1] = UI.Bind("Frame", button, "Trace" .. direction, { Visible = false })
		end
		table.insert(
			self.connections,
			button.Activated:Connect(function()
				self:Activate(i)
			end)
		)
		if self.d.input then
			table.insert(
				self.connections,
				button.InputBegan:Connect(function(input)
					self:BeginDrag(i, input)
				end)
			)
		end
	end
	for i = 1, 4 do
		self.lines[i] = UI.Bind("Frame", self.root, "Wire" .. i, { Visible = false })
	end
	self.check = UI.Bind("TextButton", self.root, "Check", { Text = "TEST" })
	table.insert(
		self.connections,
		self.check.Activated:Connect(function()
			if
				self.work
				and (self.work.Puzzle.Kind == "Memory" or self.work.Puzzle.Kind == "Speaker")
				and workspace:GetServerTimeNow() < self.work.Puzzle.RevealUntil
			then
				return
			end
			self:Submit(7)
		end)
	)
	self.ghost = UI.Bind("TextLabel", self.root, "DraggedItem", { Visible = false })
	self.extra = Extra.new(self.root)
	if self.d.input then
		table.insert(
			self.connections,
			self.d.input.InputChanged:Connect(function(input)
				self:MoveDrag(input)
			end)
		)
		table.insert(
			self.connections,
			self.d.input.InputEnded:Connect(function(input)
				self:EndDrag(input)
			end)
		)
		if self.d.input.WindowFocusReleased then
			table.insert(
				self.connections,
				self.d.input.WindowFocusReleased:Connect(function()
					self:CancelDrag()
					self.key = nil
					self:Render()
				end)
			)
		end
	end
	return self
end
function View:CancelDrag()
	self.drag, self.selected = nil, nil
	self.ghost.Visible = false
end
function View:Submit(move, token)
	local work = self.work
	if not self.root.Visible or self.busy or not work or not work.Puzzle then
		return
	end
	if token and (token.Id ~= work.Id or token.Revision ~= work.Puzzle.Revision) then
		return
	end
	self:CancelDrag()
	self.send(
		"PuzzleInput",
		{ WorkId = work.Id, OrderId = work.OrderId, Move = move, PuzzleRevision = work.Puzzle.Revision }
	)
end
function View:Activate(i)
	if
		self.busy
		or not self.root.Visible
		or not self.buttons[i].Visible
		or not self.buttons[i].Active
		or os.clock() < (self.ignoreClickUntil or 0)
	then
		return
	end
	local puzzle = self.work.Puzzle
	if (puzzle.Kind == "Memory" or puzzle.Kind == "Speaker") and workspace:GetServerTimeNow() < puzzle.RevealUntil then
		return
	end
	if puzzle.Kind == "Wires" or puzzle.Kind == "BatteryFit" or Extra.Pair(puzzle) then
		local count = puzzle.Kind == "Wires" and #puzzle.Slots or 3
		if i <= count and self.buttons[i].Visible and (not puzzle.Placed or not puzzle.Placed[i]) then
			self.selected = i
			self.key = nil
			self:Render()
		elseif i > count and i <= count * 2 and self.buttons[i].Visible and self.selected then
			self:Submit(self.selected * 10 + i - count)
		end
	else
		self:Submit(i)
	end
end
function View:BeginDrag(i, input)
	local count = self.work and self.work.Puzzle.Kind == "Wires" and #self.work.Puzzle.Slots or 3
	if not self.root.Visible or self.busy or i > count or self.drag then
		return
	end
	local puzzle = self.work.Puzzle
	if
		(puzzle.Kind ~= "Wires" and puzzle.Kind ~= "BatteryFit" and not Extra.Pair(puzzle))
		or not self.buttons[i].Visible
		or (puzzle.Placed and puzzle.Placed[i])
	then
		return
	end
	local kind = input.UserInputType
	if kind ~= Enum.UserInputType.MouseButton1 and kind ~= Enum.UserInputType.Touch then
		return
	end
	local button = self.buttons[i]
	local pointer = Vector2.new(input.Position.X, input.Position.Y)
	self.selected = i
	self.drag = {
		Item = i,
		Input = input,
		Mouse = kind == Enum.UserInputType.MouseButton1,
		Pointer = pointer,
		LastPointer = pointer,
		Start = button.AbsolutePosition - self.root.AbsolutePosition + button.AbsoluteSize / 2,
		Id = self.work.Id,
		Revision = puzzle.Revision,
		RootPosition = self.root.AbsolutePosition,
		RootSize = self.root.AbsoluteSize,
	}
	self.key = nil
	self:Render()
end
function View:MoveDrag(input)
	local drag = self.drag
	if not drag then
		return
	end
	if drag.RootPosition ~= self.root.AbsolutePosition or drag.RootSize ~= self.root.AbsoluteSize then
		self:CancelDrag()
		return
	end
	if input ~= drag.Input and not (drag.Mouse and input.UserInputType == Enum.UserInputType.MouseMovement) then
		return
	end
	drag.LastPointer = Vector2.new(input.Position.X, input.Position.Y)
	local delta = drag.LastPointer - drag.Pointer
	if delta.Magnitude < 6 then
		return
	end
	drag.Moved = true
	local position = drag.Start + delta
	self.ghost.Position = UDim2.fromOffset(position.X, position.Y)
	self.ghost.Text = self.buttons[drag.Item].Text
	self.ghost.Visible = true
end
function View:EndDrag(input)
	local drag = self.drag
	if
		not drag
		or (input ~= drag.Input and not (drag.Mouse and input.UserInputType == Enum.UserInputType.MouseButton1))
	then
		return
	end
	if
		input.UserInputState == Enum.UserInputState.Cancel
		or drag.RootPosition ~= self.root.AbsolutePosition
		or drag.RootSize ~= self.root.AbsoluteSize
	then
		self:CancelDrag()
		return
	end
	if not drag.Mouse then
		drag.LastPointer = Vector2.new(input.Position.X, input.Position.Y)
	end
	local position = self.root.AbsolutePosition + drag.Start + drag.LastPointer - drag.Pointer
	self.drag, self.ghost.Visible = nil, false
	if not drag.Moved then
		return
	end
	self.ignoreClickUntil = os.clock() + 0.15
	local count = self.work.Puzzle.Kind == "Wires" and #self.work.Puzzle.Slots or 3
	for slot = 1, count do
		local object = self.buttons[slot + count]
		local origin, size = object.AbsolutePosition, object.AbsoluteSize
		if
			object.Visible
			and object.Active
			and position.X >= origin.X
			and position.X <= origin.X + size.X
			and position.Y >= origin.Y
			and position.Y <= origin.Y + size.Y
		then
			self:Submit(drag.Item * 10 + slot, drag)
			return
		end
	end
	self.selected, self.key = nil, nil
	self:Render()
end
local function connect(line, a, b)
	local delta = b - a
	local center = (a + b) / 2
	line.Position, line.Size, line.Rotation =
		UDim2.fromOffset(center.X, center.Y),
		UDim2.fromOffset(delta.Magnitude, 3),
		math.deg(math.atan2(delta.Y, delta.X))
	line.Visible = true
end
function View:Update(work, busy, visible)
	local identity = work and (work.Id .. ":" .. work.Puzzle.Revision) or nil
	local changed = identity ~= self.identity
	self.identity = identity
	self.work, self.busy = work, busy
	self.root.Visible = visible == true
	if changed or busy or not visible then
		self:CancelDrag()
	end
	if not visible then
		self.extra:Hide()
		self.key = nil
		return
	end
	self:Render()
end
function View:Render()
	if not self.root.Visible then
		return
	end
	local p = self.work.Puzzle
	local now = workspace:GetServerTimeNow()
	local reduced = self.d.reduced and self.d.reduced() or false
	local watching = (p.Kind == "Memory" or p.Kind == "Speaker") and now < p.RevealUntil
	local step = watching and math.floor((now - p.RevealAt) / 0.7) + 1 or 0
	local lit = watching and (now - p.RevealAt) % 0.7 < 0.5 and p.Sequence[step] or 0
	if Extra.Supports(p) then
		self.key = nil
		self.extra:Render(self, p, watching, lit, reduced)
		return
	end
	self.extra:Hide()
	local key = self.work.Id
		.. ":"
		.. p.Revision
		.. ":"
		.. tostring(self.busy)
		.. ":"
		.. tostring(self.selected)
		.. ":"
		.. tostring(lit)
		.. ":"
		.. tostring(step)
		.. ":"
		.. tostring(watching)
		.. ":"
		.. tostring(reduced)
		.. ":"
		.. tostring(self.root.AbsoluteSize)
	if self.key == key then
		return
	end
	self.key = key
	self.check.Visible = p.Kind == "Circuit" or p.Kind == "Dials" or p.Kind == "Memory"
	self.check.Active = not self.busy and not watching
	self.check.Text = p.Kind == "Memory"
			and (now < p.RevealAt and "GET READY" or watching and ("WATCH " .. math.min(step, p.Count) .. "/" .. p.Count) or "WATCH AGAIN")
		or p.Kind == "Dials" and "CHECK NUMBERS"
		or "CHECK PATH"
	for _, line in ipairs(self.lines) do
		line.Visible = false
	end
	for i, button in ipairs(self.buttons) do
		local count = p.Kind == "Wires" and #p.Slots or 3
		button.Visible, button.Active, button.Rotation = i <= count * 2, not self.busy and not watching, 0
		if i > count * 2 then
			continue
		end
		button.BackgroundColor3, button.TextColor3 = BLACK, WHITE
		button.TextYAlignment = Enum.TextYAlignment.Center
		button.TextXAlignment, button.TextSize = Enum.TextXAlignment.Center, 14
		button.Position = UDim2.new((i - 1) % 3 / 3, 4, math.floor((i - 1) / 3) * 0.37, 0)
		button.Size = UDim2.new(1 / 3, -8, 0.34, -2)
		for _, arm in ipairs(self.arms[i]) do
			arm.Visible = false
		end
		if self.dials[i] then
			self.dials[i].Visible = p.Kind == "Dials"
		end
		if p.Kind == "Wires" or p.Kind == "BatteryFit" then
			local item = i <= count and i or p.Slots[i - count]
			button.Position = UDim2.new(i <= count and 0 or 0.7, 0, ((i - 1) % count) / count, 2)
			button.Size = UDim2.new(0.3, 0, 1 / count, -6)
			button.Text = p.Kind == "Wires" and ((i <= count and "WIRE " or "SPACE ") .. item)
				or ((i <= count and "BATTERY " or "SPACE ") .. MARKS[item])
			button.TextColor3 = COLORS[item]
			if p.Placed[item] then
				button.Text = p.Kind == "Wires" and "CONNECTED " .. item or "FITTED " .. MARKS[item]
				button.Active = false
				button.TextColor3 = ACCENT
				if p.Kind == "BatteryFit" and i <= count then
					button.Visible = false
				end
			end
			if self.selected == i then
				button.Text = "[ " .. button.Text .. " ]"
			end
		elseif p.Kind == "Probes" then
			local index = (i - 1) % 3 + 1
			button.Text = i <= 3 and ((p.Tested[i] and "" or "CHECK ") .. NAMES[i] .. "\n" .. p.Readings[i])
				or ("REPLACE\n" .. NAMES[index])
			if i > 3 then
				button.Visible = p.Progress == 3
			end
		elseif p.Kind == "Circuit" then
			button.Text = i == 1 and "START" or i == 4 and "END" or ""
			button.TextYAlignment, button.TextXAlignment, button.TextSize =
				Enum.TextYAlignment.Top, Enum.TextXAlignment.Left, 11
			local rotation = p.Rotations[i]
			local a, b = rotation % 4, (rotation + (p.Shapes[i] == "Straight" and 2 or 1)) % 4
			self.arms[i][a + 1].Visible, self.arms[i][b + 1].Visible = true, true
		elseif p.Kind == "Dials" then
			button.Visible = i <= 3
			if i <= 3 then
				button.Size = UDim2.new(1 / 3, -8, 1, -52)
				button.TextYAlignment = Enum.TextYAlignment.Bottom
				button.Text = "TURN / " .. p.Values[i]
				self.dialLabels[i].Text = "MATCH " .. p.Targets[i]
				self.needles[i].Rotation = (p.Values[i] - 3) * 60
			end
		else
			button.Text = tostring(i)
			if watching and lit == i then
				button.Text = "[ " .. i .. " ]"
				if not reduced then
					button.BackgroundColor3 = Color3.fromRGB(65, 59, 50)
				end
			end
		end
	end
	if p.Kind == "Wires" and self.root.AbsoluteSize and self.root.AbsoluteSize.X > 0 then
		local size = self.root.AbsoluteSize
		for item, placed in ipairs(p.Placed) do
			if placed then
				local slot = table.find(p.Slots, item)
				connect(
					self.lines[item],
					Vector2.new(size.X * 0.3, size.Y * ((item - 0.5) / #p.Slots)),
					Vector2.new(size.X * 0.7, size.Y * ((slot - 0.5) / #p.Slots))
				)
			end
		end
	end
end
function View:Destroy()
	self.extra:Hide()
	self:CancelDrag()
	for _, connection in ipairs(self.connections) do
		connection:Disconnect()
	end
	UI.Release(self.root)
end
return View
