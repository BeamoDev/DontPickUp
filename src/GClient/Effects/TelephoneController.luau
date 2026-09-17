-- Physical telephone adapter for the server-owned six-digit customer pickup flow.
local Telephone = require(script.Parent.PhysicalTelephoneController)
local Config = require(script.Parent.TelephoneConfig)
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("GShared", 30)
local Scene = require(Shared:WaitForChild("World", 30):WaitForChild("SceneReferences", 30))
local Pickup = {}
Pickup.__index = Pickup
local errors = {
	InvalidTicket = "ENTER SIX DIGITS",
	TicketNotFound = "TICKET NOT FOUND",
	PhoneNotReady = "REPAIR PHONE FIRST",
	FaxClosed = "CALL ENDED",
	MoveCloser = "MOVE CLOSER",
	ConnectionError = "CONNECTION DELAY",
	RequestPending = "PLEASE WAIT",
	RateLimited = "PLEASE WAIT",
}
function Pickup.new(deps)
	local self = setmetatable({ d = deps }, Pickup)
	local config = table.clone(Config)
	config.MaxDigits = 6
	local phoneDeps = table.clone(deps)
	phoneDeps.config = config
	phoneDeps.modalOpen = function()
		return self.blocked == true
	end
	phoneDeps.isTelephone = function(model)
		return model ~= nil and model == Scene.Telephone(deps.workspace)
	end
	phoneDeps.active = function(active)
		if not active then
			self:Dismiss()
		end
		if deps.cursor then
			deps.cursor(false)
		end
	end
	phoneDeps.returning = function(returning)
		if deps.cursor then
			deps.cursor(returning)
		end
	end
	phoneDeps.dial = function(number)
		self:Dial(number)
	end
	phoneDeps.emptyText = function()
		local ready = {}
		for _, ticket in ipairs(self.item and self.item.Tickets or {}) do
			if ticket.Step == "ReadyForPickup" then
				table.insert(ready, ticket.Ticket)
			end
		end
		return #ready > 0 and ("READY: " .. table.concat(ready, " / ") .. "\nENTER SIX DIGITS")
			or "ENTER SIX-DIGIT TICKET"
	end
	phoneDeps.acceptKey = function(value)
		return value == "End" or not (self.busy or self.pendingTicket)
	end
	phoneDeps.hangup = function()
		self.pendingTicket = nil
	end
	self.phone = Telephone.new(phoneDeps)
	return self
end
function Pickup:OwnsInput()
	return self.phone.saved ~= nil
end
function Pickup:NeedsPointer()
	return self.phone.saved ~= nil and not self.phone.camera.exiting
end
function Pickup:Dismiss()
	local item = self.item
	self.pendingTicket = nil
	if item and self.dismissed ~= item.Id then
		self.dismissed = item.Id
		self.d.send("CloseFax", { FaxId = item.Id })
	end
end
function Pickup:Dial(number)
	if self.busy or self.pendingTicket or not self.item or not self.phone:Ready() then
		return
	end
	if not number:match("^%d%d%d%d%d%d$") then
		self:Error("InvalidTicket")
		return
	end
	self.pendingTicket = number
	self.phone.status = "CALLING " .. number
	self.phone:Write()
	self.d.send("DialTicket", { FaxId = self.item.Id, Ticket = number })
end
function Pickup:Error(code)
	self.pendingTicket = nil
	if self:OwnsInput() then
		self.phone.status = errors[code] or "CALL FAILED"
		self.phone:Write()
	end
end
function Pickup:Update(state, blocked, busy)
	self.blocked, self.busy = blocked == true, busy == true
	local item = state.Fax
	if
		not item
		or item.Id == self.dismissed
		or not state.Alive
		or (state.WorkBlocked == true or state.WorkBlocked == nil and state.Event ~= nil)
		or state.Phase == "Results"
		or self.d.clock() >= item.EndsAt
		or blocked
	then
		self.phone:Close(not state.Alive)
		return
	end
	if not self.item or self.item.Id ~= item.Id then
		self.item, self.pendingTicket, self.callSerial = item, nil, item.CallSerial or 0
	end
	self.item = item
	if not self:OwnsInput() then
		local model = Scene.Telephone(self.d.workspace)
		if not model then
			self:Dismiss()
			return
		end
		self.phone:Open(model)
		if self:OwnsInput() then
			self.phone:Write()
		end
	end
	if (item.CallSerial or 0) ~= self.callSerial then
		self.callSerial = item.CallSerial
		if self.pendingTicket == item.CalledTicket then
			self.phone:ConnectPickup(item.CalledTicket, item.Message)
		end
		self.pendingTicket = nil
	end
end
function Pickup:Step()
	self.phone:Update()
end
function Pickup:InputBegan(input, processed)
	self.phone:InputBegan(input, processed)
end
function Pickup:InputChanged(input)
	self.phone:InputChanged(input)
end
function Pickup:InputEnded(input, processed)
	self.phone:InputEnded(input, processed)
end
function Pickup:Destroy()
	self.phone:Destroy()
end
return Pickup
