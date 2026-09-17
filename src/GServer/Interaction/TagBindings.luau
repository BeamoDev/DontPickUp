-- Tags may be applied before parenting, removed at runtime, or moved out of Workspace.
local Bindings = {}
Bindings.__index = Bindings

function Bindings.new(collection, world, tags, changed)
	local self = setmetatable({
		collection = collection,
		world = world,
		tags = tags,
		changed = changed,
		items = {},
		dead = setmetatable({}, { __mode = "k" }),
		connections = {},
	}, Bindings)
	for _, tag in ipairs(tags.Names) do
		table.insert(
			self.connections,
			collection:GetInstanceAddedSignal(tag):Connect(function(item)
				self:Refresh(item)
			end)
		)
		table.insert(
			self.connections,
			collection:GetInstanceRemovedSignal(tag):Connect(function(item)
				self:Refresh(item)
			end)
		)
		for _, item in ipairs(collection:GetTagged(tag)) do
			self:Refresh(item)
		end
	end
	return self
end

function Bindings:Refresh(item)
	if self.closed or self.dead[item] then
		return
	end
	local kind = self.tags.Kind(self.collection, item)
	local record = self.items[item]
	if kind and not record then
		record = {}
		self.items[item] = record
		record.ancestry = item.AncestryChanged:Connect(function()
			self:Refresh(item)
		end)
		record.destroying = item.Destroying:Connect(function()
			self.dead[item] = true
			self:Forget(item)
		end)
	end
	if not record then
		return
	end
	local active = item:IsDescendantOf(self.world) and kind or nil
	if record.kind ~= active then
		local old = record.kind
		record.kind = active
		self.changed(item, old, active)
	end
	if not kind then
		self:Forget(item)
	end
end

function Bindings:Forget(item)
	local record = self.items[item]
	if not record then
		return
	end
	self.items[item] = nil
	record.ancestry:Disconnect()
	record.destroying:Disconnect()
	if record.kind then
		self.changed(item, record.kind, nil)
	end
end

function Bindings:Destroy()
	self.closed = true
	for _, connection in ipairs(self.connections) do
		connection:Disconnect()
	end
	for item in pairs(self.items) do
		self:Forget(item)
	end
end

return Bindings
