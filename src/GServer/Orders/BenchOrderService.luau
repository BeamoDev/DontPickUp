local Catalog = require(script.Parent.BenchOrderCatalog)
local Station = require(script.Parent.BenchOrderStation)
local Service = {}
Service.__index = Service
local tasks = {
	Idle = "Wait for the next customer.",
	Arriving = "A customer is approaching the counter.",
	Waiting = "Click the customer to accept their phone.",
	Repairing = "Click the phone on the bench. Repair it and reassemble it.",
	Ready = "Repair complete. Click the customer to return their phone.",
	Leaving = "Order paid. The customer is leaving.",
}
function Service.new(services, deps)
	local self = setmetatable({ s = services, d = deps, revision = 0, number = 0, stage = "Idle" }, Service)
	self.station = Station.new(services, Catalog)
	deps.repairs:SetCompletionHandler(function(model)
		self:Completed(model)
	end)
	return self
end
function Service:Ready(player)
	return not self.closed and player.Parent == self.s.Players and self.d.data:IsReady(player)
end
function Service:Crew()
	local result = {}
	for _, player in ipairs(self.s.Players:GetPlayers()) do
		if self:Ready(player) then
			table.insert(result, player)
		end
	end
	return result
end
function Service:Snapshot()
	local order = self.order
	return {
		Enabled = self.station ~= nil,
		Revision = self.revision,
		Id = order and order.id or "",
		Number = self.number,
		Stage = self.stage,
		Customer = order and order.customer.Name or "",
		AppearanceId = order and order.appearanceId,
		Problem = order and order.customer.Problem or "",
		Task = tasks[self.stage],
		Reward = 10,
	}
end
function Service:Publish(stage, lines)
	self.stage, self.revision = stage, self.revision + 1
	if self.station then
		self.station:Publish(self.order and self.order.id, self.revision, stage)
	end
	self.d.changed(self:Snapshot(), lines)
end
function Service:Completed(model)
	local order = self.order
	if self.closed or self.stage ~= "Repairing" or not order or order.phone ~= model then
		return
	end
	if self.station:PhoneValid(model) and self.d.repairs:IsComplete(model, order.repairId) then
		self:Publish("Ready")
	end
end
function Service:Reset()
	if self.station then
		self.station:Clear()
	end
	self.order, self.deadline = nil, nil
	self:Publish("Idle")
end
function Service:Tick()
	if self.closed or not self.station then
		return
	end
	if not self.station:Valid() then
		self.station:Destroy()
		self.station, self.order = nil, nil
		self:Publish("Idle")
		return
	end
	if #self:Crew() == 0 then
		if self.order then
			self:Reset()
		end
		self.deadline = nil
		return
	end
	local now = os.clock()
	if self.order and not self.station:CustomerValid() then
		self:Reset()
		return
	end
	if self.order and self.order.phone and self.stage ~= "Leaving" then
		local phone = self.order.phone
		if not self.station:PhoneValid(phone) or phone:GetAttribute("DPU_RepairId") ~= self.order.repairId then
			self:Reset()
			return
		end
	end
	if self.stage == "Idle" then
		self.deadline = self.deadline or now + Catalog.FirstArrivalSeconds
		if now < self.deadline then
			return
		end
		self.number += 1
		self.order = {
			id = self.s.HttpService:GenerateGUID(false),
			customer = table.clone(Catalog.Customers[(self.number - 1) % #Catalog.Customers + 1]),
		}
		self.station:Arrive(self.order.customer.Name)
		self.order.customer.Name = self.station.actor.model:GetAttribute("DPU_CustomerName") or self.order.customer.Name
		self.order.appearanceId = self.station.actor.model:GetAttribute("DPU_AppearanceId")
		self.deadline = now + Catalog.ArrivalSeconds
		self:Publish("Arriving")
	elseif self.stage == "Arriving" and now >= self.deadline then
		self:Publish("Waiting")
	elseif self.stage == "Leaving" and now >= self.deadline then
		self:Reset()
		self.deadline = now + Catalog.BetweenOrdersSeconds
	end
end
function Service:Request(player, action, payload)
	if not self:Ready(player) then
		return { Ok = false, Code = "DataNotReady" }
	end
	if action == "GetOrderState" then
		return { Ok = true, Order = self:Snapshot() }
	end
	if action ~= "ServeCustomer" or type(payload) ~= "table" then
		return { Ok = false, Code = "InvalidRequest" }
	end
	local order = self.order
	if not self.station or not order or payload.Id ~= order.id or payload.Revision ~= self.revision then
		return { Ok = false, Code = "Changed" }
	end
	if self.stage ~= "Waiting" and self.stage ~= "Ready" then
		return { Ok = false, Code = "WrongStep" }
	end
	if self.d.busy(player) or not self.station:CanInteract(player) then
		return { Ok = false, Code = "OutOfReach" }
	end
	if self.stage == "Waiting" then
		local phone, reason = self.station:CreatePhone(order.id)
		if not phone then
			return { Ok = false, Code = reason }
		end
		-- Add is idempotent; do not depend on CollectionService signal scheduling.
		self.d.repairs:Add(phone)
		order.phone, order.repairId = phone, phone:GetAttribute("DPU_RepairId")
		self:Publish("Repairing", {
			{
				Speaker = "Customer",
				DisplayName = order.customer.Name,
				AppearanceId = order.appearanceId,
				Text = order.customer.Greeting,
				Animation = order.customer.Mood,
			},
			{ Speaker = "You", Text = "I'll check the connections. Please wait here." },
		})
	else
		if not self.station:PhoneValid(order.phone) or not self.d.repairs:IsComplete(order.phone, order.repairId) then
			return { Ok = false, Code = "NotRepaired" }
		end
		-- No yielding in settlement. The whole present, loaded crew is paid once;
		-- clients never choose a recipient, amount, device or completion result.
		local paid = false
		for _, member in ipairs(self:Crew()) do
			local ok = self.d.data:RecordOrderPayment(member, "Order_" .. order.id)
			paid = paid or ok
		end
		if not paid then
			return { Ok = false, Code = "DataNotReady" }
		end
		self.deadline = os.clock() + Catalog.DepartureSeconds
		self:Publish("Leaving", {
			{
				Speaker = "Customer",
				DisplayName = order.customer.Name,
				AppearanceId = order.appearanceId,
				Text = order.customer.Thanks,
				Animation = "HeadNodAgree",
			},
			{ Speaker = "You", Text = "All four connections are secure. Have a good evening." },
		})
		self.station:Depart()
	end
	return { Ok = true }
end
function Service:Shutdown()
	self.closed = true
	self.d.repairs:SetCompletionHandler(nil)
	if self.station then
		self.station:Destroy()
	end
	self.station, self.order = nil, nil
end
return Service
