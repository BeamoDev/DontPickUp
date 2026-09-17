local UI = require(script.Parent.Parent.Interface.AuthoredUI)
-- One reusable input panel. Only the work owner receives the current puzzle.
local PhysicalView = require(script.Parent.PhysicalRepairView)
local View = {}
local TaskView = require(script.Parent.RepairTaskView)
View.__index = View
function View.new(gui, send, deps)
	local self = setmetatable({ connections = {}, send = send, d = deps or {} }, View)
	self.panel = UI.Bind("Frame", gui, "BenchPuzzle", { Visible = false })
	UI.Bind("UICorner", self.panel, nil)
	self.constraint = UI.Bind("UISizeConstraint", self.panel, nil)
	self.title = UI.Bind("TextLabel", self.panel, nil)
	self.hint = UI.Bind("TextLabel", self.panel, nil)
	self.buttons = {}
	for i = 1, 6 do
		local button = UI.Bind("TextButton", self.panel, "Input" .. i)
		self.buttons[i] = button
		table.insert(
			self.connections,
			button.Activated:Connect(function()
				local work = self.work
				if self.panel.Visible and not self.busy and work and work.Puzzle then
					self.send("PuzzleInput", {
						WorkId = work.Id,
						OrderId = work.OrderId,
						Move = i,
						PuzzleRevision = work.Puzzle.Revision,
					})
				end
			end)
		)
	end
	self.tasks = TaskView.new(self.panel, send, deps)
	if deps and deps.workspace then
		self.physical = PhysicalView.new(gui, send, deps)
	end
	return self
end
function View:Update(state, busy, blocked)
	self.work, self.busy = state.Work, busy
	if self.physical and self.physical:Update(state, busy, blocked) then
		self.panel.Visible = false
		self.tasks:Update(nil, busy, false)
		self.key = nil
		return
	end
	local work = state.Work
	local puzzle = work and work.Puzzle
	self.panel.Visible = puzzle ~= nil
		and state.Alive == true
		and not (state.WorkBlocked == true or state.WorkBlocked == nil and state.Event ~= nil)
		and not blocked
		and not (self.d.menuOpen and self.d.menuOpen())
		and (not work.UserId or not self.d.player or work.UserId == self.d.player.UserId)
		and (not state.SeatStation or (work.Station ~= "Bench" and work.Station ~= "Bench2") or state.SeatStation == work.Station)
		and ((work.Station ~= "Bench" and work.Station ~= "Bench2") or state.Seated == true)
	if not self.panel.Visible then
		self.tasks:Update(nil, busy, false)
		self.key = nil
		return
	end
	local camera = workspace.CurrentCamera
	local compact = camera and (camera.ViewportSize.X < 900 or camera.ViewportSize.Y < 650)
	local phone = puzzle.Kind == "Phone"
	local advanced = TaskView.Supports(puzzle)
	self.tasks:Update(advanced and work or nil, busy, advanced == true)
	local short = camera and camera.ViewportSize.Y < 450
	local key = work.Id
		.. ":"
		.. tostring(puzzle.Revision)
		.. ":"
		.. tostring(busy)
		.. ":"
		.. tostring(compact)
		.. ":"
		.. tostring(short)
	if key == self.key then
		return
	end
	self.key = key
	self.panel.AnchorPoint = Vector2.new(1, 1)
	self.panel.Position = UDim2.new(0.98, 0, 1, -12)
	self.panel.Size = UDim2.new(0.94, 0, 0, advanced and (short and 256 or 288) or 242)
	self.constraint.MaxSize =
		Vector2.new(phone and 460 or advanced and not compact and 520 or 390, phone and 320 or 288)
	if phone then
		self.panel.Size = UDim2.new(0.94, 0, 0, 320)
	end
	self.hint.Size = UDim2.new(1, -16, 0, phone and 158 or advanced and 52 or 86)
	self.hint.TextSize = advanced and compact and 12 or 14
	self.title.Text = puzzle.Title
		.. (
			puzzle.TaskCount and puzzle.TaskCount > 1 and (" / " .. puzzle.TaskIndex .. " OF " .. puzzle.TaskCount)
			or ""
		)
	local hint = puzzle.Hint
	if puzzle.Sequence and puzzle.Kind ~= "Memory" and puzzle.Kind ~= "Speaker" then
		local printed = {}
		for _, n in ipairs(puzzle.Sequence) do
			table.insert(
				printed,
				puzzle.Labels and puzzle.Labels[n] or tostring(puzzle.Kind == "PhoneNumber" and n % 10 or n)
			)
		end
		local nextItem = printed[puzzle.Progress + 1]
		hint = "COPY: "
			.. table.concat(printed, " - ")
			.. "\n"
			.. (nextItem and ("NEXT: " .. nextItem) or "DONE!")
			.. "  ("
			.. puzzle.Progress
			.. "/"
			.. #printed
			.. " done)"
	end
	self.hint.Text = hint .. "\n" .. (puzzle.Feedback or "")
	if advanced then
		self.hint.Text = hint
			.. "\n"
			.. (puzzle.Kind == "Memory" and (puzzle.Progress .. "/" .. puzzle.Count .. " correct. ") or "")
			.. (puzzle.Feedback or "")
		for _, button in ipairs(self.buttons) do
			button.Visible = false
		end
		return
	end
	local colors = { "BLACK", "RED", "GREEN" }
	for i, button in ipairs(self.buttons) do
		button.Position = UDim2.new(((i - 1) % 3) / 3, 6, 0, (phone and 204 or 130) + math.floor((i - 1) / 3) * 54)
		button.Active = not busy
		button.Visible = not puzzle.Cells or i <= 4
		if puzzle.Labels then
			button.Text, button.Visible = puzzle.Labels[i] or "", puzzle.Labels[i] ~= nil
		elseif puzzle.Cells and i <= 3 then
			local function value(n)
				return puzzle.Kind == "Battery" and (n == 1 and "+" or "-") or colors[n + 1]
			end
			button.Text = "MATCH " .. value(puzzle.Targets[i]) .. "\n[ " .. value(puzzle.Cells[i]) .. " ]"
		elseif puzzle.Cells then
			button.Text = "CHECK\nCONNECTION"
		else
			button.Text = tostring(i)
		end
	end
end
function View:Destroy()
	if self.physical then
		self.physical:Destroy()
	end
	self.tasks:Destroy()
	for _, connection in ipairs(self.connections) do
		connection:Disconnect()
	end
	UI.Release(self.panel)
end
return View
