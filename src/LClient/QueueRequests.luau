-- Request ownership is separate from authoritative queue state. Timeouts never mean "left".
local Requests = {}
Requests.__index = Requests

function Requests.new(deps)
	return setmetatable({ d = deps, pending = nil, flights = 0, destroyed = false }, Requests)
end

function Requests:Send(action, payload)
	if self.destroyed or self.pending then
		return false
	end
	if self.flights >= 2 then
		self.d.error("ConnectionError")
		return false
	end
	local operation = { Action = action, Started = self.d.clock(), EntryId = payload and payload.EntryId }
	self.pending = operation
	self.flights += 1
	self.d.busy(action)
	self.d.spawn(function()
		local ok, response = pcall(self.d.invoke, action, payload)
		self.flights -= 1
		if self.destroyed then
			return
		end
		-- Even a late reply may carry newer server state. The controller checks its revision.
		if ok and type(response) == "table" then
			self.d.apply(response.Queue)
		end
		if self.pending ~= operation then
			return
		end
		self.pending = nil
		self.d.busy(nil)
		if not ok or type(response) ~= "table" then
			self.d.error("ConnectionError")
		elseif not response.Ok then
			self.d.error(response.Code)
		end
	end)
	return true
end

function Requests:Observe(snapshot)
	local pending = self.pending
	if
		pending
		and pending.EntryId
		and (
			pending.EntryId ~= snapshot.EntryId
			or (pending.Action == "QueueCreate" and not snapshot.Configuring)
		)
	then
		self.pending = nil
		self.d.busy(nil)
	end
end

function Requests:Tick()
	if self.pending and self.d.clock() - self.pending.Started >= 8 then
		self.pending = nil
		self.d.busy(nil)
		self.d.error("RequestTimeout")
	end
end

function Requests:Destroy()
	self.destroyed = true
	self.pending = nil
end

return Requests
