-- Physical adapter only. ShiftService owns part reservations, stock and accepted work.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("GShared", 30)
local Scene = require(Shared:WaitForChild("World", 30):WaitForChild("SceneReferences", 30))
local Workshop = {}
Workshop.__index = Workshop

function Workshop.new(folder, origin, phone)
	local self =
		setmetatable({ tools = {}, gear = {}, phone = phone, folder = folder, seats = {}, pendingSeats = {} }, Workshop)
	self.seat = self:AddSeat("Bench", origin * CFrame.new(-12, 1.7, 3))
	return self
end
function Workshop:AddSeat(station, frame)
	local name = station == "Bench" and "RepairSeat" or station .. "Seat"
	local seat = self.folder:FindFirstChild(name)
	assert(seat and seat:IsA("Seat"), "[DPU] Missing authored " .. self.folder:GetFullName() .. "." .. name)
	self.seats[station] = seat
	return seat
end
function Workshop:SeatStation(player)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 or not humanoid.Sit then
		return nil
	end
	for station, seat in pairs(self.seats) do
		if seat.Parent and humanoid.SeatPart == seat and seat.Occupant == humanoid then
			return station
		end
	end
	return nil
end
function Workshop:IsSeated(player, station)
	local seated = self:SeatStation(player)
	return seated ~= nil and (station == nil or station == seated)
end
function Workshop:Sit(player, station)
	station = station or "Bench"
	local seat = self.seats[station]
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 or not seat or not seat.Parent then
		return false, "NotReady"
	end
	if self:IsSeated(player, station) then
		return true
	end
	local pending = self.pendingSeats[station]
	if seat.Occupant or (pending and pending.Player ~= player and os.clock() < pending.Until) then
		return false, "BenchOccupied"
	end
	self.pendingSeats[station] = { Player = player, Until = os.clock() + 1 }
	seat:Sit(humanoid)
	return true
end
function Workshop:Stand(player)
	for station, pending in pairs(self.pendingSeats) do
		if pending.Player == player then
			self.pendingSeats[station] = nil
		end
	end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		for _, seat in pairs(self.seats) do
			if humanoid.SeatPart == seat or seat.Occupant == humanoid then
				humanoid.Sit = false
			end
		end
	end
end

function Workshop:ClearPart(player)
	local entry = self.tools[player]
	self.tools[player] = nil
	if entry then
		entry.Tool:Destroy()
	end
end

function Workshop:GivePart(player, record)
	local backpack = player:FindFirstChildOfClass("Backpack")
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not backpack or not humanoid or humanoid.Health <= 0 then
		return false
	end
	self:ClearPart(player)
	local tool = Instance.new("Tool")
	tool.Name, tool.ToolTip =
		record.Fault .. " replacement", "Carry this to the repair bench and place it beside the phone."
	tool.CanBeDropped, tool.RequiresHandle = false, true
	tool:SetAttribute("DPU_RepairPart", true)
	tool:SetAttribute("RunId", record.RunId)
	tool:SetAttribute("OrderId", record.OrderId)
	tool:SetAttribute("PartType", record.Fault)
	local component = Scene.Station(self.folder, "Part_" .. record.Fault)
		or self.phone and self.phone:FindFirstChild(record.Fault, true)
	local handle = component and component:IsA("BasePart") and component:Clone() or Instance.new("Part")
	for _, item in ipairs(handle:GetDescendants()) do
		if
			item:IsA("LuaSourceContainer")
			or item:IsA("JointInstance")
			or item:IsA("Constraint")
			or item:IsA("ProximityPrompt")
			or item:IsA("ClickDetector")
			or item:IsA("SurfaceGui")
			or item:IsA("BillboardGui")
		then
			item:Destroy()
		end
	end
	handle:SetAttribute("DPU_Direct", nil)
	handle:SetAttribute("DPU_Enabled", nil)
	handle.Name, handle.Size = "Handle", Vector3.new(0.7, 0.35, 1)
	if component and component:IsA("BasePart") then
		handle.Size = component.Size
	end
	handle.Anchored, handle.CFrame, handle.Transparency = false, CFrame.new(), 0
	handle.Color = record.Fault == "Battery" and Color3.fromRGB(123, 117, 85)
		or record.Fault == "Speaker" and Color3.fromRGB(102, 104, 95)
		or Color3.fromRGB(155, 143, 115)
	handle.CanCollide, handle.CanTouch, handle.Massless, handle.CastShadow = false, false, true, false
	handle.Parent = tool
	self.tools[player] = { Tool = tool, Record = record }
	tool.Parent = backpack
	humanoid:EquipTool(tool)
	return true
end

function Workshop:HasPart(player, record)
	local entry = self.tools[player]
	local backpack = player:FindFirstChildOfClass("Backpack")
	return entry ~= nil
		and entry.Record == record
		and entry.Tool.Parent ~= nil
		and (entry.Tool.Parent == backpack or entry.Tool.Parent == player.Character)
end

function Workshop:Destroy()
	for player in pairs(self.gear) do
		self:ClearGear(player)
	end
	for player in pairs(self.tools) do
		self:ClearPart(player)
	end
	for _, seat in pairs(self.seats) do
		if seat.Occupant then
			seat.Occupant.Sit = false
		end
	end
end

function Workshop:HasGear(player, id)
	local item = self.gear[player] and self.gear[player][id]
	local backpack = player:FindFirstChildOfClass("Backpack")
	return item ~= nil and item.Parent ~= nil and (item.Parent == backpack or item.Parent == player.Character)
end
function Workshop:GiveGear(player, id)
	if self:HasGear(player, id) then
		return true
	end
	local backpack = player:FindFirstChildOfClass("Backpack")
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not backpack or not humanoid or humanoid.Health <= 0 then
		return false
	end
	self.gear[player] = self.gear[player] or {}
	local previous = self.gear[player][id]
	if previous then
		previous:Destroy()
	end
	local tool = Instance.new("Tool")
	tool.Name, tool.ToolTip, tool.CanBeDropped = id, "Keep this in your kit. Use the matching station to work.", false
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = id == "Screwdriver" and Vector3.new(0.18, 1.4, 0.18)
		or id == "BrassKey" and Vector3.new(0.45, 0.15, 0.8)
		or Vector3.new(0.8, 0.3, 1.1)
	handle.Color = id == "BrassKey" and Color3.fromRGB(192, 149, 55) or Color3.fromRGB(127, 135, 90)
	handle.CanCollide, handle.CanTouch, handle.Massless = false, false, true
	handle.Parent, tool.Parent = tool, backpack
	self.gear[player][id] = tool
	humanoid:EquipTool(tool)
	return true
end
function Workshop:ClearGear(player)
	for _, tool in pairs(self.gear[player] or {}) do
		tool:Destroy()
	end
	self.gear[player] = nil
end

return Workshop
