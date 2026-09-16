-- Disposable shop geometry, customers, and interaction adapters for the first playable night.
local World = {}
local Stations = require(script.Parent.Parent.Repair.RepairStations)
local RepairTemplates = require(script.Parent.Parent.Repair.RepairTemplates)
local Workshop = require(script.Parent.Parent.Repair.Workshop)
local LoreRecords = require(script.Parent.Parent.Lore.ShopSecrets)
local ShopLayout = require(script.Parent.ShopLayout)
World.__index = World
local OLIVE = Color3.fromRGB(76, 80, 61)
local PAPER = Color3.fromRGB(228, 224, 216)

local function part(parent, name, size, frame, color, material)
	local value = Instance.new("Part")
	value.Name, value.Size, value.CFrame = name, size, frame
	value.Anchored, value.TopSurface, value.BottomSurface = true, Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	value.Color, value.Material = color, material or Enum.Material.SmoothPlastic
	value.Parent = parent
	return value
end

local function sign(parent, content, offset, color)
	local board = Instance.new("BillboardGui")
	board.Name, board.Size, board.StudsOffset =
		"Sign", UDim2.fromScale(3.8, 0.55), offset or Vector3.new(0, parent.Size.Y / 2 + 0.7, 0)
	-- Billboard scale is measured in studs: signs shrink naturally with distance.
	board.MaxDistance, board.AlwaysOnTop = 22, false
	board.Parent = parent
	local label = Instance.new("TextLabel")
	label.Size, label.BackgroundTransparency = UDim2.fromScale(1, 1), 1
	label.TextStrokeTransparency = 0.65
	label.BackgroundColor3, label.TextColor3 = Color3.fromRGB(0, 0, 0), PAPER
	label.BorderSizePixel = 0
	label.Font, label.TextScaled, label.TextWrapped = Enum.Font.Code, true, true
	label.Text, label.Parent = content, board
	return label
end

