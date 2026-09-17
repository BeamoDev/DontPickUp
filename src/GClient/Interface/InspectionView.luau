local UI = require(script.Parent.AuthoredUI)
-- Personal, paginated document reader. Text arrives only after server inspection.
local View = {}
View.__index = View
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
	self.panel = UI.Bind("Frame", gui, "Inspection", { Visible = false })
	UI.Bind("UISizeConstraint", self.panel, nil)
	local function label(name)
		return UI.Bind("TextLabel", self.panel, name, { Text = "" })
	end
	self.title = label("Title")
	self.text = label("Document")
	self.text.TextYAlignment = Enum.TextYAlignment.Top
	self.text.TextXAlignment = Enum.TextXAlignment.Left
	local function button(name, text, callback)
		local control = UI.Bind("TextButton", self.panel, name, { Text = text })
		table.insert(self.connections, control.Activated:Connect(callback))
		return control
	end
	self.previous = button("Previous", "PREVIOUS", function()
		self:Page(-1)
	end)
	self.close = button("Close", "CLOSE [B / Q]", function()
		self:Close()
	end)
	self.next = button("Next", "NEXT", function()
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
		or (state.WorkBlocked == true or state.WorkBlocked == nil and state.Event ~= nil)
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
	UI.Release(self.panel)
end
return View
