-- A small temporary ticket panel. Authored HUD/Subtitles are left intact.
local View = {}
View.__index = View
function View.new(playerGui)
	local gui = Instance.new("ScreenGui")
	gui.Name, gui.ResetOnSpawn, gui.DisplayOrder = "DPU_Orders", false, 5
	local panel = Instance.new("Frame")
	panel.Name, panel.AnchorPoint, panel.Position = "Ticket", Vector2.new(1, 0), UDim2.new(1, -16, 0, 76)
	panel.Size, panel.BackgroundColor3, panel.BackgroundTransparency =
		UDim2.fromOffset(270, 166), Color3.fromRGB(25, 31, 25), 0.08
	panel.BorderSizePixel, panel.Active, panel.Visible, panel.Parent = 0, true, false, gui
	local function label(name, y, height, color, size)
		local text = Instance.new("TextLabel")
		text.Name, text.Position, text.Size = name, UDim2.fromOffset(12, y), UDim2.new(1, -24, 0, height)
		text.BackgroundTransparency, text.Font, text.TextSize = 1, Enum.Font.Code, size
		text.TextColor3, text.TextWrapped = color, true
		text.TextXAlignment, text.TextYAlignment = Enum.TextXAlignment.Left, Enum.TextYAlignment.Top
		text.Parent = panel
		return text
	end
	local title = label("Title", 10, 22, Color3.fromRGB(222, 190, 141), 17)
	local problem = label("Problem", 38, 49, Color3.fromRGB(223, 223, 204), 14)
	local objective = label("Objective", 94, 43, Color3.fromRGB(168, 205, 160), 14)
	local reward = label("Payment", 143, 19, Color3.fromRGB(167, 173, 158), 12)
	gui.Parent = playerGui
	return setmetatable(
		{ gui = gui, panel = panel, title = title, problem = problem, objective = objective, reward = reward },
		View
	)
end
function View:Render(state)
	self.panel.Visible = state.Enabled == true
	self.title.Text = state.Id ~= "" and string.format("ORDER %03d / %s", state.Number, state.Customer)
		or "REPAIR SERVICE"
	self.problem.Text = state.Problem ~= "" and state.Problem or "The next customer will be here shortly."
	self.objective.Text = state.Task
	self.reward.Text = state.Stage == "Leaving" and "+10 CREDITS EACH / ORDER COMPLETE"
		or "PAYMENT: 10 CREDITS PER EMPLOYEE"
end
function View:Notice(text)
	self.objective.Text = text
end
function View:Destroy()
	self.gui:Destroy()
end
return View
