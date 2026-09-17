-- Reuses authoritative drawer movement within the prototype's single input stack.
local Policy = require(script.Parent.Parent.Story.GovernmentService)
local Storage = {}
Storage.__index = Storage
function Storage.new(services, world)
	local model = world:FindFirstChild("Storage")
	if not model then
		return nil
	end -- Older authored shop layout.
	assert(model:IsA("Model"), "[DPU] DPU_Prototype.Storage must be a Model")
	local Containers = require(script.Parent.Parent.Interaction.ContainerService)
	local self = setmetatable({ model = model, boxes = {}, saved = {} }, Storage)
	self.containers = Containers.new(services, function(player)
		return self:Allowed(player, self.run)
	end)
	self.containers:Bind(model)
	for box in pairs(self.containers.boxes) do
		local station = "Storage_" .. box.Name
		self.boxes[station] = box
		local label = model:FindFirstChild("Label" .. box.Name:match("^Box(%d*)$"))
		for _, part in ipairs(label and { box, label } or { box }) do
			if part:IsA("BasePart") then
				local saved = {}
				for _, key in ipairs({ "DPU_Direct", "DPU_Enabled", "DPU_Range", "DPU_Label" }) do
					saved[key] = { part:GetAttribute(key) }
				end
				self.saved[part] = saved
				part:SetAttribute("DPU_Direct", station)
				part:SetAttribute("DPU_Range", 8)
				part:SetAttribute("DPU_Enabled", false)
				part:SetAttribute("DPU_Label", "Open / close drawer")
			end
		end
	end
	return self
end
function Storage:Allowed(player, run)
	local member = run and run.players[player]
	return run ~= nil
		and not run.closing
		and member ~= nil
		and member.Alive
		and member.ClockedIn
		and member.Acknowledged
		and run.d.ready(player)
		and run.d.present(player)
		and not member.Focus
		and not member.Inspection
		and not member.Fax
		and not member.CarriedPart
		and (run.phase == "Tutorial" or run.phase == "Night" or run.phase == "Closing")
		and not Policy.BlocksWork(run)
end
function Storage:Update(run)
	self.run = run
	local enabled = (run.phase == "Tutorial" or run.phase == "Night" or run.phase == "Closing")
		and not Policy.BlocksWork(run)
	if self.enabled == enabled then
		return
	end
	self.enabled = enabled
	for part in pairs(self.saved) do
		part:SetAttribute("DPU_Enabled", enabled)
	end
end
function Storage:Request(player, payload, run)
	self.run = run
	local box = self.boxes[payload.Station]
	if not box or box.Parent ~= self.model or payload.Id ~= box:GetAttribute("DPU_ContainerId") then
		return { Ok = false, Code = "Unavailable" }
	end
	return self.containers:Request(player, { Id = payload.Id, Revision = payload.Revision })
end
function Storage:Remove(player)
	self.containers:Remove(player)
end
function Storage:Destroy()
	self.containers:Shutdown()
	for part, saved in pairs(self.saved) do
		for key, value in pairs(saved) do
			part:SetAttribute(key, value[1])
		end
	end
end
return Storage
