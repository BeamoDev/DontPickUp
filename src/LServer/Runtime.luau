-- Server modules can require this sibling and call Runtime.Get() after startup.
local Runtime = { services = nil }
function Runtime.Set(services)
	assert(not Runtime.services, "DontPickUp runtime already started")
	Runtime.services = services
end
function Runtime.Get()
	return Runtime.services
end
return Runtime
