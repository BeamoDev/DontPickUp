-- Disposable shop geometry, customers, and interaction adapters for the first playable night.
local World = {}
local RepairTemplates = require(script.Parent.RepairTemplates)
local Workshop = require(script.Parent.Workshop)
World.__index = World
local OLIVE = Color3.fromRGB(76, 80, 61)
local GREEN = Color3.fromRGB(128, 255, 115)

local function part(parent, name, size, frame, color, material)
	local value = Instance.new("Part")
	value.Name, value.Size, value.CFrame = name, size, frame
	value.Anchored, value.TopSurface, value.BottomSurface =
		true, Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	value.Color, value.Material = color, material or Enum.Material.SmoothPlastic
	value.Parent = parent
	return value
end

local function sign(parent, content, offset, color)
	local board = Instance.new("BillboardGui")
	board.Name, board.Size, board.StudsOffset =
		"Sign", UDim2.fromScale(4.8, 1.1), offset or Vector3.new(0, 3, 0)
	-- Billboard scale is measured in studs: signs shrink naturally with distance.
	board.MaxDistance, board.AlwaysOnTop = 35, false
	board.Parent = parent
	local label = Instance.new("TextLabel")
	label.Size, label.BackgroundTransparency = UDim2.fromScale(1, 1), 0.5
	label.BackgroundColor3, label.TextColor3 = Color3.fromRGB(0, 0, 0), color or GREEN
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
		connections = {},
		avatars = {},
		lamps = {},
		closing = false,
	}, World)
	assert(
		not workspace:FindFirstChild("DPU_Prototype"),
		"Duplicate prototype world; only run one Game bootstrap"
	)
	local marker = workspace:FindFirstChild("DontPickUpPrototypeOrigin")
	self.origin = marker and marker:IsA("BasePart") and marker.CFrame or CFrame.new(0, 0, 400)
	local folder = Instance.new("Folder")
	folder.Name, folder.Parent = "DPU_Prototype", workspace
	folder:SetAttribute("PrototypeOwned", true)
	self.folder = folder
	local function p(name, size, position, color, material)
		return part(folder, name, size, self.origin * CFrame.new(position), color, material)
	end
	p(
		"Ground",
		Vector3.new(100, 1, 110),
		Vector3.new(0, -0.5, -20),
		Color3.fromRGB(37, 39, 35),
		Enum.Material.Concrete
	)
	p(
		"ShopFloor",
		Vector3.new(48, 0.3, 38),
		Vector3.new(0, 0.15, 0),
		Color3.fromRGB(92, 83, 66),
		Enum.Material.Concrete
	)
	p("BackWall", Vector3.new(48, 13, 1), Vector3.new(0, 6.5, 19), OLIVE)
	p("LeftWall", Vector3.new(1, 13, 38), Vector3.new(-24, 6.5, 0), OLIVE)
	p("RightWallFront", Vector3.new(1, 13, 20), Vector3.new(24, 6.5, -9), OLIVE)
	p("RightWallBack", Vector3.new(1, 13, 10), Vector3.new(24, 6.5, 14), OLIVE)
	p("StaffDoorLintel", Vector3.new(1, 6, 8), Vector3.new(24, 10, 5), OLIVE)
	p("Roof", Vector3.new(49, 1, 39), Vector3.new(0, 13, 0), Color3.fromRGB(52, 55, 47))
	p("FrontLower", Vector3.new(48, 3, 1), Vector3.new(0, 1.5, -19), OLIVE)
	p("FrontUpper", Vector3.new(48, 3, 1), Vector3.new(0, 11.5, -19), OLIVE)
	for _, x in ipairs({ -18, 18 }) do
		p("WindowSide", Vector3.new(12, 7, 1), Vector3.new(x, 6.5, -19), OLIVE)
	end
	for y = 4, 9, 2 do
		p(
			"RustyHorizontalBar",
			Vector3.new(24, 0.15, 0.2),
			Vector3.new(0, y, -19),
			Color3.fromRGB(90, 55, 37),
			Enum.Material.CorrodedMetal
		)
	end
	p("PartsRoomFrontLeft", Vector3.new(7, 9, 0.5), Vector3.new(-20.5, 4.5, 8), OLIVE)
	p("PartsRoomFrontRight", Vector3.new(7, 9, 0.5), Vector3.new(-7.5, 4.5, 8), OLIVE)
	p("PartsRoomRightWall", Vector3.new(0.5, 9, 11), Vector3.new(-4, 4.5, 13.5), OLIVE)
	local lintel = p("PartsRoomDoorway", Vector3.new(6, 2, 0.5), Vector3.new(-14, 8, 8), OLIVE)
	sign(lintel, "PARTS ROOM", Vector3.new(0, 1, 0))
	local shelter =
		p("Shelter", Vector3.new(8, 0.1, 5), Vector3.new(-13, 0.4, 15), Color3.fromRGB(71, 106, 64))
	shelter.CanCollide = false
	self.stations.Shelter = shelter
	sign(shelter, "STORAGE SHELTER\nStay inside when warned", Vector3.new(0, 4, 0))
	local stationSpecs = {
		Tool_Tester = { Vector3.new(-7, 2.4, 12), Vector3.new(1.2, 0.6, 1.4), "BENCH TESTER / TAKE" },
		Tool_Screwdriver = { Vector3.new(-18, 2.4, 16), Vector3.new(0.3, 0.3, 1.5), "SCREWDRIVER / TAKE" },
		Tool_Cartridge = { Vector3.new(16, 2.5, 12), Vector3.new(1.2, 0.3, 1.4), "SOFTWARE CARTRIDGE / TAKE" },
		Tool_BrassKey = { Vector3.new(21, 0.55, -16), Vector3.new(0.4, 0.15, 0.8), "Small brass key" },
		Secret_Timecard = { Vector3.new(-2, 0.6, 17), Vector3.new(0.8, 0.1, 1.3), "Discarded timecard" },
		Secret_Tape = { Vector3.new(-22, 0.6, -9), Vector3.new(0.8, 0.3, 0.6), "Unmarked tape" },
		Secret_Locker = { Vector3.new(17, 1.5, -13), Vector3.new(2.5, 3, 2), "Locked archive drawer" },
		StaffDoor = { Vector3.new(24, 3.5, 5), Vector3.new(0.3, 7, 8), "STAFF ENTRANCE" },
		Timeclock = { Vector3.new(20, 3, 6), Vector3.new(1.5, 2, 0.6), "TIMECLOCK / CLOCK IN" },
		Radio = { Vector3.new(5, 2, 13), Vector3.new(3, 2, 1.5), "RADIO / TUNE" },
		DeskLamp = { Vector3.new(-8.5, 4, -2), Vector3.new(0.4, 1.5, 0.4), "BENCH LAMP" },
		Counter = { Vector3.new(0, 1.7, -13), Vector3.new(15, 3.4, 4), "INTAKE / RETURNS" },
		Bench = { Vector3.new(-12, 1.5, -1), Vector3.new(9, 3, 4), "REPAIR BENCH" },
		Stock = { Vector3.new(-7, 1, 15), Vector3.new(3, 2, 3), "SUPPLY CRATE / RESTOCK" },
		Part_Battery = { Vector3.new(-21, 2, 10), Vector3.new(3, 4, 2), "BATTERIES" },
		Part_Speaker = { Vector3.new(-21, 2, 13.5), Vector3.new(3, 4, 2), "SPEAKERS" },
		Part_Keypad = { Vector3.new(-21, 2, 17), Vector3.new(3, 4, 2), "KEYPADS" },
		Fuse = { Vector3.new(22, 4, 10), Vector3.new(1, 4, 3), "FUSE BOX" },
		Phone = { Vector3.new(10, 1.5, -1), Vector3.new(5, 3, 4), "DISCONNECTED PHONE" },
		Records = { Vector3.new(20, 2, -6), Vector3.new(4, 4, 4), "REPAIR RECORDS" },
	}
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
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name, prompt.ObjectText, prompt.ActionText = "Interact", spec[3], "Use"
		prompt.HoldDuration, prompt.MaxActivationDistance, prompt.RequiresLineOfSight = 0, 10, false
		if string.match(name, "^Tool_") or string.match(name, "^Secret_") then
			prompt.MaxActivationDistance, prompt.RequiresLineOfSight = 5, true
		end
		if name == "Bench" then
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
	end
	self.doorClosed = self.stations.StaffDoor.CFrame
	p("TesterShelf", Vector3.new(3, 2.1, 2), Vector3.new(-7, 1.05, 12), OLIVE)
	p("ToolDrawer", Vector3.new(3, 2.1, 2), Vector3.new(-18, 1.05, 16), OLIVE)
	p("CartridgeShelf", Vector3.new(3, 2.2, 2), Vector3.new(16, 1.1, 12), OLIVE)
	local stampButton = p("TimeclockStamp", Vector3.new(0.55, 0.3, 0.12), Vector3.new(20, 2.65, 6.37), GREEN)
	stampButton.CanCollide, stampButton.CanTouch = false, false
	local timecard = p(
		"TimecardSlot",
		Vector3.new(0.9, 0.8, 0.08),
		Vector3.new(20, 3.4, 6.35),
		Color3.fromRGB(188, 181, 144)
	)
	timecard.CanCollide, timecard.CanTouch = false, false
	local clockCamera = Instance.new("Attachment")
	clockCamera.Name, clockCamera.CFrame, clockCamera.Parent =
		"InteractionCamera", CFrame.lookAt(Vector3.new(2, 0.6, 4), Vector3.zero), self.stations.Timeclock
	self.doorOpened = self.origin
		* CFrame.new(24, 3.5, 1)
		* CFrame.Angles(0, math.pi / 2, 0)
		* CFrame.new(0, 0, 4)
	local benchLight = Instance.new("PointLight")
	benchLight.Name, benchLight.Range, benchLight.Brightness = "WorkLight", 12, 2
	benchLight.Color, benchLight.Parent = Color3.fromRGB(225, 207, 145), self.stations.DeskLamp
	self.benchLight = benchLight
	local answer = Instance.new("ProximityPrompt")
	answer.Name, answer.ObjectText, answer.ActionText = "Answer", "DO NOT PICK UP", "Answer anyway (danger)"
	answer.KeyboardKeyCode, answer.HoldDuration, answer.MaxActivationDistance = Enum.KeyCode.F, 1.5, 10
	answer.RequiresLineOfSight, answer.Enabled, answer.Parent = false, false, self.stations.Phone
	self.answer = answer
	table.insert(
		self.connections,
		answer.Triggered:Connect(function(player)
			if self.interact then
				self.interact(player, "Answer")
			end
		end)
	)
	self.repairPhone, self.releaseTemplate =
		RepairTemplates.Build(services.ReplicatedStorage, folder, self.origin * CFrame.new(-12, 3.05, -1))
	self.workshop = Workshop.new(folder, self.origin, self.repairPhone)
	self.phoneParts = {}
	for _, item in ipairs(self.repairPhone:GetDescendants()) do
		if item:IsA("BasePart") then
			self.phoneParts[item] = item.Transparency or 0
		end
	end
	self.replacement = p("ReplacementTray", Vector3.new(0.8, 0.2, 1.1), Vector3.new(-10, 3.2, -1), GREEN)
	self.replacement.CanCollide, self.replacement.CanTouch, self.replacement.Transparency = false, false, 1
	local focus = Instance.new("Attachment")
	focus.Name, focus.CFrame, focus.Parent = "RepairFocus", CFrame.new(0, 1.8, 0), self.stations.Bench
	local camera = Instance.new("Attachment")
	camera.Name = "RepairCamera"
	camera.CFrame = CFrame.lookAt(Vector3.new(0, 5.3, 4), Vector3.new(0, 1.8, 0))
	camera.Parent = self.stations.Bench
	p("DeskPhoneBase", Vector3.new(2, 0.4, 1.6), Vector3.new(10, 3.25, -1), Color3.fromRGB(42, 41, 34))
	self.receiver =
		p("Receiver", Vector3.new(2.4, 0.4, 0.6), Vector3.new(10, 3.65, -1.3), Color3.fromRGB(27, 29, 24))
	p("CRT", Vector3.new(2.5, 2, 2), Vector3.new(-15, 4, -1.5), Color3.fromRGB(155, 146, 118))
	p(
		"CRTScreen",
		Vector3.new(1.8, 1.3, 0.1),
		Vector3.new(-15, 4, -0.45),
		Color3.fromRGB(35, 101, 52),
		Enum.Material.Neon
	)
	for _, x in ipairs({ -12, 12 }) do
		local fixture = p(
			"CeilingLight",
			Vector3.new(6, 0.2, 1.5),
			Vector3.new(x, 12.3, 1),
			Color3.fromRGB(220, 224, 174),
			Enum.Material.Neon
		)
		local light = Instance.new("PointLight")
		light.Color, light.Brightness, light.Range, light.Shadows, light.Parent =
			Color3.fromRGB(219, 228, 176), 2, 36, true, fixture
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
		"StaffSpawn",
		Vector3.new(6, 0.3, 4),
		self.origin * CFrame.new(32, 0.5, 7) * CFrame.Angles(0, math.pi / 2, 0)
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