local function rig(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if root and humanoid and humanoid.Health > 0 then
		return character, root, humanoid
	end
end

function World.new(services, config)
	local self = setmetatable({
		s = services,
		c = config,
		stations = {},
		prompts = {},
		direct = {},
		connections = {},
		avatars = {},
		lamps = {},
		closing = false,
	}, World)
	assert(not workspace:FindFirstChild("DPU_Prototype"), "Duplicate prototype world; only run one Game bootstrap")
	local marker = workspace:FindFirstChild("DontPickUpPrototypeOrigin")
	self.origin = marker and marker:IsA("BasePart") and marker.CFrame or CFrame.new(0, 0, 400)
	local folder = Instance.new("Folder")
	folder.Name, folder.Parent = "DPU_Prototype", workspace
	folder:SetAttribute("PrototypeOwned", true)
	self.folder = folder
	local function p(name, size, position, color, material)
		return part(folder, name, size, self.origin * CFrame.new(position), color, material)
	end
	self.stations.Shelter = ShopLayout.Build(p, sign)
	local stationSpecs = {
		Tools = { Vector3.new(-8.5, 3.35, 0), Vector3.new(1.2, 0.5, 1.4), "REPAIR KIT" },
		Tool_BrassKey = { Vector3.new(19, 0.55, -17), Vector3.new(0.4, 0.15, 0.8), "Small brass key" },
		Secret_Timecard = { Vector3.new(-17, 0.6, 21), Vector3.new(0.8, 0.1, 1.3), "Discarded timecard" },
		Secret_Tape = { Vector3.new(18, 0.6, 21), Vector3.new(0.8, 0.3, 0.6), "Unmarked tape" },
		Secret_Locker = { Vector3.new(-20, 1.5, 20), Vector3.new(2.5, 3, 2), "Locked archive drawer" },
		StaffDoor = { Vector3.new(22, 3.5, 5), Vector3.new(0.3, 7, 8), "STAFF ENTRANCE" },
		Timeclock = { Vector3.new(18, 3, 0), Vector3.new(1.5, 2, 0.6), "TIMECLOCK / CLOCK IN" },
		Radio = { Vector3.new(17, 3.9, 18), Vector3.new(3, 2, 1.5), "RADIO / TUNE" },
		DeskLamp = { Vector3.new(-8.5, 4, -2), Vector3.new(0.4, 1.5, 0.4), "BENCH LAMP" },
		Fax = { Vector3.new(-5, 3.85, -13), Vector3.new(2.8, 0.9, 2), "FAX PHONE / CALL PICKUP" },
		Counter = { Vector3.new(0, 1.7, -13), Vector3.new(15, 3.4, 4), "TAKE / RETURN PHONES" },
		Bench = { Vector3.new(-12, 1.5, -1), Vector3.new(9, 3, 4), "BENCH 1" },
		Bench2 = { Vector3.new(10, 1.5, -1), Vector3.new(9, 3, 4), "BENCH 2" },
		Stock = { Vector3.new(-7, 1, 20), Vector3.new(3, 2, 3), "SUPPLY CRATE / RESTOCK" },
		Part_Battery = { Vector3.new(-19, 3.35, 15), Vector3.new(2.4, 0.6, 1.6), "BATTERIES" },
		Part_Speaker = { Vector3.new(-15, 3.35, 15), Vector3.new(2.4, 0.6, 1.6), "SPEAKERS" },
		Part_Keypad = { Vector3.new(-11, 3.35, 15), Vector3.new(2.4, 0.6, 1.6), "KEYPADS" },
		Fuse = { Vector3.new(21, 4, 17), Vector3.new(1, 4, 3), "FUSE BOX" },
		Phone = { Vector3.new(14, 1.5, 18), Vector3.new(8, 3, 4), "DISCONNECTED PHONE" },
		Records = { Vector3.new(5.5, 3.75, -13), Vector3.new(3, 0.5, 2), "Repair log" },
	}
	local lorePositions = {
		DeskNote = Vector3.new(-12, 0.6, -2),
		Directive = Vector3.new(20, 4, -3),
		Warning = Vector3.new(-20, 4, 10),
		RepairLog = Vector3.new(3, 3.5, -13),
		CustomerFile = Vector3.new(-18, 3.6, 15),
		Newspaper = Vector3.new(6, 3.5, -13),
		Photograph = Vector3.new(-20, 0.5, -5),
		Message = Vector3.new(17, 3.1, 18),
		Redacted = Vector3.new(-19, 0.6, 19),
		Correction = Vector3.new(19, 4, -3),
	}
	for id, position in pairs(lorePositions) do
		stationSpecs["Secret_" .. id] = { position, Vector3.new(1.4, 0.12, 2), LoreRecords[id].Format }
	end
	for name, spec in pairs(stationSpecs) do
		local object = p(
			name,
			spec[2],
			spec[1],
			name == "Fuse" and Color3.fromRGB(95, 92, 83) or Color3.fromRGB(100, 80, 56),
			Enum.Material.Wood
		)
		self.stations[name] = object
		if not string.match(name, "^Secret_") and name ~= "Tool_BrassKey" then
			sign(object, spec[3])
		end
		local larger = name == "StaffDoor"
			or name == "Counter"
			or (name == "Bench" or name == "Bench2")
			or name == "Fuse"
		if larger then
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name, prompt.ObjectText, prompt.ActionText = "Interact", spec[3], "Use"
			prompt.HoldDuration, prompt.MaxActivationDistance, prompt.RequiresLineOfSight = 0, 10, false
			-- Deliberate physical actions use the native hold ring. Menus and escape controls stay quick.
			prompt.HoldDuration = string.match(name, "^Part_") and 0.85
				or (name == "Tools" or string.match(name, "^Tool_")) and 0.5
				or name == "Stock" and 1
				or (name == "Bench" or name == "Bench2") and 0.4
				or name == "Fuse" and 1.2
				or name == "Counter" and 0.6
				or 0
			if name == "Tools" or string.match(name, "^Tool_") or string.match(name, "^Secret_") then
				prompt.MaxActivationDistance, prompt.RequiresLineOfSight = 5, true
			end
			if name == "Bench" or name == "Bench2" then
				prompt.MaxActivationDistance = 6
			end
			if name == "Timeclock" then
				prompt.MaxActivationDistance = 5
			end
			if name == "Stock" or string.match(name, "^Part_") then
				prompt.MaxActivationDistance, prompt.RequiresLineOfSight = 5, true
			end
			prompt.Enabled, prompt.Parent = false, object
			self.prompts[name] = prompt
			table.insert(
				self.connections,
				prompt.Triggered:Connect(function(player)
					if self.interact then
						self.interact(player, name)
					end
				end)
			)
		else
			self.direct[name] = object
			object:SetAttribute("DPU_Direct", name)
			object:SetAttribute("DPU_Range", name == "Phone" and 8 or 5)
			object:SetAttribute("DPU_Enabled", false)
		end
	end
	local faxReceiver =
		p("FaxReceiver", Vector3.new(2.2, 0.3, 0.45), Vector3.new(-5, 4.45, -13.55), Color3.fromRGB(38, 38, 34))
	faxReceiver.Parent = self.stations.Fax
	faxReceiver.CanCollide, faxReceiver.CanTouch, faxReceiver.CanQuery = false, false, false
	local faxPaper = p("FaxPaper", Vector3.new(1.6, 0.06, 1.2), Vector3.new(-5, 4.35, -12.85), PAPER)
	faxPaper.Parent = self.stations.Fax
	faxPaper.CanCollide, faxPaper.CanTouch, faxPaper.CanQuery = false, false, false
	self.doorClosed = self.stations.StaffDoor.CFrame
	local stampButton = p("TimeclockStamp", Vector3.new(0.55, 0.3, 0.12), Vector3.new(18, 2.65, 0.37), PAPER)
	stampButton.CanCollide, stampButton.CanTouch = false, false
	self.direct.TimeclockStamp = stampButton
	stampButton:SetAttribute("DPU_Direct", "Timeclock")
	stampButton:SetAttribute("DPU_Range", 5)
	local timecard =
		p("TimecardSlot", Vector3.new(0.9, 0.8, 0.08), Vector3.new(18, 3.4, 0.35), Color3.fromRGB(188, 181, 144))
	timecard.CanCollide, timecard.CanTouch = false, false
	local clockCamera = Instance.new("Attachment")
	clockCamera.Name, clockCamera.CFrame, clockCamera.Parent =
		"InteractionCamera", CFrame.lookAt(Vector3.new(2, 0.6, 4), Vector3.zero), self.stations.Timeclock
	self.doorOpened = self.origin * CFrame.new(22, 3.5, 1) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.new(0, 0, 4)
	local benchLight = Instance.new("PointLight")
	benchLight.Name, benchLight.Range, benchLight.Brightness = "WorkLight", 12, 2
	benchLight.Color, benchLight.Parent = Color3.fromRGB(225, 207, 145), self.stations.DeskLamp
	self.benchLight = benchLight
	self.repairPhone, self.releaseTemplate =
		RepairTemplates.Build(services.ReplicatedStorage, folder, self.origin * CFrame.new(-12, 3.05, -1))
	self.workshop = Workshop.new(folder, self.origin, self.repairPhone)
	self.phoneParts = {}
	for _, item in ipairs(self.repairPhone:GetDescendants()) do
		if item:IsA("BasePart") then
			self.phoneParts[item] = item.Transparency or 0
		end
	end
	self.replacement = p("ReplacementTray", Vector3.new(0.8, 0.2, 1.1), Vector3.new(-10, 3.2, -1), PAPER)
	self.replacement.CanCollide, self.replacement.CanTouch, self.replacement.Transparency = false, false, 1
	local focus = Instance.new("Attachment")
	focus.Name, focus.CFrame, focus.Parent = "RepairFocus", CFrame.new(0, 1.8, 0), self.stations.Bench
	local camera = Instance.new("Attachment")
	camera.Name = "RepairCamera"
	camera.CFrame = CFrame.lookAt(Vector3.new(0, 8.3, 0.8), Vector3.new(0, 1.8, 0))
	camera.Parent = self.stations.Bench
	self.repairLanes =
		{ Bench = { phone = self.repairPhone, parts = self.phoneParts, tray = self.replacement, offset = 0 } }
	local phone2, release2 =
		RepairTemplates.Build(services.ReplicatedStorage, folder, self.origin * CFrame.new(10, 3.05, -1))
	phone2.Name, self.releaseSecond = "RepairPhone2", release2
	self.workshop:AddSeat("Bench2", self.origin * CFrame.new(10, 1.7, 3))
	local parts2 = {}
	for _, item in ipairs(phone2:GetDescendants()) do
		if item:IsA("BasePart") then
			parts2[item] = item.Transparency or 0
		end
	end
	local tray2 = p("ReplacementTray2", Vector3.new(0.8, 0.2, 1.1), Vector3.new(12, 3.2, -1), PAPER)
	tray2.CanCollide, tray2.CanTouch, tray2.Transparency = false, false, 1
	self.repairLanes.Bench2 = { phone = phone2, parts = parts2, tray = tray2, offset = 9 }
	for id, lane in pairs(self.repairLanes) do
		local phone = lane.phone:Clone()
		phone.Name, phone.Parent = "CounterPhone_" .. id, folder
		phone:PivotTo(self.origin * CFrame.new(id == "Bench" and -1.5 or 1.5, 3.4, -13))
		lane.counterParts = {}
		for _, object in ipairs(phone:GetDescendants()) do
			if object:IsA("BasePart") then
				lane.counterParts[object] = object.Transparency
				object.Transparency, object.CanCollide, object.CanTouch = 1, false, false
			end
		end
	end
	for _, source in ipairs({ focus, camera }) do
		local marker2 = source:Clone()
		marker2.Parent = self.stations.Bench2
	end
	local phoneBase =
		p("DeskPhoneBase", Vector3.new(2, 0.4, 1.6), Vector3.new(14, 3.25, 18), Color3.fromRGB(42, 41, 34))
	self.stations.Phone:SetAttribute("DPU_Direct", nil)
	self.direct.Phone = phoneBase
	phoneBase:SetAttribute("DPU_Direct", "Phone")
	phoneBase:SetAttribute("DPU_Range", 8)
	self.receiver = p("Receiver", Vector3.new(2.4, 0.4, 0.6), Vector3.new(14, 3.65, 17.7), Color3.fromRGB(27, 29, 24))
	self.stations.Answer, self.direct.Answer = self.receiver, self.receiver
	self.receiver:SetAttribute("DPU_Direct", "Answer")
	self.receiver:SetAttribute("DPU_Range", 8)
	self.receiver:SetAttribute("DPU_Enabled", false)
	p("CRT", Vector3.new(2.5, 2, 2), Vector3.new(-15, 4, -1.5), Color3.fromRGB(155, 146, 118))
	p(
		"CRTScreen",
		Vector3.new(1.8, 1.3, 0.1),
		Vector3.new(-15, 4, -0.45),
		Color3.fromRGB(101, 103, 96),
		Enum.Material.Neon
	)
	for _, location in ipairs({ { -12, 0 }, { 12, 0 }, { 0, 16 } }) do
		local fixture = p(
			"CeilingLight",
			Vector3.new(6, 0.2, 1.5),
			Vector3.new(location[1], 12.3, location[2]),
			Color3.fromRGB(220, 224, 174),
			Enum.Material.Neon
		)
		local light = Instance.new("PointLight")
		light.Color, light.Brightness, light.Range, light.Shadows, light.Parent =
			Color3.fromRGB(219, 214, 198), 1.4, 22, false, fixture
		table.insert(self.lamps, light)
	end
	local backup = p(
		"BackupLight",
		Vector3.new(0.4, 0.8, 0.4),
		Vector3.new(0, 8, 14),
		Color3.fromRGB(255, 145, 61),
		Enum.Material.Neon
	)
	local light = Instance.new("PointLight")
	light.Color, light.Brightness, light.Range, light.Parent = backup.Color, 1, 35, backup
	local spawn = Instance.new("SpawnLocation")
	spawn.Name, spawn.Size, spawn.CFrame =
		"StaffSpawn", Vector3.new(6, 0.3, 4), self.origin * CFrame.new(30, 0.5, 5) * CFrame.Angles(0, math.pi / 2, 0)
	spawn.Anchored, spawn.Neutral, spawn.Duration, spawn.Transparency = true, true, 0, 1
	spawn.Parent = folder
	self.spawn = spawn
	self.spectate = self.origin * CFrame.new(0, 17, 2)
	p("ObservationDeck", Vector3.new(20, 1, 16), Vector3.new(0, 15, 2), Color3.fromRGB(55, 60, 48))
	sign(folder.ObservationDeck, "OFF DUTY / OBSERVATION", Vector3.new(0, 4, 0))
	self.originalLighting = {}
	for _, key in ipairs({ "ClockTime", "Brightness", "Ambient", "OutdoorAmbient", "FogEnd", "FogColor" }) do
		self.originalLighting[key] = services.Lighting[key]
	end
	services.Lighting.Brightness, services.Lighting.Ambient = 1.5, Color3.fromRGB(62, 66, 55)
	services.Lighting.OutdoorAmbient, services.Lighting.FogEnd = Color3.fromRGB(24, 28, 30), 150
	services.Lighting.FogColor = Color3.fromRGB(22, 28, 31)
	return self
end

function World:Outside(player)
	local _, root = rig(player)
	if not root then
		return nil
	end
	local point = self.origin:PointToObjectSpace(root.Position)
	-- One stud of tolerance at doorways prevents edge jitter from counting as exposure.
	local bounds = ShopLayout.Bounds
	return point.X < bounds[1] - 1
		or point.X > bounds[2] + 1
		or point.Z < bounds[3] - 1
		or point.Z > bounds[4] + 1
		or point.Y < -3
		or point.Y > 13.5
end

function World:Near(player, name)
	local _, root = rig(player)
	local station = self.stations[name]
	if not root or not station then
		return false
	end
	local room = ShopLayout.Rooms[ShopLayout.Access[name]]
	if room then
		local localPoint = self.origin:PointToObjectSpace(root.Position)
		if localPoint.X < room[1] or localPoint.X > room[2] or localPoint.Z < room[3] or localPoint.Z > room[4] then
			return false
		end
	end
	local point = station.CFrame:PointToObjectSpace(root.Position)
	if name == "Shelter" then
		return math.abs(point.X) <= station.Size.X / 2
			and math.abs(point.Z) <= station.Size.Z / 2
			and math.abs(point.Y) <= 7
	end
	local distance = self.c.InteractionDistance
	if name == "Tools" or string.match(name, "^Tool_") or string.match(name, "^Secret_") then
		distance = 5
		local inside = self.origin:PointToObjectSpace(root.Position)
		if math.abs(inside.X) > 21.5 or inside.Z < -18.5 or inside.Z > 22.5 then
			return false
		end
	end
	if name == "Fax" then
		distance = 5
	end
	if name == "Timeclock" then
		local localPoint = self.origin:PointToObjectSpace(root.Position)
		if localPoint.X > 21.5 then
			return false
		end
		distance = 5
	end
	if name == "Bench" or name == "Bench2" then
		distance = 6
	end
	if name == "Stock" or string.match(name, "^Part_") then
		distance = 5
	end
	return (root.Position - station.Position).Magnitude <= distance
end

function World:Reset(player, alive)
	local character, root, humanoid = rig(player)
	if not character then
		if player.Parent == self.s.Players then
			task.spawn(function()
				local ok, reason = pcall(function()
					player:LoadCharacterAsync()
				end)
				if not ok then
					warn("[DPU] Could not respawn staff:", reason)
				end
			end)
		end
		return
	end
	humanoid.Health = humanoid.MaxHealth
	local slot = self.avatars[player] and self.avatars[player].Slot or 1
	character:PivotTo((alive and self.spawn.CFrame * CFrame.new((slot - 2.5) * 3, 4, 0) or self.spectate))
	root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
end

function World:Attach(player, alive, died)
	if self.avatars[player] then
		return
	end
	local occupied = {}
	for _, avatar in pairs(self.avatars) do
		occupied[avatar.Slot] = true
	end
	local slot = 1
	while occupied[slot] do
		slot += 1
	end
	local binding = { OriginalSpawn = player.RespawnLocation, Slot = slot }
	self.avatars[player] = binding
	player.RespawnLocation = self.spawn
	local function characterAdded(character)
		if binding.Death then
			binding.Death:Disconnect()
		end
		local humanoid = character:WaitForChild("Humanoid", 10)
		local root = character:WaitForChild("HumanoidRootPart", 10)
		if
			self.closing
			or self.avatars[player] ~= binding
			or player.Character ~= character
			or not humanoid
			or not root
		then
			return
		end
		binding.Death = humanoid.Died:Connect(function()
			died(player)
		end)
		self:Reset(player, alive(player))
	end
	binding.Character = player.CharacterAdded:Connect(characterAdded)
	if player.Character then
		task.spawn(characterAdded, player.Character)
	end
end

function World:Remove(player)
	self.workshop:Stand(player)
	self.workshop:ClearPart(player)
	local binding = self.avatars[player]
	if not binding then
		return
	end
	if binding.Character then
		binding.Character:Disconnect()
	end
	if binding.Death then
		binding.Death:Disconnect()
	end
	if player.Parent then
		player.RespawnLocation = binding.OriginalSpawn
	end
	self.avatars[player] = nil
end

function World:Figure(name, position, color)
	local model = Instance.new("Model")
	model.Name, model.Parent = name, self.folder
	local root = part(model, "Root", Vector3.new(1, 1, 1), position, color)
	root.Transparency, root.CanCollide = 1, false
	model.PrimaryPart = root
	local pieces = {
		{ "Torso", Vector3.new(2, 2, 1), Vector3.new(0, 0, 0), color },
		{ "Head", Vector3.new(1.3, 1.3, 1.3), Vector3.new(0, 1.65, 0), Color3.fromRGB(152, 131, 103) },
		{ "EyeL", Vector3.new(0.16, 0.16, 0.08), Vector3.new(-0.3, 1.8, 0.68), Color3.fromRGB(13, 16, 12) },
		{ "EyeR", Vector3.new(0.16, 0.16, 0.08), Vector3.new(0.3, 1.8, 0.68), Color3.fromRGB(13, 16, 12) },
		{ "ArmL", Vector3.new(0.7, 2.5, 0.8), Vector3.new(-1.4, -0.2, 0), color },
		{ "ArmR", Vector3.new(0.7, 2.5, 0.8), Vector3.new(1.4, -0.2, 0), color },
		{ "LegL", Vector3.new(0.8, 2.4, 0.8), Vector3.new(-0.55, -2.1, 0), Color3.fromRGB(37, 43, 41) },
		{ "LegR", Vector3.new(0.8, 2.4, 0.8), Vector3.new(0.55, -2.1, 0), Color3.fromRGB(37, 43, 41) },
	}
	for _, spec in ipairs(pieces) do
		local limb = part(model, spec[1], spec[2], position * CFrame.new(spec[3]), spec[4])
		limb.Anchored, limb.CanCollide, limb.Massless = false, false, true
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1, weld.Parent = root, limb, root
	end
	return model
end

function World:ActionFor(run, player, station)
	local lane = Stations.ForPlayer(run, player)
	local order, member = lane.order, run.players[player]
	if not member then
		return nil
	end
	if station == "Bench" or station == "Bench2" then
		if member.StationId ~= station then
			return "SelectStation"
		end
		if member.CarriedPart then
			return "DepositPart"
		end
		if not self.workshop:IsSeated(player, station) then
			return "Sit"
		end
		return order and order.Step
	elseif station == "Counter" then
		order = Stations.AtCounter(run, player).order
		return order and (order.Step == "Waiting" and "TakeOrder" or order.Step == "Return" and "Return") or nil
	elseif station == "Answer" then
		return "Answer"
	end
	return self.actions and self.actions[station]
end

function World:Render(run)
	-- Lighting changes once per in-game minute; scene bindings only on state changes.
	local elapsed = run.nightAt
			and math.clamp((run.endedAt or workspace:GetServerTimeNow()) - run.nightAt, 0, self.c.NightSeconds)
		or 0
	local minute = run.phase == "Tutorial" and 22 * 60 or math.floor(elapsed / self.c.NightSeconds * 360)
	if minute ~= self.clockMinute then
		self.clockMinute = minute
		self.s.Lighting.ClockTime = minute / 60
	end
	if run.revision ~= nil and self.renderRevision == run.revision then
		return
	end
	self.renderRevision = run.revision
	-- Puzzle clicks and profile notices change snapshots without changing the scene.
	local visualOrder, visualEvent = run.stations.Bench.order, run.event
	local visualKey = table.concat({
		run.phase,
		visualOrder and visualOrder.Id or "",
		visualOrder and visualOrder.Step or "",
		tostring(visualOrder and visualOrder.PausedAt ~= nil),
		tostring(visualOrder and visualOrder.PartDelivered == true),
		visualOrder and visualOrder.Fault or "",
		visualEvent and visualEvent.Id or "",
		visualEvent and visualEvent.Kind or "",
		run.stations.Bench.work and run.stations.Bench.work.Station or "",
		tostring(run.doorOpen == true),
		tostring(run.lampOn ~= false),
		tostring(run.stock.Battery or 0),
		tostring(run.stock.Speaker or 0),
		tostring(run.stock.Keypad or 0),
	}, ":")
	local second = run.stations.Bench2
	visualKey ..= ":" .. table.concat({
		second.order and second.order.Id or "",
		second.order and second.order.Step or "",
		tostring(second.order and second.order.PartDelivered),
		tostring(second.order and second.order.PausedAt),
		second.work and second.work.Id or "",
	}, ":")
	if self.visualKey == visualKey then
		return
	end
	self.visualKey = visualKey
	if self.doorOpen ~= (run.doorOpen == true) then
		local first = self.doorOpen == nil
		self.doorOpen = run.doorOpen == true
		if self.doorTween then
			self.doorTween:Cancel()
		end
		local target = self.doorOpen and self.doorOpened or self.doorClosed
		-- Noncolliding while open so the swing cannot pin staff in the doorway.
		self.stations.StaffDoor.CanCollide = not self.doorOpen
		if first then
			self.stations.StaffDoor.CFrame = target
		else
			self.doorTween = self.s.TweenService:Create(
				self.stations.StaffDoor,
				TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ CFrame = target }
			)
			self.doorTween:Play()
		end
	end
	self.benchLight.Enabled = run.lampOn ~= false
	for _, id in ipairs(Stations.Ids) do
		self:RenderRepair(run.stations[id])
	end
	local order = run.stations.Bench.order
	local event = run.event
	local blackout = event and event.Kind == "Blackout"
	for _, lamp in ipairs(self.lamps) do
		if lamp.Enabled ~= not blackout then
			lamp.Enabled = not blackout
		end
	end
	self.receiver.Color = event and event.Kind == "Call" and Color3.fromRGB(165, 43, 36) or Color3.fromRGB(27, 29, 24)
	local watcherKind = event
			and (event.Kind == "Visitor" or event.Kind == "Inspection" or event.Kind == "Shadow")
			and event.Kind
		or nil
	if watcherKind ~= self.watcherKind then
		if self.watcher then
			self.watcher:Destroy()
			self.watcher = nil
		end
		self.watcherKind = watcherKind
		if watcherKind then
			self.watcher = self:Figure(
				watcherKind,
				self.origin * CFrame.new(event.Kind == "Shadow" and -8 or 8, 3.5, -21),
				watcherKind ~= "Inspection" and Color3.fromRGB(12, 14, 12) or Color3.fromRGB(50, 61, 47)
			)
		end
	end
	local actions = {}
	if run.phase == "Tutorial" or run.phase == "Night" then
		actions.StaffDoor, actions.Timeclock = "ToggleDoor", "OpenClock"
		actions.Tools, actions.Tool_BrassKey = "PickupTool", "PickupTool"
		for id in pairs(LoreRecords) do
			actions["Secret_" .. id] = "Discover"
		end
		actions.Radio, actions.DeskLamp = "TuneRadio", "ToggleLamp"
		if not run.event then
			actions.Stock = "Restock"
			actions.Fax = "OpenFax"
		end
		if order and not run.event then
			actions.Counter = order.Step == "Waiting" and "TakeOrder" or order.Step == "Return" and "Return" or nil
			actions.Bench = table.find({ "Diagnose", "Repair", "Secure", "Install", "Test" }, order.Step) and order.Step
				or (order.Step == "Collect" or order.Step == "Evidence") and "Sit"
				or nil
			actions.Stock = "Restock"
			if order.Step == "Collect" then
				for _, fault in ipairs({ "Battery", "Speaker", "Keypad" }) do
					actions["Part_" .. fault] = (run.stock[fault] or 0) > 0 and "Collect" or nil
				end
			end
		end
		if event then
			actions.Fuse = event.Kind == "Blackout" and "RestorePower" or nil
			actions.Phone = event.Kind == "Call" and "Silence" or nil
			actions.Records = event.Kind == "Inspection" and "Records" or nil
		end
	end
	if run.phase == "Night" or run.phase == "Tutorial" then
		if not event then
			actions.Bench = "Sit"
			actions.Bench2 = run.phase == "Night" and "Sit" or nil
			for _, lane in pairs(run.stations) do
				local job = lane.order
				if job then
					if job.Step == "Waiting" or job.Step == "Return" then
						actions.Counter = "TakeOrder"
					end
					if job.Step == "Collect" then
						actions["Part_" .. job.Fault] = "Collect"
					end
				end
			end
		end
	end
	self.actions = actions
	local names = {
		OpenFax = "Use fax phone",
		OpenClock = "Open timeclock",
		PickupTool = "Pick up",
		Discover = "Inspect",
		ToggleDoor = run.doorOpen and "Close staff door" or "Open staff door",
		ClockIn = "Clock in",
		TuneRadio = "Tune radio",
		ToggleLamp = "Toggle work light",
		InspectRecords = "Read shift log",
		Secure = "Put phone back together",
		Sit = "Sit at repair bench",
		TakeOrder = "Accept phone",
		Return = "Return repaired phone",
		Diagnose = "Find the broken part",
		Collect = "Take new part",
		Repair = "Put in new part",
		Install = "Open customer phone",
		Test = "Test phone",
		Restock = "Unpack more parts",
		RestorePower = "Restore power",
		Silence = "Silence the phone",
		Records = "Show repair papers",
	}
	for name, prompt in pairs(self.prompts) do
		local enabled = actions[name] ~= nil
		local text = name == "Counter" and "Take / return phone"
			or name == "Tools" and "Take repair kit"
			or names[actions[name]]
			or "Use"
		local fault = string.match(name, "^Part_(.+)$")
		if fault then
			text = "Take " .. fault .. " (" .. tostring(run.stock[fault] or 0) .. ")"
		end
		if (name == "Bench" or name == "Bench2") and actions[name] then
			text = "Sit / use repair bench"
		end
		if prompt.Enabled ~= enabled then
			prompt.Enabled = enabled
		end
		if prompt.ActionText ~= text then
			prompt.ActionText = text
		end
	end
	for name, object in pairs(self.direct) do
		local station = object:GetAttribute("DPU_Direct") or name
		local enabled = station == "Answer" and actions.Phone ~= nil or actions[station] ~= nil
		object:SetAttribute("DPU_Enabled", enabled)
		object:SetAttribute(
			"DPU_Label",
			station == "Answer" and "Answer forbidden call?" or names[actions[station]] or "Inspect"
		)
	end
