local View = require(script.Parent.OrderView)
local Controller = {}
Controller.__index = Controller
function Controller.new(deps)
	local self = setmetatable({ d = deps, revision = -1, view = View.new(deps.playerGui) }, Controller)
	-- Subscribe before fetching, and reject old responses after newer broadcasts.
	self.connection = deps.changed.OnClientEvent:Connect(function(state, lines)
		self:Apply(state, lines)
	end)
	task.spawn(function()
		local ok, result = pcall(deps.remote.InvokeServer, deps.remote, "GetOrderState", {})
		if ok and type(result) == "table" and result.Ok then
			self:Apply(result.Order)
		end
	end)
	return self
end
function Controller:Apply(state, lines)
	if
		self.destroyed
		or type(state) ~= "table"
		or type(state.Revision) ~= "number"
		or state.Revision <= self.revision
	then
		return
	end
	self.revision = state.Revision
	self.view:Render(state)
	if lines then
		self.d.dialogue:Play(lines)
	end
end
function Controller:Response(response)
	if self.destroyed or type(response) ~= "table" or response.Ok then
		return
	end
	local messages = {
		Changed = "The order changed. Check the current task.",
		OutOfReach = "Move closer to the customer with empty hands.",
		NotRepaired = "Finish repairing this customer's phone first.",
		DataNotReady = "Your profile is still loading. Try again shortly.",
		MissingPhoneTemplate = "OrderPhone template is missing. Check Studio Output.",
	}
	self.view:Notice(messages[response.Code] or "Could not handle this order. Please try again.")
end
function Controller:Destroy()
	self.destroyed = true
	self.connection:Disconnect()
	self.view:Destroy()
end
return Controller
