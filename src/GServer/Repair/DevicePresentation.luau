-- Server-owned copies of authored device art. No fixed shop or UI construction.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("GShared", 30)
local Scene = require(Shared:WaitForChild("World", 30):WaitForChild("SceneReferences", 30))
local Placement = require(script.Parent.DevicePlacement)
local Devices = {}
Devices.__index = Devices
local function clean(model)
	local items = model:GetDescendants()
	table.insert(items, model)
	for _, item in ipairs(items) do
		item:SetAttribute("DPU_Direct", nil)
		item:SetAttribute("DPU_Enabled", nil)
		if
			item:IsA("LuaSourceContainer")
			or item:IsA("JointInstance")
			or item:IsA("Constraint")
			or item:IsA("ProximityPrompt")
			or item:IsA("ClickDetector")
		then
			item:Destroy()
		elseif item:IsA("BasePart") then
			item.Anchored, item.CanCollide, item.CanTouch, item.CanQuery = true, false, false, true
		end
	end
end
local function clone(source)
	local archivable = source.Archivable
	source.Archivable = true
	local ok, copy = pcall(source.Clone, source)
	source.Archivable = archivable
	assert(ok and copy, "[DPU] Could not clone authored Phone")
	clean(copy)
	return copy
end
function Devices.new(services, folder, template)
	return setmetatable(
		{ services = services, folder = folder, template = template, copies = {}, anchors = {}, views = {} },
		Devices
	)
end
function Devices:Create(name, repair)
	local model = clone(self.template)
	local ok, result = pcall(self.Build, self, model, name, repair)
	if not ok then
		model:Destroy()
		error(result, 0)
	end
	return result
end
function Devices:Build(model, name, repair)
	model.Name = name
	local body, cover, screen =
		model:FindFirstChild("Phone"), model:FindFirstChild("BackCover"), model:FindFirstChild("Screen")
	assert(
		body and cover and screen and model:FindFirstChild("Battery") and model:FindFirstChild("Screws"),
		"[DPU] Assets.Devices.Phone needs Phone, Screen, Battery, BackCover and Screws"
	)
	-- Imported mesh axes vary: the thin body axis gives the face normal.
	for index = 1, 4 do
		local screw = model.Screws:FindFirstChild("Screw" .. index)
		assert(screw and screw:IsA("BasePart"), "[DPU] Assets.Devices.Phone.Screws needs Screw" .. index)
	end
	local destination, anchor = Placement.Resolve(self.folder, name, body)
	local size, frame = body.Size, body.CFrame
	local front = size.X <= size.Y and size.X <= size.Z and frame.RightVector
		or size.Y <= size.Z and frame.UpVector
		or frame.LookVector
	if front:Dot(screen.CFrame.Position - cover.CFrame.Position) < 0 then
		front = -front
	end
	local up = size.Y >= size.X and size.Y >= size.Z and frame.UpVector
		or size.X >= size.Z and frame.RightVector
		or -frame.LookVector
	local source = CFrame.lookAt(body.CFrame.Position, body.CFrame.Position + front, up)
	local heading = Vector3.new(destination.LookVector.X, 0, destination.LookVector.Z)
	heading = heading.Magnitude > 0.01 and heading.Unit or -Vector3.zAxis
	local plane = CFrame.lookAt(destination.Position, destination.Position + heading)
	local target = CFrame.lookAt(
		destination.Position,
		destination.Position + (repair and -Vector3.yAxis or Vector3.yAxis),
		-heading
	)
	model:PivotTo(target * source:Inverse() * model:GetPivot())
	model:SetAttribute("DPU_DeviceId", "Phone")
	model:SetAttribute("DPU_DevicePlane", plane)
	-- Speaker/keypad replacement shapes come from the same authored stock pickups.
	for _, fault in ipairs({ "Speaker", "Keypad" }) do
		if not model:FindFirstChild(fault, true) then
			local stock = Scene.Station(self.folder, "Part_" .. fault)
			assert(stock and stock:IsA("BasePart"), "[DPU] Missing Storage pickup for " .. fault)
			local part = clone(stock)
			part.Name = fault
			for _, item in ipairs(part:GetDescendants()) do
				if item:IsA("SurfaceGui") or item:IsA("BillboardGui") then
					item:Destroy()
				end
			end
			part.Anchored, part.CanCollide, part.CanTouch = true, false, false
			local mount = model:FindFirstChild(fault .. "Mount", true)
			part.CFrame = mount and mount:IsA("Attachment") and mount.WorldCFrame
				or plane
					* CFrame.new(fault == "Speaker" and 0.35 or -0.35, 0.06, fault == "Speaker" and -0.5 or 0.45)
			part.Size =
				Vector3.new(math.min(part.Size.X, 0.55), math.min(part.Size.Y, 0.15), math.min(part.Size.Z, 0.6))
			part.Transparency, part.Parent = 0, model
		end
	end
	local view = { model = model, homes = {}, loose = {}, tweens = {}, key = nil, plane = plane }
	local _, bounds = model:GetBoundingBox()
	local width = math.max(bounds.X, bounds.Z, 1)
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			view.homes[part] = part.CFrame
			part:SetAttribute("DPU_DeviceHome", part.CFrame)
			local name = part.Name
			if
				name == "BackCover"
				or name == "Battery"
				or name == "Speaker"
				or name == "Keypad"
				or name:match("^Screw%d$")
			then
				local offset = name == "BackCover" and Vector3.new(-width * 0.8, 0.12, 0)
					or name == "Battery" and Vector3.new(width * 0.8, 0.12, 0)
					or name:match("^Screw%d$") and Vector3.new((tonumber(name:sub(-1)) - 2.5) * 0.35, 0.18, width * 0.7)
					or Vector3.new(width * 0.8, 0.12, 0.7)
				view.loose[part] = part.CFrame + plane:VectorToWorldSpace(offset)
				part:SetAttribute("DPU_DeviceLoose", view.loose[part])
			end
			if part.Parent.Name == "Pipes" then
				part.Transparency, part.CanQuery = 1, false
			end
		end
	end
	-- Only detach an optional legacy anchor after the complete copy is validated.
	if anchor then
		self.anchors[anchor] = anchor.Parent
		anchor.Parent = nil
	end
	model.Parent = self.folder
	table.insert(self.copies, model)
	if repair then
		self.views[name] = view
	end
	return model