end

function World:RenderRepair(lane)
	local view = self.repairLanes[lane.Id]
	local order = lane.order
	local present = order
		and (
			order.Step == "Waiting"
			or order.Step == "Return"
			or ((order.Step == "Arriving" or order.Step == "PickupArriving") and not order.PausedAt)
		)
	local suspended = not present
	if suspended and view.customer then
		local customer = view.customer
		if view.customerTween then
			view.customerTween:Cancel()
			view.customerTween = nil
		end
		view.customer, view.orderId = nil, nil
		self.s.TweenService
			:Create(
				customer.PrimaryPart,
				TweenInfo.new(3, Enum.EasingStyle.Linear),
				{ CFrame = self.origin * CFrame.new(view.offset, 3.5, -43) }
			)
			:Play()
		task.delay(3, function()
			customer:Destroy()
		end)
	end
	if order and not suspended and view.orderId ~= order.Id then
		if view.customer then
			view.customer:Destroy()
		end
		view.orderId = order.Id
		local coat = order.Coat or { 105, 88, 58 }
		view.customer = self:Figure(
			"Customer_" .. lane.Id,
			self.origin * CFrame.new(view.offset, 3.5, -43),
			Color3.fromRGB(coat[1], coat[2], coat[3])
		)
		view.customerLabel = sign(view.customer.PrimaryPart, order.Customer, Vector3.new(0, 3.6, 0))
		view.customerTween = self.s.TweenService:Create(
			view.customer.PrimaryPart,
			TweenInfo.new(
				(order.Step == "Waiting" or order.Step == "Return") and 0 or self.c.ArrivalSeconds,
				Enum.EasingStyle.Linear
			),
			{ CFrame = self.origin * CFrame.new(view.offset, 3.5, -21) }
		)
		view.customerTween:Play()
	end
	local atCounter = order and (order.Step == "Waiting" or order.Step == "Return")
	for object, alpha in pairs(view.counterParts or {}) do
		object.Transparency = atCounter and alpha or 1
	end
	local visible = order ~= nil and order.Step ~= "Arriving" and not atCounter
	if visible ~= view.visible then
		view.visible = visible
		for object, alpha in pairs(view.parts) do
			object.Transparency = visible and alpha or 1
		end
	end
	view.tray.Transparency = order and order.PartDelivered and 0 or 1
end

function World:Shutdown()
	self.closing = true
	if self.doorTween then
		self.doorTween:Cancel()
	end
	for player in pairs(self.avatars) do
		self:Remove(player)
	end
	for _, connection in ipairs(self.connections) do
		connection:Disconnect()
	end
	for key, value in pairs(self.originalLighting) do
		self.s.Lighting[key] = value
	end
	self.workshop:Destroy()
	self.folder:Destroy()
	self.releaseTemplate()
	self.releaseSecond()
end

return World
