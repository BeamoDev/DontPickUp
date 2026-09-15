-- Injected storage/clock makes lease ownership and failure paths testable without Roblox.
local SessionStore = {}
SessionStore.__index = SessionStore

function SessionStore.new(deps)
	return setmetatable({ d = deps }, SessionStore)
end

function SessionStore:Acquire(userId, token, cancelled)
	local d = self.d
	local deadline = d.clock() + d.config.LoadTimeoutSeconds
	local attempt = 0
	while not cancelled() and d.clock() < deadline do
		attempt += 1
		local reason = "Busy"
		local ok, record = pcall(d.update, userId, function(old)
			if cancelled() then
				return nil
			end
			local data = d.schema.Decode(old)
			if not data then
				reason = "InvalidData"
				return nil
			end
			local now = d.now()
			if old and old.Lease and old.Lease.Token ~= token and old.Lease.Expires > now then
				return nil
			end
			local nextRecord = old and d.schema.Copy(old) or { Format = 1, Data = data }
			nextRecord.Lease = { Token = token, Expires = now + d.config.LeaseSeconds }
			return nextRecord
		end)
		if ok and record and record.Lease and record.Lease.Token == token then
			if cancelled() then
				self:Abandon(userId, token)
				return nil, "Cancelled"
			end
			return { Data = d.schema.Copy(record.Data), Token = token, Expires = record.Lease.Expires }
		end
		if ok and reason == "InvalidData" then
			return nil, reason
		end
		d.wait(math.min(2 + attempt * 0.3, 5))
	end
	-- An UpdateAsync may have committed before throwing. Release only our own token.
	self:Abandon(userId, token)
	return nil, cancelled() and "Cancelled" or "LoadTimeout"
end

function SessionStore:Abandon(userId, token)
	for attempt = 1, 3 do
		local ok = pcall(self.d.update, userId, function(old)
			if type(old) ~= "table" or not old.Lease or old.Lease.Token ~= token then
				return nil
			end
			local copy = self.d.schema.Copy(old)
			copy.Lease = nil -- Preserve the stored payload, never save a cancelled load's defaults.
			return copy
		end)
		if ok then
			return true
		end
		self.d.wait(attempt)
	end
	return false -- The lease still expires if the storage service remains unavailable.
end

function SessionStore:Write(userId, session, data, release, operationId, deadline)
	local d = self.d
	if not d.schema.Validate(data) then
		return false, "InvalidData"
	end
	local snapshot = d.schema.Copy(data)
	for attempt = 1, 4 do
		if d.clock() >= deadline then
			break
		end
		local lost = false
		local ok, record = pcall(d.update, userId, function(old)
			-- Retry a lost response without reapplying a release or stealing the next owner's lease.
			if type(old) == "table" and old.LastOperation == operationId then
				return old
			end
			if
				not d.schema.Decode(old)
				or not old
				or not old.Lease
				or old.Lease.Token ~= session.Token
				or old.Lease.Expires <= d.now()
			then
				lost = true
				return nil
			end
			local nextRecord = d.schema.Copy(old)
			nextRecord.Data = d.schema.Copy(snapshot)
			nextRecord.LastOperation = operationId
			nextRecord.Lease = if release
				then nil
				else { Token = session.Token, Expires = d.now() + d.config.LeaseSeconds }
			return nextRecord
		end)
		if ok and record and record.LastOperation == operationId then
			if not release and record.Lease and record.Lease.Token == session.Token then
				session.Expires = record.Lease.Expires
			end
			return true
		end
		if ok and lost then
			return false, "OwnershipLost"
		end
		d.wait(math.min(attempt * 1.5, math.max(0, deadline - d.clock())))
	end
	return false, "SaveUnavailable"
end

return SessionStore