end
function Devices:Update(name, lane)
	local view = self.views[name]
	local order, work = lane.order, lane.work
	local p = work and work.Puzzle
	local step, stage = order and order.Step, p and p.DeviceStage
	local key = table.concat(
		{ order and order.Id or "", step or "", work and work.Id or "", stage or "", tostring(p and p.Revision) },
		":"
	)
	if key == view.key then
		return
	end
	view.key = key
	local opened = step
		and not table.find({
			"Arriving",
			"Waiting",
			"Diagnose",
			"Install",
			"Evidence",
			"Test",
			"ReadyForPickup",
			"PickupArriving",
			"Return",
		}, step)
	for part, home in pairs(view.homes) do
		local name, loose = part.Name, false
		if name:match("^Screw%d$") then
			local index = tonumber(name:sub(-1))
			loose = opened or step == "Diagnose" and stage and (stage ~= "OpenScrews" or p.Turns[index] >= 1)
			if stage == "CloseScrews" then
				loose = p.Turns[index] == 0
			end
		elseif name == "BackCover" then
			loose = opened or stage == "RemoveBattery" or stage == "Probes"
			if stage == "CloseScrews" then
				loose = false
			end
		elseif name == "Battery" then
			loose = step == "Collect" or step == "Repair" or step == "Secure" or stage == "Probes"
			if step == "Secure" then
				loose = stage == nil and order.Fault ~= "Battery" or stage == "FitBattery"
			end
			if step == "Repair" and order.Fault == "Battery" and not p then
				loose = false
			end
		elseif (name == "Speaker" or name == "Keypad") and step == "Repair" and order.Fault == name then
			loose = p and p.Phase == 2
		end
		local goal = loose and view.loose[part] or home
		if goal and goal ~= part.CFrame then
			if view.tweens[part] then
				view.tweens[part]:Cancel()
			end
			local tween = self.services.TweenService:Create(
				part,
				TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut),
				{ CFrame = goal }
			)
			view.tweens[part] = tween
			tween:Play()
		end
	end
end
function Devices:Carry(customer)
	local grip = customer:FindFirstChild("DeviceGrip", true)
	local hand = customer:FindFirstChild("RightHand", true)
		or customer:FindFirstChild("Right Arm", true)
		or customer:FindFirstChild("HumanoidRootPart", true)
		or customer:FindFirstChildWhichIsA("BasePart", true)
	if not hand or not hand:IsA("BasePart") then
		return
	end
	local phone = clone(self.template)
	phone.Name = "CustomerDevice"
	phone:PivotTo(grip and grip:IsA("Attachment") and grip.WorldCFrame or hand.CFrame * CFrame.new(0, -0.5, -0.25))
	for _, part in ipairs(phone:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored, part.CanQuery, part.Massless = false, false, true
			local weld = Instance.new("WeldConstraint")
			weld.Part0, weld.Part1, weld.Parent = hand, part, part
		end
	end
	phone.Parent = customer
	return phone
end
function Devices.ShowCarried(phone, visible)
	if not phone then
		return
	end
	for _, part in ipairs(phone:GetDescendants()) do
		if part:IsA("BasePart") then
			if part:GetAttribute("DPU_CarryAlpha") == nil then
				part:SetAttribute("DPU_CarryAlpha", part.Transparency)
			end
			part.Transparency = visible and part:GetAttribute("DPU_CarryAlpha") or 1
		end
	end
end
function Devices:Destroy()
	for _, view in pairs(self.views) do
		for _, tween in pairs(view.tweens) do
			tween:Cancel()
		end
	end
	for _, model in ipairs(self.copies) do
		model:Destroy()
	end
	for anchor, parent in pairs(self.anchors) do
		anchor.Parent = parent
	end
end
return Devices
