local Shared = game:GetService("ReplicatedStorage"):WaitForChild("GShared", 30)
local Query = require(Shared:WaitForChild("Interaction", 30):WaitForChild("InteractionQuery", 30))
local Tags = require(Shared:WaitForChild("Interaction", 30):WaitForChild("InteractionTags", 30))
local Rig = require(Shared:WaitForChild("Repair", 30):WaitForChild("RepairRig", 30))
local Bench = require(script.Parent.BenchOrderTestBench)
local Actor = require(script.Parent.Parent.Customers.CustomerActor)
local Station = {}
Station.__index = Station
function Station.new(services, config)
	local model = services.Workspace:FindFirstChild("RepairOrderStation")
	local generated = false
	if not model and config.StudioBench and services.RunService:IsStudio() then
		model, generated = Bench.Create(services.Workspace), true
	end
	if not model then
		return nil
	end
	local points = {}
	for _, name in ipairs({ "CustomerStart", "CustomerStand", "PhoneSpot" }) do
		local point = model:FindFirstChild(name)
		if not point or not point:IsA("BasePart") then
			warn("[DPU][Orders] RepairOrderStation needs a BasePart named " .. name)
			if generated then
				model:Destroy()
			end
			return nil
		end
		points[name] = point
	end
	points.CustomerExit = model:FindFirstChild("CustomerExit") or points.CustomerStart
	if not points.CustomerExit:IsA("BasePart") then
		return nil
	end
	Actor.PrepareTemplates(services.ReplicatedStorage)
	local owned = Instance.new("Folder")
	owned.Name, owned.Parent = "DPU_ActiveOrder", services.Workspace
	return setmetatable(
		{ s = services, config = config, model = model, points = points, owned = owned, generated = generated },
		Station
	)
end
function Station:Valid()
	if not self.model:IsDescendantOf(self.s.Workspace) or not self.owned:IsDescendantOf(self.s.Workspace) then
		return false
	end
	for _, point in pairs(self.points) do
		if not point:IsDescendantOf(self.model) then
			return false
		end
	end
	return true
end
function Station:Arrive(customerName)
	self:Clear()
	self.invalidCustomer = false
	local config = table.clone(self.config)
	config.CustomerName = customerName
	self.actor = Actor.new(self.s, self.owned, self.points.CustomerStart.CFrame, config)
	self.actor:MoveTo(self.points.CustomerStand.CFrame, self.config.ArrivalSeconds)
	self.s.CollectionService:AddTag(self.actor.model, "Customer")
	self.ancestry = self.actor.model.AncestryChanged:Connect(function()
		if not self.actor.model:IsDescendantOf(self.owned) then
			self.invalidCustomer = true
		end
	end)
	self.tagRemoved = self.s.CollectionService:GetInstanceRemovedSignal("Customer"):Connect(function(model)
		if model == self.actor.model then
			self.invalidCustomer = true
		end
	end)
end
function Station:CustomerValid()
	return not self.invalidCustomer
		and self.actor ~= nil
		and self.actor.model:IsDescendantOf(self.owned)
		and self.actor.target:IsDescendantOf(self.actor.model)
		and self.s.CollectionService:HasTag(self.actor.model, "Customer")
end
function Station:Publish(id, revision, stage)
	if self.actor then
		self.actor.model:SetAttribute("DPU_OrderId", id)
		self.actor.model:SetAttribute("DPU_OrderRevision", revision)
		self.actor.model:SetAttribute("DPU_OrderStage", stage)
	end
end
function Station:CanInteract(player)
	local actor, character = self.actor, player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local head = character and character:FindFirstChild("Head")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if
		not self:Valid()
		or not self:CustomerValid()
		or not root
		or not head
		or not humanoid
		or humanoid.Health <= 0
		or humanoid.Sit
	then
		return false
	end
	return Query.Distance(actor.target, root.Position) <= Tags.Distance
		and Query.Visible(self.s.Workspace, self.s.CollectionService, character, head, actor.target, actor.model)
end
function Station:CreatePhone(id)
	local assets = self.s.ServerStorage:FindFirstChild("Assets")
	local template = assets and assets:FindFirstChild("OrderPhone")
	if template and not template:IsA("Model") then
		return nil, "InvalidPhoneTemplate"
	end
	local phone
	if template then
		local archivable = template.Archivable
		template.Archivable = true
		phone = template:Clone()
		template.Archivable = archivable
	end
	if not phone and self.generated then
		phone = Bench.Phone()
	end
	if not phone then
		return nil, "MissingPhoneTemplate"
	end
	local rig, reason = Rig.Read(phone)
	if not rig then
		phone:Destroy()
		return nil, reason
	end
	for _, item in ipairs(phone:GetDescendants()) do
		if item:IsA("LuaSourceContainer") then
			item:Destroy()
		end
		for _, tag in ipairs(self.s.CollectionService:GetTags(item)) do
			self.s.CollectionService:RemoveTag(item, tag)
		end
	end
	for _, tag in ipairs(self.s.CollectionService:GetTags(phone)) do
		self.s.CollectionService:RemoveTag(phone, tag)
	end
	for _, part in ipairs(rig.parts) do
		part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery = true, false, false, true
	end
	-- Test phone starts front-up; authored templates keep their authored rotation.
	local rotation = not template and CFrame.Angles(math.pi / 2, 0, 0) or phone:GetPivot().Rotation
	phone:PivotTo(CFrame.new(self.points.PhoneSpot.Position) * self.points.PhoneSpot.CFrame.Rotation * rotation)
	local bounds, size = phone:GetBoundingBox()
	phone:PivotTo(
		phone:GetPivot() + Vector3.yAxis * (self.points.PhoneSpot.Position.Y - bounds.Position.Y + size.Y / 2)
	)
	phone.Name = "OrderPhone"
	phone:SetAttribute("DPU_OrderId", id)
	phone.Parent, self.phone = self.owned, phone
	self.s.CollectionService:AddTag(phone, "PhoneRepair")
	return phone
end
function Station:PhoneValid(phone)
	return phone == self.phone
		and phone:IsDescendantOf(self.owned)
		and self.s.CollectionService:HasTag(phone, "PhoneRepair")
end
function Station:Depart()
	if self.phone then
		self.s.CollectionService:RemoveTag(self.phone, "PhoneRepair")
		self.phone:Destroy()
		self.phone = nil
	end
	if self.actor then
		self.actor:MoveTo(self.points.CustomerExit.CFrame, self.config.DepartureSeconds)
	end
end
function Station:Clear()
	if self.ancestry then
		self.ancestry:Disconnect()
		self.ancestry = nil
	end
	if self.tagRemoved then
		self.tagRemoved:Disconnect()
		self.tagRemoved = nil
	end
	if self.phone then
		self.s.CollectionService:RemoveTag(self.phone, "PhoneRepair")
		self.phone:Destroy()
		self.phone = nil
	end
	if self.actor then
		self.s.CollectionService:RemoveTag(self.actor.model, "Customer")
		self.actor:Destroy()
		self.actor = nil
	end
end
function Station:Destroy()
	self:Clear()
	self.owned:Destroy()
	if self.generated then
		self.model:Destroy()
	end
end
return Station
