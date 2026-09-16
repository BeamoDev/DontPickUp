-- Personal, paginated document reader. Text arrives only after server inspection.
local View = {}
View.__index = View
local function make(class, parent, properties)
	local item = Instance.new(class)
	for key, value in pairs(properties) do
		item[key] = value
	end
	item.Parent = parent
	return item
end
local function pages(text)
	local result, page = {}, ""
	for word in text:gmatch("%S+") do
		if #page + #word > 210 then
			table.insert(result, page)
			page = ""
		end
		page ..= (page == "" and "" or " ") .. word
	end
	if page ~= "" then
		table.insert(result, page)
	end
	return result
end
function View.new(gui, deps)
	local self = setmetatable({ d = deps, connections = {} }, View)
	self.panel = make("Frame", gui, {
		Name = "Inspection",
		Size = UDim2.fromScale(0.92, 0.78),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.5,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 50,
	})
	make("UISizeConstraint", self.panel, { MaxSize = Vector2.new(620, 480) })
	local function label(name, y, size)
		return make("TextLabel", self.panel, {
			Name = name,
			Position = UDim2.new(0, 18, 0, y),
			Size = size,
			BackgroundTransparency = 1,
			Text = "",
			Font = Enum.Font.Code,
			TextSize = 18,
			TextWrapped = true,
			RichText = false,
			TextColor3 = Color3.fromRGB(235, 230, 214),
			ZIndex = 51,
		})
	end
	self.title = label("Title", 12, UDim2.new(1, -36, 0, 44))
	self.text = label("Document", 68, UDim2.new(1, -36, 1, -132))
	self.text.TextYAlignment = Enum.TextYAlignment.Top
	self.text.TextXAlignment = Enum.TextXAlignment.Left
	local function button(name, x, text, callback)
		local control = make("TextButton", self.panel, {
			Name = name,
			Position = UDim2.new(x, 8, 1, -52),
			Size = UDim2.new(1 / 3, -16, 0, 44),
			BackgroundColor3 = Color3.fromRGB(40, 38, 34),
			BackgroundTransparency = 0.2,
			TextColor3 = Color3.fromRGB(235, 230, 214),
			Font = Enum.Font.Code,
			TextSize = 14,
			TextWrapped = true,
			Text = text,
			Selectable = true,
			ZIndex = 51,
		})
		table.insert(self.connections, control.Activated:Connect(callback))
		return control
	end
	self.previous = button("Previous", 0, "PREVIOUS", function()
		self:Page(-1)
	end)
	self.close = button("Close", 1 / 3, "CLOSE [B / Q]", function()
		self:Close()
	end)
	self.next = button("Next", 2 / 3, "NEXT", function()
		self:Page(1)
	end)
	table.insert(
		self.connections,
		deps.input.InputBegan:Connect(function(input, processed)
			if
				self.panel.Visible
				and not processed
				and (input.KeyCode == Enum.KeyCode.ButtonB or input.KeyCode == Enum.KeyCode.Q)
			then
				self:Close()
			end
		end)
	)
	return self
end
function View:Page(delta)
	if not self.pages then
		return
	end
	self.page = math.clamp(self.page + delta, 1, #self.pages)
	self.text.Text = self.pages[self.page]
	self.title.Text = self.item.Title .. "\n" .. self.item.Format .. "  " .. self.page .. "/" .. #self.pages
	self.previous.Visible, self.next.Visible = self.page > 1, self.page < #self.pages
end
function View:Hide()
	if self.panel.Visible and self.d.gui then
		local selected = self.d.gui.SelectedObject
		if selected and selected:IsDescendantOf(self.panel) then
			self.d.gui.SelectedObject = self.savedSelection and self.savedSelection.Parent and self.savedSelection
				or nil
		end
	end
	self.panel.Visible = false
end
function View:Close()
	if not self.item then
		return
	end
	self.dismissed = self.item.Id
	self:Hide()
	self.d.send("CloseInspection", { InspectionId = self.item.Id })
end
function View:Update(state, blocked)
	local item = state.Inspection
	if
		not item
		or item.Id == self.dismissed
		or blocked
		or not state.Alive
		or state.Event
		or state.Phase == "Results"
		or self.d.clock() >= item.ExpiresAt
	then
		self:Hide()
		return
	end
	if not self.item or self.item.Id ~= item.Id then
		self.item, self.pages, self.page = item, pages(item.Text), 1
		self:Page(0)
	end
	if not self.panel.Visible and self.d.gui then
		self.savedSelection = self.d.gui.SelectedObject
		if self.d.input.GamepadEnabled then
			self.d.gui.SelectedObject = self.close
		end
	end
	self.panel.Visible = true
end
function View:Destroy()
	self:Hide()
	for _, connection in ipairs(self.connections) do
		connection:Disconnect()
	end
	self.panel:Destroy()
end
return View
