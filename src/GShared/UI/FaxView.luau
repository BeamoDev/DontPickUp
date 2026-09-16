-- Reusable keypad. Digits stay local; only CALL sends a server-validated ticket.
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
local errors = {
	InvalidTicket = "Enter all six numbers.",
	TicketNotFound = "Ticket not found. Check the numbers.",
	PhoneNotReady = "Repair and test this phone first.",
	FaxClosed = "Close this screen and use the fax again.",
	PleaseWait = "Wait a moment, then press CALL.",
	ConnectionError = "Waiting for the shop connection...",
}
function View.new(gui, deps)
	local self = setmetatable({ d = deps, connections = {}, digits = "" }, View)
	self.panel = make("Frame", gui, {
		Name = "FaxPhone",
		Size = UDim2.fromScale(0.92, 0.9),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.5,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 50,
	})
	make("UISizeConstraint", self.panel, { MaxSize = Vector2.new(460, 570) })
	local function text(name, y, height, size)
		return make("TextLabel", self.panel, {
			Name = name,
			Position = UDim2.fromScale(0.04, y),
			Size = UDim2.fromScale(0.92, height),
			BackgroundTransparency = 1,
			Text = "",
			TextColor3 = Color3.fromRGB(235, 230, 214),
			Font = Enum.Font.Code,
			TextSize = size,
			TextWrapped = true,
			ZIndex = 51,
		})
	end
	text("Title", 0.02, 0.06, 20).Text = "FAX PHONE / CUSTOMER PICKUP"
	self.tickets = text("Tickets", 0.09, 0.15, 15)
	self.message = text("Message", 0.24, 0.09, 15)
	self.display = text("Number", 0.33, 0.07, 23)
	local function button(name, label, x, y, w, h, callback)
		local control = make("TextButton", self.panel, {
			Name = name,
			Text = label,
			Position = UDim2.fromScale(x, y),
			Size = UDim2.fromScale(w, h),
			BackgroundColor3 = Color3.fromRGB(40, 38, 34),
			BackgroundTransparency = 0.2,
			TextColor3 = Color3.fromRGB(235, 230, 214),
			Font = Enum.Font.Code,
			TextSize = 17,
			TextWrapped = true,
			Selectable = true,
			ZIndex = 51,
		})
		table.insert(self.connections, control.Activated:Connect(callback))
		return control
	end
	for i, key in ipairs({ "1", "2", "3", "4", "5", "6", "7", "8", "9", "CLEAR", "0", "DELETE" }) do
		local control = button(
			"Key" .. key,
			key,
			0.04 + ((i - 1) % 3) * 0.31,
			0.42 + math.floor((i - 1) / 3) * 0.09,
			0.29,
			0.075,
			function()
				self:Key(key)
			end
		)
		self.first = self.first or control
	end
	self.call = button("Call", "CALL CUSTOMER", 0.04, 0.8, 0.44, 0.14, function()
		self:Call()
	end)
	self.close = button("Close", "CLOSE [Q / B]", 0.52, 0.8, 0.44, 0.14, function()
		self:Close()
	end)
	local digits = {
		Zero = "0",
		One = "1",
		Two = "2",
		Three = "3",
		Four = "4",
		Five = "5",
		Six = "6",
		Seven = "7",
		Eight = "8",
		Nine = "9",
	}
	table.insert(
		self.connections,
		deps.input.InputBegan:Connect(function(input, processed)
			if processed or not self.panel.Visible then
				return
			end
			local key = input.KeyCode.Name
			if key == "Q" or key == "ButtonB" then
				self:Close()
			elseif key == "Return" or key == "KeypadEnter" then
				self:Call()
			elseif key == "Backspace" then
				self:Key("DELETE")
			elseif digits[key] then
				self:Key(digits[key])
			elseif key:match("^Keypad%d$") then
				self:Key(key:sub(-1))
			end
		end)
	)
	return self
end
function View:Key(key)
	if not self.panel.Visible or self.busy then
		return
	end
	if key == "CLEAR" then
		self.digits = ""
	elseif key == "DELETE" then
		self.digits = self.digits:sub(1, -2)
	elseif #self.digits < 6 then
		self.digits ..= key
	end
	self.message.Text = "Enter the six-digit ticket, then press CALL."
	self.display.Text = self.digits .. string.rep("_", 6 - #self.digits)
end
function View:Call()
	if not self.panel.Visible or self.busy or not self.item then
		return
	end
	if #self.digits ~= 6 then
		self:Error("InvalidTicket")
		return
	end
	self.d.send("DialTicket", { FaxId = self.item.Id, Ticket = self.digits })
end
function View:Error(code)
	if self.panel.Visible then
		self.message.Text = errors[code] or "Could not call. Try again."
	end
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
	self.d.send("CloseFax", { FaxId = self.item.Id })
end
function View:Update(state, blocked, busy)
	self.busy = busy
	local item = state.Fax
	if
		not item
		or item.Id == self.dismissed
		or not state.Alive
		or state.Event
		or state.Phase == "Results"
		or self.d.clock() >= item.EndsAt
	then
		self:Hide()
		return
	end
	if blocked then
		if self.panel.Visible then
			self:Close()
		else
			self:Hide()
		end
		return
	end
	if not self.item or self.item.Id ~= item.Id then
		self.digits, self.lastMessage = "", nil
		self.message.Text = "Enter the six-digit ticket, then press CALL."
	end
	self.item = item
	local tickets = {}
	for _, ticket in ipairs(item.Tickets) do
		local status = ticket.Step == "ReadyForPickup" and "READY"
			or ticket.Step == "PickupArriving" and "ON THE WAY"
			or ticket.Step == "Return" and "AT COUNTER"
			or "FIXING"
		table.insert(tickets, ticket.Ticket .. " / " .. ticket.Customer .. " / " .. status)
	end
	self.tickets.Text = #tickets > 0 and table.concat(tickets, "\n") or "No phones dropped off yet."
	if item.Message ~= self.lastMessage then
		self.lastMessage = item.Message
		self.message.Text = item.Message or "Enter the six-digit ticket, then press CALL."
	end
	self.display.Text = self.digits .. string.rep("_", 6 - #self.digits)
	self.call.Active = not busy
	if not self.panel.Visible and self.d.gui then
		self.savedSelection = self.d.gui.SelectedObject
		if self.d.input.GamepadEnabled then
			self.d.gui.SelectedObject = self.first
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
