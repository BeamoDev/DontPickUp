local Shared = game:GetService("ReplicatedStorage"):WaitForChild("GShared", 30)
local Tags = require(Shared:WaitForChild("Interactions", 30):WaitForChild("InteractionTags", 30))
local Bindings = require(script.Parent.TagBindings)
local Containers = require(script.Parent.Parent.Containers.ContainerService)
local Drinks = require(script.Parent.DrinkService)
local Throws = require(script.Parent.ThrowService)
local Service = {}
Service.__index = Service

function Service.new(services, eligible)
	local self = setmetatable({}, Service)
	self.containers = Containers.new(services, eligible)
	self.drinks = Drinks.new(services, eligible, function(character, head, part, item)
		return self.containers:Visible(character, head, part, item)
	end)
	self.throws = Throws.new(services, eligible, function(character, head, part, item)
		return self.containers:Visible(character, head, part, item)
	end)
	self.bindings = Bindings.new(services.CollectionService, services.Workspace, Tags, function(item, old, new)
		if old == "Container" then
			self.containers:Unbind(item)
		elseif old == "Drink" then
			self.drinks:Drop(item)
		elseif old == "throw" then
			self.throws:Drop(item)
		end
		if new == "Container" then
			self.containers:Bind(item)
		elseif new == "Drink" then
			self.drinks:Add(item)
		elseif new == "throw" then
			self.throws:Add(item)
		end
	end)
	return self
end

function Service:Request(player, action, payload)
	if action == "GrabThrow" or action == "ReleaseThrow" or action == "CancelThrow" then
		return self.throws:Request(player, action, payload)
	end
	if self.throws.holds[player] then
		return { Ok = false, Code = "AlreadyHolding" }
	end
	if action == "ToggleContainer" then
		return self.containers:Request(player, payload)
	end
	if action == "Drink" then
		return self.drinks:Request(player, payload)
	end
	return { Ok = false, Code = "UnknownAction" }
end
function Service:Remove(player)
	self.containers:Remove(player)
	self.drinks:Remove(player)
	self.throws:Remove(player)
end
function Service:Shutdown()
	self.bindings:Destroy()
	self.containers:Shutdown()
	self.drinks:Shutdown()
	self.throws:Shutdown()
end
return Service
