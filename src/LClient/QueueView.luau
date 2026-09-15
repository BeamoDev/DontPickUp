local View = {}
View.__index = View
local SELECTED = Color3.fromRGB(4, 255, 0)
local UNSELECTED = Color3.fromRGB(58, 58, 58)
local MESSAGES = {
	DataNotReady = "Your data is still loading. Try again shortly.",
	SetupExpired = "Queue setup expired. Walk in again to create a queue.",
	InvalidMode = "Choose Story or Endless.",
	InvalidParty = "Choose between 1 and 4 players.",
	NoQueueReservation = "Walk into an empty queue first.",
	TransferInProgress = "Preparing your private session...",
	RateLimited = "Please wait a moment.",
	RequestPending = "Please wait a moment.",
	ServerError = "Something went wrong. Please try again.",
	ConnectionError = "Could not reach the server. Please try again.",
	RequestTimeout = "The server is taking longer than usual. Please try again.",
	HostChoosing = "The party leader is choosing a mode. Please wait.",
	QueueFull = "This party is full. Try another queue.",
	PartyDeparting = "This party is departing. Try another queue.",
	FriendsOnly = "This party is for the leader's friends.",
	QueueChanged = "Your queue changed. Please try again.",
	CharacterNotReady = "Step into the entrance when your character is ready.",
	PartyChanged = "The party changed. Please try again.",
	PartyUnavailable = "This party is no longer available.",
	AlreadyInParty = "Leave your current party before joining another.",
	QueueLeft = "You left the party.",
	QueueRemoved = "This queue closed. You can join another.",
	StudioPreviewComplete = "Studio check passed. Teleport preview complete.",
	TransferFinished = "Teleport could not finish. Please rejoin a queue.",
	MembersNotReady = "A player is not ready. Please rejoin a queue.",
}

local function reveal(object)
	while object do
		if object:IsA("GuiObject") then
			object.Visible = true
		elseif object:IsA("ScreenGui") then
			object.Enabled = true
		end
		object = object.Parent
	end
end

local function write(object, content)
	if object and (object:IsA("TextLabel") or object:IsA("TextButton")) then
		object.Text = content
	elseif object and object:IsA("ImageButton") then
		local label = object:FindFirstChild("Title") or object:FindFirstChildWhichIsA("TextLabel")
		if label and label:IsA("TextLabel") then
			label.Text = content
			label.Visible = true
		end
	end
end

function View.new(gui, actions)
	local panel = gui:FindFirstChild("Party")
	local leave = gui:FindFirstChild("Leave")
	local scroll = panel and panel:FindFirstChild("ScrollingFrame")
	if not panel or not panel:IsA("GuiObject") or not leave or not leave:IsA("GuiButton") or not scroll then
		return nil, "Queue.Party, Party.ScrollingFrame, or Queue.Leave is missing"
	end
	local controls = {}
	for _, name in ipairs({ "Create", "Lower", "Raise" }) do
		controls[name] = panel:FindFirstChild(name)
		if not controls[name] or not controls[name]:IsA("GuiButton") then
			return nil, "Party." .. name .. " must be a button"
		end
	end
	local modes = {}
	for _, mode in ipairs({ "Story", "Endless" }) do
		local button = scroll:FindFirstChild(mode)
		if not button or not button:IsA("GuiButton") then
			return nil, "ScrollingFrame." .. mode .. " must be a button"
		end
		modes[mode] = {
			Button = button,
			Marker = button:FindFirstChild("Selected") or button:FindFirstChild("selected"),
			Stroke = button:FindFirstChildWhichIsA("UIStroke"),
		}
	end
	-- The screenshot has an Endless.Selected template. Reuse its authored design if Story lacks one.
	local template = modes.Story.Marker or modes.Endless.Marker
	for mode, parts in pairs(modes) do
		if not parts.Marker and template then
			parts.Marker = template:Clone()
			parts.Marker.Name = "Selected"
			parts.Marker.Parent = parts.Button
		end
		if not parts.Marker then
			warn("[DPU][Queue UI] Missing " .. mode .. ".Selected")
		end
		if not parts.Stroke then
			warn("[DPU][Queue UI] Missing " .. mode .. ".UIStroke")
		end
	end
	-- Use an authored Queue.Status if supplied. Otherwise add one small status label;
	-- never repurpose the hidden setup panel to display join/leave failures.
	local status = gui:FindFirstChild("Status")
	local ownedStatus = false
	if not status or not status:IsA("TextLabel") then
		status = Instance.new("TextLabel")
		status.Name = "DPU_Status"
		status.AnchorPoint = Vector2.new(0.5, 1)
		status.Position = UDim2.fromScale(0.5, 0.82)
		status.Size = UDim2.new(0.8, 0, 0, 48)
		status.BackgroundColor3 = Color3.fromRGB(18, 20, 18)
		status.BackgroundTransparency = 0.2
		status.BorderSizePixel = 0
		status.TextColor3 = Color3.fromRGB(230, 235, 225)
		status.TextSize = 18
		status.TextWrapped = true
		status.ZIndex = math.max(panel.ZIndex, leave.ZIndex) + 1
		local expires = panel:FindFirstChild("Expire")
		if expires and expires:IsA("TextLabel") then
			status.FontFace = expires.FontFace
		end
		status.Parent = gui
		ownedStatus = true
	end
	local self = setmetatable({
		gui = gui,
		panel = panel,
		leave = leave,
		controls = controls,
		modes = modes,
		status = status,
		ownedStatus = ownedStatus,
		connections = {},
		mode = "Story",
		capacity = 4,
		maxCapacity = 4,
		state = { Active = false },
		busy = false,
		clock = actions.clock or function()
			return workspace:GetServerTimeNow()
		end,
	}, View)
	local function connect(button, callback)
		table.insert(self.connections, button.Activated:Connect(callback))
	end
	for mode, parts in pairs(modes) do
		connect(parts.Button, function()
			if self.busy or not self.state.Configuring then
				return
			end
			self.mode = mode
			self:Render()
		end)
	end
	connect(controls.Lower, function()
		if self.busy or not self.state.Configuring then
			return
		end
		self.capacity = math.max(1, self.capacity - 1)
		self:Render()
	end)
	connect(controls.Raise, function()
		if self.busy or not self.state.Configuring then
			return
		end
		self.capacity = math.min(self.maxCapacity, self.capacity + 1)
		self:Render()
	end)
	connect(controls.Create, function()
		if not self.busy and self.state.Configuring then
			actions.create(self.capacity, self.mode)
		end
	end)
	connect(leave, function()
		if not self.busy and self.state.Active and self.state.CanLeave then
			actions.leave()
		end
	end)
	self:Render()
	return self