function World:Near(player, name)
	local _, root = rig(player)
	local station = self.stations[name]
	if not root or not station then
		return false
	end
	local point = station.CFrame:PointToObjectSpace(root.Position)
	if name == "Shelter" then
		return math.abs(point.X) <= station.Size.X / 2
			and math.abs(point.Z) <= station.Size.Z / 2
			and math.abs(point.Y) <= 7
	end
	local distance = self.c.InteractionDistance
	if string.match(name, "^Tool_") or string.match(name, "^Secret_") then
		distance = 5
		local inside = self.origin:PointToObjectSpace(root.Position)
		if math.abs(inside.X) > 23.5 or math.abs(inside.Z) > 18.5 then
			return false
		end
	end
	if name == "Timeclock" then
		local localPoint = self.origin:PointToObjectSpace(root.Position)
		if localPoint.X > 23 then
			return false
		end
		distance = 5
	end
	if name == "Bench" then
		distance = 6
	end
	if
		name == "Stock"
		or string.match(name, "^Part_")
		or name == "Tool_Tester"
		or name == "Tool_Screwdriver"
	then
		local localPoint = self.origin:PointToObjectSpace(root.Position)
		if localPoint.X < -24 or localPoint.X > -4 or localPoint.Z < 8.5 or localPoint.Z > 19 then
			return false
		end
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

