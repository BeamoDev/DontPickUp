local Shared = game:GetService("ReplicatedStorage"):WaitForChild("GShared", 30)
local Tags = require(Shared:WaitForChild("Interaction", 30):WaitForChild("InteractionTags", 30))
local Bindings = require(script.Parent.TagBindings)
local Containers = require(script.Parent.ContainerService)
local Drinks = require(script.Parent.DrinkService)
local Throws = require(script.Parent.ThrowService)
local Repairs = require(script.Parent.Parent.Repair.PhoneRepairService)
local Service = {}
Service.__index = Service

function Service.new(services, eligible)
	local self = setmetatable({}, Service)
	self.containers = Containers.new(services, eligible)
	self.repairs = Repairs.new(services, eligible)
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
		elseif old == "PhoneRepair" then
			self.repairs:Drop(item)
		elseif old == "throw" then
			self.throws:Drop(item)
		end
		if new == "Container" then
			self.containers:Bind(item)
		elseif new == "Drink" then
			self.drinks:Add(item)
		elseif new == "PhoneRepair" then
			self.repairs:Add(item)
		elseif new == "throw" then
			self.throws:Add(item)
		end
	end)
	return self
end

function Service:Request(player, action, payload)
	if
		action == "BeginRepair"
		or action == "CancelRepair"
		or action == "RepairGrab"
		or action == "RepairDrop"
		or action == "RepairRelease"
	then
		if self.throws.holds[player] then
			return { Ok = false, Code = "AlreadyHolding" }
		end
		return self.repairs:Request(player, action, payload)
	end
	if self.repairs.sessions[player] then
		return { Ok = false, Code = "RepairInProgress" }
	end
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
	self.repairs:Remove(player)
end
function Service:Shutdown()
	self.bindings:Destroy()
	self.containers:Shutdown()
	self.drinks:Shutdown()
	self.throws:Shutdown()
	self.repairs:Shutdown()
end
return Service
