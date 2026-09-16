local Fixture = {}
function Fixture.Signal()
	local listeners = {}
	return {
		Connect = function(_, fn)
			local connection = { Connected = true }
			function connection:Disconnect()
				self.Connected = false
			end
			table.insert(listeners, { connection, fn })
			return connection
		end,
		Fire = function(_, ...)
			for _, listener in ipairs(listeners) do
				if listener[1].Connected then
					listener[2](...)
				end
			end
		end,
	}
end
function Fixture.Collection()
	local tags, added, removed = {}, {}, {}
	local service = {}
	function service:HasTag(item, tag)
		return tags[tag] and tags[tag][item] == true or false
	end
	function service:GetTagged(tag)
		local result = {}
		for item in pairs(tags[tag] or {}) do
			table.insert(result, item)
		end
		return result
	end
	function service:GetInstanceAddedSignal(tag)
		added[tag] = added[tag] or Fixture.Signal()
		return added[tag]
	end
	function service:GetInstanceRemovedSignal(tag)
		removed[tag] = removed[tag] or Fixture.Signal()
		return removed[tag]
	end
	function service:AddTag(item, tag)
		if self:HasTag(item, tag) then
			return
		end
		tags[tag] = tags[tag] or {}
		tags[tag][item] = true
		self:GetInstanceAddedSignal(tag):Fire(item)
	end
	function service:RemoveTag(item, tag)
		if not self:HasTag(item, tag) then
			return
		end
		tags[tag][item] = nil
		self:GetInstanceRemovedSignal(tag):Fire(item)
	end
	return service
end
return Fixture