function World:Render(run)
	-- Lighting changes once per in-game minute; scene bindings only on state changes.
	local elapsed = run.nightAt
			and math.clamp(
				(run.endedAt or workspace:GetServerTimeNow()) - run.nightAt,
				0,
				self.c.NightSeconds
			)
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
	local visualOrder, visualEvent = run.order, run.event
	local visualKey = table.concat({
		run.phase,
		visualOrder and visualOrder.Id or "",
		visualOrder and visualOrder.Step or "",
		tostring(visualOrder and visualOrder.PausedAt ~= nil),
		tostring(visualOrder and visualOrder.PartDelivered == true),
		visualOrder and visualOrder.Fault or "",
		visualEvent and visualEvent.Id or "",
		visualEvent and visualEvent.Kind or "",
		run.work and run.work.Station or "",
		tostring(run.doorOpen == true),
		tostring(run.lampOn ~= false),
		tostring(run.stock.Battery or 0),
		tostring(run.stock.Speaker or 0),
		tostring(run.stock.Keypad or 0),
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
	local order = run.order
	local suspended = order and order.Step == "Arriving" and order.PausedAt ~= nil
	if suspended and self.customer then
		self.customer:Destroy()
		self.customer, self.orderId = nil, nil
	end
	if order and not suspended and self.orderId ~= order.Id then
		if self.customer then
			self.customer:Destroy()
		end
		self.orderId = order.Id
		local coat = order.Coat or { 105, 88, 58 }
		self.customer = self:Figure(
			"Customer",
			self.origin * CFrame.new(0, 3.5, -43),
			Color3.fromRGB(coat[1], coat[2], coat[3])
		)
		self.customerLabel = sign(self.customer.PrimaryPart, order.Customer, Vector3.new(0, 3.6, 0))
		self.s.TweenService
			:Create(
				self.customer.PrimaryPart,
				TweenInfo.new(self.c.ArrivalSeconds, Enum.EasingStyle.Linear),
				{ CFrame = self.origin * CFrame.new(0, 3.5, -21) }
			)
			:Play()
	elseif not order and self.customer then
		local customer = self.customer
		self.customer, self.orderId = nil, nil
		self.s.TweenService
			:Create(
				customer.PrimaryPart,
				TweenInfo.new(4, Enum.EasingStyle.Linear),
				{ CFrame = self.origin * CFrame.new(0, 3.5, -43) }
			)
			:Play()
		task.delay(4, function()
			customer:Destroy()
		end)
	end
	local event = run.event
	local blackout = event and event.Kind == "Blackout"
	for _, lamp in ipairs(self.lamps) do
		if lamp.Enabled ~= not blackout then
			lamp.Enabled = not blackout
		end
	end
	self.receiver.Color = event and event.Kind == "Call" and Color3.fromRGB(165, 43, 36)
		or Color3.fromRGB(27, 29, 24)
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
		for _, id in ipairs({ "Tester", "Screwdriver", "Cartridge", "BrassKey" }) do
			actions["Tool_" .. id] = "PickupTool"
		end
		for _, id in ipairs({ "Timecard", "Tape", "Locker" }) do
			actions["Secret_" .. id] = "Discover"
		end
		actions.Radio, actions.DeskLamp = "TuneRadio", "ToggleLamp"
		actions.Records = "InspectRecords"
		if not run.event then
			actions.Stock = "Restock"
		end
		if order and not run.event then
			actions.Counter = order.Step == "Waiting" and "TakeOrder"
				or order.Step == "Return" and "Return"
				or nil
			actions.Bench = table.find({ "Diagnose", "Repair", "Secure", "Install", "Test" }, order.Step)
					and order.Step
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
			actions.Records = event.Kind == "Inspection" and "Records" or "InspectRecords"
		end
	end
	self.actions = actions
	local names = {
		OpenClock = "Inspect timeclock",
		PickupTool = "Pick up",
		Discover = "Inspect",
		ToggleDoor = run.doorOpen and "Close staff door" or "Open staff door",
		ClockIn = "Clock in",
		TuneRadio = "Tune radio",
		ToggleLamp = "Toggle work light",
		InspectRecords = "Read shift log",
		Secure = "Tighten contact",
		Sit = "Sit at repair bench",
		TakeOrder = "Accept phone",
		Return = "Return repaired phone",
		Diagnose = "Diagnose",
		Collect = "Collect replacement",
		Repair = "Fit replacement",
		Install = "Install government package",
		Test = "Test phone",
		Restock = "Restock parts",
		RestorePower = "Restore power",
		Silence = "Silence the phone",
		Records = "Present repair records",
	}
	for name, prompt in pairs(self.prompts) do
		local enabled = actions[name] ~= nil and not (run.work and run.work.Station == name)
		local text = names[actions[name]] or "Use"
		local fault = string.match(name, "^Part_(.+)$")
		if fault then
			text = "Take " .. fault .. " (" .. tostring(run.stock[fault] or 0) .. ")"
		end
		if name == "Bench" and actions.Bench then
			text = "Sit / use repair bench"
		end
		if prompt.Enabled ~= enabled then
			prompt.Enabled = enabled
		end
		if prompt.ActionText ~= text then
			prompt.ActionText = text
		end
	end
	self.answer.Enabled = actions.Phone ~= nil
	local visible = order ~= nil and order.Step ~= "Arriving" and order.Step ~= "Waiting"
	if visible ~= self.phoneVisible then
		self.phoneVisible = visible
		for object, alpha in pairs(self.phoneParts) do
			object.Transparency = visible and alpha or 1
		end
	end
	self.replacement.Transparency = order and order.PartDelivered and 0 or 1
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
end

return World
