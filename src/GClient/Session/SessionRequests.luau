-- One in-flight call. Deferred exit intents retain the visit/run they were created for.
local Requests = {}
Requests.__index = Requests
function Requests.new(deps)
	return setmetatable({ d = deps }, Requests)
end
function Requests.Payload(state, action, choice)
	if action == "GetPrototype" or action == "ReturnLobby" then
		return action, nil
	end
	local payload = { RunId = state.RunId, Action = action }
	if action == "Interact" then
		payload.Station = choice.Station
		payload.OrderId, payload.EventId = state.Order and state.Order.Id, state.Event and state.Event.Id
		if choice.Station == "Counter" then
			payload.OrderId = state.CounterOrderId
		end
	elseif action == "ToggleStorage" then
		payload.Station, payload.Id, payload.Revision = choice.Station, choice.Id, choice.Revision
	elseif action == "Vote" then
		payload.OrderId, payload.Choice = state.Vote and state.Vote.OrderId, choice
	elseif action == "Signal" then
		payload.Signal = choice
	elseif state.Event and table.find({ "RestorePower", "Silence", "Answer", "Records" }, action) then
		payload.EventId = state.Event.Id
	else
		payload.OrderId = state.Order and state.Order.Id
		if action == "Collect" then
			payload.Part = state.Order and state.Order.Fault
		end
		if action == "PickupTool" then
			payload.Tool = state.RequiredTool
		end
	end
	if type(choice) == "table" and action ~= "Interact" then
		for _, key in ipairs({
			"FocusId",
			"WorkId",
			"OrderId",
			"Move",
			"PuzzleRevision",
			"InspectionId",
			"Station",
			"FaxId",
			"Ticket",
		}) do
			if choice[key] ~= nil then
				payload[key] = choice[key]
			end
		end
		-- Restocking deliberately has no order; never inherit a nearby customer's ID.
		if action == "PuzzleInput" then
			payload.OrderId = choice.OrderId
		end
	end
	return "PrototypeAction", payload
end
function Requests:Send(action, choice)
	if self.stopped then
		return
	end
	local state = self.d.state()
	local name, payload = Requests.Payload(state, action, choice)
	if self.pending then
		if action == "CloseFax" or action == "CloseInspection" or action == "CloseFocus" or action == "Stand" then
			self.deferred = { Name = name, Payload = payload, RunId = state.RunId }
		end
		return
	end
	self:_invoke(name, payload, state.RunId)
end
function Requests:_invoke(name, payload, runId)
	local remote = self.d.remote()
	if not remote then
		self.d.error("DataNotReady")
		return
	end
	local operation = { Started = self.d.clock(), RunId = runId }
	self.pending = operation
	self.d.busy(true)
	self.d.spawn(function()
		local ok, response = pcall(function()
			return remote:InvokeServer(name, payload)
		end)
		if self.stopped or self.pending ~= operation then
			return
		end
		if ok and type(response) == "table" then
			self.d.apply(response.State)
		end
		self.pending = nil
		self.d.busy(false)
		if not operation.RunId or operation.RunId == self.d.state().RunId then
			if not ok or type(response) ~= "table" then
				self.d.error("ConnectionError")
			elseif not response.Ok then
				self.d.error(response.Code)
			end
		end
		local deferred = self.deferred
		self.deferred = nil
		if deferred and deferred.RunId == self.d.state().RunId then
			self:_invoke(deferred.Name, deferred.Payload, deferred.RunId)
		end
	end)
end
function Requests:Tick()
	if self.pending and self.d.clock() - self.pending.Started >= 12 then
		self.pending.Started = self.d.clock()
		self.d.error("ConnectionError")
	end
end
function Requests:Destroy()
	self.stopped, self.deferred = true, nil
end
return Requests