end

function View:IsValid()
	return self.gui.Parent ~= nil
		and self.status:IsDescendantOf(self.gui)
		and self.panel:IsDescendantOf(self.gui)
		and self.leave:IsDescendantOf(self.gui)
		and self.controls.Create:IsDescendantOf(self.panel)
		and self.modes.Story.Button:IsDescendantOf(self.panel)
		and self.controls.Lower:IsDescendantOf(self.panel)
		and self.controls.Raise:IsDescendantOf(self.panel)
		and self.modes.Endless.Button:IsDescendantOf(self.panel)
end

function View:SetState(state)
	if
		state.Active ~= self.state.Active
		or state.EntryId ~= self.state.EntryId
		or state.State ~= self.state.State
	then
		self.error = nil
	end
	if
		state.Configuring
		and (
			not self.state.Configuring
			or state.EntryId ~= self.state.EntryId
			or state.QueueId ~= self.state.QueueId
		)
	then
		self.mode = state.Mode or "Story"
		self.capacity = state.Capacity or 4
		self.maxCapacity = state.MaxCapacity or 4
		self.error = nil
	end
	self.state = state
	if state.Message then
		self.error = MESSAGES[state.Message] or "The party could not continue. Please rejoin a queue."
		self.errorUntil = self.clock() + 5
	end
	self:Render()
end

function View:SetBusy(busy)
	self.busy = busy
	self:Render()
end

function View:Error(code)
	self.error = MESSAGES[code] or "Could not complete the queue action. Please try again."
	self.errorUntil = self.clock() + 4
	self:Render()
end

function View:Render()
	local state = self.state
	self.panel.Visible = state.Active == true and state.Configuring == true
	self.leave.Visible = state.Active == true
	if state.Active then
		reveal(self.leave)
		if state.Configuring then
			reveal(self.panel)
			local background = self.panel:FindFirstChild("Background")
			if background and background:IsA("GuiObject") then
				background.Visible = true
			end
			for _, parts in pairs(self.modes) do
				reveal(parts.Button)
			end
			for _, control in pairs(self.controls) do
				reveal(control)
			end
			for _, name in ipairs({ "Limit", "Expire", "PlayerTitle", "Title" }) do
				local label = self.panel:FindFirstChild(name)
				if label then
					reveal(label)
				end
			end
		end
	end
	for mode, parts in pairs(self.modes) do
		local selected = mode == self.mode
		if parts.Marker and parts.Marker:IsA("GuiObject") then
			parts.Marker.Visible = selected
		end
		if parts.Stroke then
			parts.Stroke.Color = selected and SELECTED or UNSELECTED
		end
		parts.Button.Active = not self.busy and state.Configuring == true
	end
	self.controls.Create.Active = not self.busy and state.Configuring == true
	self.controls.Lower.Active = not self.busy and state.Configuring == true and self.capacity > 1
	self.controls.Raise.Active = not self.busy
		and state.Configuring == true
		and self.capacity < self.maxCapacity
	self.leave.Active = not self.busy and state.CanLeave == true
	write(self.controls.Create, self.busy == "QueueCreate" and "Creating..." or "Create")
	write(
		self.leave,
		self.busy == "QueueLeave" and "Leaving..."
			or state.State == "Teleporting" and "Teleporting..."
			or state.CanLeave == false and "Preparing..."
			or "Leave"
	)
	write(self.panel:FindFirstChild("Limit"), tostring(self.capacity))
	local expires = self.panel:FindFirstChild("Expire")
	if self.error and self.clock() < (self.errorUntil or 0) then
		write(expires, self.error)
	elseif state.Configuring then
		write(
			expires,
			string.format(
				"Closes in %ds",
				math.max(0, math.ceil((state.ExpiresAt or self.clock()) - self.clock()))
			)
		)
	end
	local statusText
	if self.error and self.clock() < (self.errorUntil or 0) then
		statusText = self.error
	elseif state.Active and not state.Configuring then
		if state.State == "Preparing" then
			statusText = "Saving progress and preparing your private session..."
		elseif state.State == "Teleporting" then
			statusText = "Teleporting your party..."
		else
			statusText = string.format(
				"%s  |  %d / %d players  |  Leaving in %ds",
				state.Mode or "Story",
				state.Count or 1,
				state.Capacity or self.capacity,
				math.max(0, math.ceil((state.ExpiresAt or self.clock()) - self.clock()))
			)
		end
	end
	self.status.Visible = statusText ~= nil
	if statusText then
		write(self.status, statusText)
		reveal(self.status)
	end
end

function View:Destroy()
	for _, connection in ipairs(self.connections) do
		connection:Disconnect()
	end
	self.connections = {}
	if self.ownedStatus then
		self.status:Destroy()
	end
end

return View
