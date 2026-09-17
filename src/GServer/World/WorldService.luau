-- Binds the authored shop; only temporary actors and carried tools are runtime-owned.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("GShared", 30)
local Scene = require(Shared:WaitForChild("World", 30):WaitForChild("SceneReferences", 30))
local World = {}
local Policy = require(script.Parent.Parent.Story.GovernmentService)
local Stations = require(script.Parent.Parent.Repair.RepairStations)
local RepairTemplates = require(script.Parent.Parent.Repair.RepairTemplates)
local Devices = require(script.Parent.Parent.Repair.DevicePresentation)
local Workshop = require(script.Parent.Parent.Repair.WorkshopService)
local LoreRecords = require(script.Parent.Parent.Story.LoreCatalog)
local ShopLayout = require(script.Parent.WorldLayout)
local Storage = require(script.Parent.StorageService)
World.__index = World
local CustomerActor = require(script.Parent.Parent.Customers.CustomerActor)
local Query = require(Shared:WaitForChild("Interaction", 30):WaitForChild("InteractionQuery", 30))
local function rig(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if root and humanoid and humanoid.Health > 0 then
		return character, root, humanoid
	end
end

function World.new(services, config)
	local folder = Scene.World(services.Workspace or workspace)
	local self = setmetatable({
		s = services,
		c = config,
		folder = folder,
		stations = {},
		prompts = {},
		direct = {},
		connections = {},
		avatars = {},
		respawning = {},
		lamps = {},
		closing = false,
		figures = setmetatable({}, { __mode = "k" }),
		saved = {},
		detached = {},
	}, World)
	local ok, result = pcall(self.Bind, self, services, config, folder)
	if not ok then
		self:Shutdown()
		error(result, 0)
	end
	return result
end

function World:Bind(services, config, folder)
	local function get(name, class)
		return Scene.Require(folder, name, class or "BasePart")
	end
	-- The floor survives a play-session copy and follows whole-shop translations/rotation.
	self.origin = get("ShopFloor").CFrame * CFrame.new(0, -0.15, -2)
	self.customerTemplates = CustomerActor.PrepareTemplates(services.ReplicatedStorage)
	self.originalLighting = { ClockTime = services.Lighting.ClockTime }
	for _, item in ipairs(folder:GetDescendants()) do
		local props = {}
		if item:IsA("BasePart") then
			for _, key in ipairs({ "CFrame", "Transparency", "Color", "CanCollide" }) do
				props[key] = item[key]
			end
		elseif item:IsA("Decal") then
			props.Transparency = item.Transparency
		elseif item:IsA("ProximityPrompt") then
			props.Enabled, props.ActionText = item.Enabled, item.ActionText
		elseif item:IsA("Light") or item:IsA("PointLight") or item:IsA("BillboardGui") then
			props.Enabled = item.Enabled
		elseif item:IsA("GuiObject") then
			props.Visible = item.Visible
			if item:IsA("TextLabel") then
				props.Text = item.Text
			elseif item:IsA("ImageLabel") then
				props.Image = item.Image
			end
		end
		self.saved[item] = {
			Props = props,
			Enabled = item:GetAttribute("DPU_Enabled"),
			Label = item:GetAttribute("DPU_Label"),
			Direct = item:GetAttribute("DPU_Direct"),
			Range = item:GetAttribute("DPU_Range"),
		}
	end
	-- Stale actors copied from Play are not live orders. Keep them for teardown restoration.
	for _, item in ipairs(folder:GetChildren()) do
		if
			item:IsA("Model")
			and (item.Name:match("^Customer_") or table.find({ "Visitor", "Inspection", "Shadow" }, item.Name))
		then
			self.detached[item] = item.Parent
			item.Parent = nil
		end
	end
	for name in pairs(ShopLayout.Access) do
		if name ~= "Answer" and name ~= "Fax" and name ~= "Phone" then
			if name:match("^Secret_") or name == "Tool_BrassKey" then
				local item = folder:FindFirstChild(name)
				self.stations[name] = item and item:IsA("BasePart") and item or nil
			elseif name:match("^Part_") then
				local item = Scene.Station(folder, name)
				assert(
					item and item:IsA("BasePart"),
					"[DPU] Missing stock pickup for " .. name .. " in DPU_Prototype.Storage"
				)
				self.stations[name], self.direct[name] = item, item
				item:SetAttribute("DPU_Direct", name)
				item:SetAttribute("DPU_Range", 5)
			else
				self.stations[name] = get(name)
			end
		end
	end
	self.storage = Storage.new(services, folder)
	local television = Scene.Television(services.Workspace or workspace)
	if television then
		self.direct.CRT = television
		television:SetAttribute("DPU_Direct", "CRT")
		television:SetAttribute("DPU_Range", 8)
	end
	self.telephone = Scene.Require(folder, "Fax", "Model")
	self.stations.Fax, self.direct.Fax = self.telephone, self.telephone
	self.stations.Phone, self.stations.Answer = self.telephone, self.telephone
	self.receiver = self.telephone:FindFirstChild("Phone")
	assert(
		self.receiver and (self.receiver:IsA("BasePart") or self.receiver:IsA("Model")),
		"[DPU] Missing authored DPU_Prototype.Fax.Phone handset (BasePart or Model)"
	)
	self.telephone:SetAttribute("DPU_Direct", "Fax")
	self.telephone:SetAttribute("DPU_Range", 8)
	-- Legacy standalone props may be deleted; do not leave their copied input active.
	for _, name in ipairs({ "DeskPhoneBase", "Receiver", "Phone" }) do
		local old = folder:FindFirstChild(name)
		if old then
			old:SetAttribute("DPU_Direct", nil)
			old:SetAttribute("DPU_Enabled", false)
			for _, descendant in ipairs(old:GetDescendants()) do
				if descendant:IsA("ProximityPrompt") then
					descendant.Enabled = false
				end
			end
		end
	end
	self.stations.StaffDoor, self.stations.Timeclock, self.stations.Shelter =
		get("StaffDoor"), get("Timeclock"), get("Shelter")
	for name, object in pairs(self.stations) do
		local prompt = object:FindFirstChild("Interact")
		if object == self.telephone then
			-- One model has three logical actions; only central world input binds it.
			if prompt and prompt:IsA("ProximityPrompt") then
				prompt.Enabled = false
			end
		elseif prompt and prompt:IsA("ProximityPrompt") then
			self.prompts[name] = prompt
			prompt.Enabled = false
			table.insert(
				self.connections,
				prompt.Triggered:Connect(function(player)
					if not self.closing and self.interact then
						self.interact(player, name)
					end
				end)
			)
		elseif object:GetAttribute("DPU_Direct") then
			self.direct[name] = object
		end
	end
	self.direct.TimeclockStamp = get("TimeclockStamp")
	for _, item in pairs(self.direct) do
		item:SetAttribute("DPU_Enabled", false)
	end
	self.doorClosed = folder:GetAttribute("StaffDoorClosed") or self.origin * CFrame.new(22, 3.5, 5)
	self.doorOpened = folder:GetAttribute("StaffDoorOpened")
		or self.origin * CFrame.new(22, 3.5, 1) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.new(0, 0, 4)
	self.benchLight = Scene.Require(self.stations.DeskLamp, "WorkLight", "PointLight")
	local building = folder:FindFirstChild("Building")
	local lighting = building and building:FindFirstChild("Lighting")
	for _, item in ipairs(folder:GetDescendants()) do
		if
			(item:IsA("Light") or item:IsA("PointLight"))
			and (item.Parent.Name == "CeilingLight" or lighting and item:IsDescendantOf(lighting))
		then
			table.insert(self.lamps, item)
		end
	end
	local board = Scene.Require(get("EmployeeBoard"), "EmployeeStatus", "SurfaceGui")
	self.employeeBoardSlots = {}
	for index = 1, 4 do
		table.insert(self.employeeBoardSlots, {
			Portrait = Scene.Require(board, "Portrait" .. index, "ImageLabel"),
			Text = Scene.Require(board, "Employee" .. index, "TextLabel"),
		})
	end
	self.voteMarkers = {}
	for _, choice in ipairs({ "REPORT", "HIDE", "INVESTIGATE" }) do
		local marker = get("Vote" .. choice)
		table.insert(self.voteMarkers, { Part = marker, Label = Scene.Require(marker, "Sign", "BillboardGui") })
	end
	local template = RepairTemplates.Get(services.ReplicatedStorage)
	self.devices = Devices.new(services, folder, template)
	for _, name in ipairs({ "RepairPhone", "RepairPhone2", "CounterPhone_Bench", "CounterPhone_Bench2" }) do
		self.devices:Create(name, name == "RepairPhone" or name == "RepairPhone2")
	end
	local function parts(model)
		local result = {}
		for _, item in ipairs(model:GetDescendants()) do
			if item:IsA("BasePart") then
				local source = template:FindFirstChild(item.Name, true)
				-- Saved runtime copies may have been hidden when Play was copied.
				result[item] = source and source:IsA("BasePart") and source.Transparency or 0
			end
		end
		return result
	end
	self.repairPhone, self.replacement = get("RepairPhone", "Model"), get("ReplacementTray")
	self.phoneParts = parts(self.repairPhone)
	self.repairLanes = {}
	for _, id in ipairs(Stations.Ids) do
		local second = id == "Bench2"
		local phone = second and get("RepairPhone2", "Model") or self.repairPhone
		self.repairLanes[id] = {
			phone = phone,
			parts = parts(phone),
			tray = second and get("ReplacementTray2") or self.replacement,
			offset = second and 9 or 0,
			counterParts = parts(get("CounterPhone_" .. id, "Model")),
		}
		Scene.Require(self.stations[id], "RepairFocus", "Attachment")
		Scene.Require(self.stations[id], "RepairCamera", "Attachment")
	end
	self.workshop = Workshop.new(folder, self.origin, self.repairPhone)
	self.workshop:AddSeat("Bench2")
	self.spawn = get("StaffSpawn", "SpawnLocation")
	self.spectate = get("ObservationDeck").CFrame * CFrame.new(0, 2, 0)
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
	if not root or not station or not station:IsDescendantOf(self.folder) then
		return false
	end
	if name == "Fax" or name == "Phone" or name == "Answer" then
		if not station:IsDescendantOf(self.s.Workspace or workspace) then
			return false
		end
		local head = player.Character:FindFirstChild("Head") or root
		for _, part in ipairs(station:GetDescendants()) do
			if
				part:IsA("BasePart")
				and part.CanQuery
				and Query.Distance(part, root.Position) <= 8
				and Query.Visible(
					self.s.Workspace or workspace,
					self.s.CollectionService,
					player.Character,
					head,
					part,
					station
				)
			then
				return true
			end
		end
		return false
	end
	if name:match("^Part_") and self.storage and station.Parent == self.storage.model then
		local box = Scene.StockBox(station)
		local head = player.Character:FindFirstChild("Head") or root
		return box ~= nil
			and box:GetAttribute("DPU_ContainerOpen") == true
			and box:GetAttribute("DPU_ContainerBusy") ~= true
			and station.CanQuery
			and Query.Distance(station, root.Position) <= 5
			and Query.Visible(self.s.Workspace or workspace, self.s.CollectionService, player.Character, head, station)
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
	if station.CanQuery == false or Query.Distance(station, root.Position) > distance then
		return false
	end
	local head = player.Character:FindFirstChild("Head") or root
	return Query.Visible(self.s.Workspace or workspace, self.s.CollectionService, player.Character, head, station)
end

function World:Reset(player, alive)
	if self.closing or player.Parent ~= self.s.Players then
		return
	end
	local character, root, humanoid = rig(player)
	if not character then
		if not self.respawning[player] then
			local pending = {}
			self.respawning[player] = pending
			task.spawn(function()
				if self.closing or player.Parent ~= self.s.Players or self.respawning[player] ~= pending then
					return
				end
				local ok, reason = pcall(function()
					player:LoadCharacterAsync()
				end)
				if self.respawning[player] == pending then
					self.respawning[player] = nil
				end
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
	self.respawning[player] = nil
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

function World:ChooseAppearance()
	return self.customerTemplates[math.random(1, #self.customerTemplates)]:GetAttribute("DPU_AppearanceId")
end
function World:CustomerName(appearanceId, name)
	for _, template in ipairs(self.customerTemplates) do
		if template:GetAttribute("DPU_AppearanceId") == appearanceId then
			return CustomerActor.CustomerName(template, name)
		end
	end
	return name
end
function World:Figure(name, position, _, appearanceId, customerName)
	local actor = CustomerActor.new(self.s, self.folder, position, {
		AppearanceId = appearanceId or self:ChooseAppearance(),
		CustomerName = customerName,
		CustomerRotation = Vector3.new(90, 180, 0),
	})
	actor.model.Name = customerName or name
	self.figures[actor.model] = actor
	return actor.model, actor
end
function World:RemoveFigure(model)
	local actor = self.figures[model]
	if actor then
		self.figures[model] = nil
		actor:Destroy()
	end
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
	for _, id in ipairs(Stations.Ids) do
		self.devices:Update(id == "Bench" and "RepairPhone" or "RepairPhone2", run.stations[id])
	end
	if self.storage then
		self.storage:Update(run)
	end
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
	for player, member in pairs(run.players) do
		visualKey ..= ":" .. tostring(player.UserId) .. ":" .. tostring(member.Alive) .. ":" .. tostring(
			member.Signal or ""
		)
	end
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
	local reportsByUser = {}
	for _, report in ipairs(run.employeeReports or {}) do
		reportsByUser[report.UserId] = report
	end
	local sortedPlayers = {}
	for player in pairs(run.players) do
		table.insert(sortedPlayers, player)
	end
	table.sort(sortedPlayers, function(a, b)
		return a.UserId < b.UserId
	end)
	for index, slot in ipairs(self.employeeBoardSlots) do
		local player = sortedPlayers[index]
		slot.Portrait.Visible, slot.Text.Visible = player ~= nil, player ~= nil
		if player then
			local member, report = run.players[player], reportsByUser[player.UserId]
			local status = not member.Alive and "TRANSFERRED" or report and report.Status or "PROBATIONARY"
			slot.Portrait.Image = "rbxthumb://type=AvatarHeadShot&id=" .. player.UserId .. "&w=150&h=150"
			slot.Text.Text = player.DisplayName
				.. "  /  "
				.. status
				.. (member.Signal and "\n> " .. member.Signal or "")
		end
	end
	local voteVisible = Stations.Voting(run) ~= nil
	for _, marker in ipairs(self.voteMarkers) do
		marker.Part.Transparency = voteVisible and 0.2 or 1
		marker.Label.Enabled = voteVisible
	end
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
	if Policy.Enabled(run) and run.policy then
		local directive = self.stations.Secret_Directive
		local notice = directive and directive:FindFirstChildWhichIsA("TextLabel", true)
		if notice and notice.Text ~= run.policy.Text then
			notice.Text = run.policy.Text
		end
	end
	local blackout = event and event.Kind == "Blackout"
	for _, lamp in ipairs(self.lamps) do
		if lamp.Enabled ~= not blackout then
			lamp.Enabled = not blackout
		end
	end
	local watcherKind = event
			and (event.Kind == "Visitor" or event.Kind == "Inspection" or event.Kind == "Shadow")
			and event.Kind
		or nil
	if watcherKind ~= self.watcherKind then
		if self.watcher then
			self:RemoveFigure(self.watcher)
			self.watcher = nil
		end
		self.watcherKind = watcherKind
		if watcherKind then
			self.watcher = self:Figure(
				watcherKind,
				self.origin * CFrame.new(event.Kind == "Shadow" and -8 or 8, 0, -21),
				watcherKind ~= "Inspection" and Color3.fromRGB(12, 14, 12) or Color3.fromRGB(50, 61, 47)
			)
		end
	end
	local actions = {}
	if run.phase == "Tutorial" or run.phase == "Night" or run.phase == "Closing" then
		actions.StaffDoor, actions.Timeclock = "ToggleDoor", "OpenClock"
		actions.Tools, actions.Tool_BrassKey = "PickupTool", "PickupTool"
		for id in pairs(LoreRecords) do
			if self.stations["Secret_" .. id] then
				actions["Secret_" .. id] = "Discover"
			end
		end
		actions.Radio, actions.DeskLamp = "TuneRadio", "ToggleLamp"
		if not Policy.BlocksWork(run) then
			actions.Stock = "Restock"
			actions.Fax = "OpenFax"
			actions.CRT = self.direct.CRT and "WatchTV" or nil
		end
		if order and not Policy.BlocksWork(run) then
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
	if run.phase == "Night" or run.phase == "Tutorial" or run.phase == "Closing" then
		if not Policy.BlocksWork(run) then
			actions.Bench = "Sit"
			actions.Bench2 = (run.phase == "Night" or run.phase == "Closing") and "Sit" or nil
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
	local ringing = actions.Phone ~= nil
	self.telephone:SetAttribute("DPU_Direct", ringing and "Phone" or "Fax")
	-- Outside a ringing event the handset resolves to its parent Fax like any other surface.
	self.receiver:SetAttribute("DPU_Direct", ringing and "Answer" or nil)
	self.receiver:SetAttribute("DPU_Enabled", ringing)
	self.receiver:SetAttribute("DPU_Range", 8)
	self.receiver:SetAttribute("DPU_Label", ringing and "Answer forbidden call?" or nil)
	local names = {
		OpenFax = "Use fax phone",
		WatchTV = "Watch TV",
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
			station == "Answer" and "Answer forbidden call?"
				or station:match("^Part_") and ("Take " .. station:sub(6) .. " (" .. tostring(
					run.stock[station:sub(6)] or 0
				) .. ")")
				or names[actions[station]]
				or "Inspect"
		)
	end
end

function World:RenderRepair(lane)
	local view = self.repairLanes[lane.Id]
	local order = lane.order
	local duplicateKey = order and order.Anomaly == "Duplicate" and order.Step == "Return" and order.Id or nil
	if view.duplicateKey ~= duplicateKey then
		if view.duplicate then
			self:RemoveFigure(view.duplicate)
			view.duplicate = nil
		end
		view.duplicateKey = duplicateKey
		if duplicateKey then
			view.duplicate = self:Figure(
				"Customer_Duplicate_" .. lane.Id,
				self.origin * CFrame.new(view.offset + 5, 0, -32),
				nil,
				order.AppearanceId,
				order.Customer
			)
		end
	end
	local present = order
		and (
			order.Step == "Waiting"
			or order.Step == "Return"
			or ((order.Step == "Arriving" or order.Step == "PickupArriving") and not order.PausedAt)
		)
	local suspended = not present
	if suspended and view.customer then
		local customer, actor = view.customer, self.figures[view.customer]
		view.customer, view.orderId = nil, nil
		Devices.ShowCarried(view.carriedDevice, view.lastStep == "Return")
		view.carriedDevice = nil
		actor:MoveTo(self.origin * CFrame.new(view.offset, 0, -43), 3)
		task.delay(3, function()
			self:RemoveFigure(customer)
		end)
	end
	if order and not suspended and view.orderId ~= order.Id then
		if view.customer then
			self:RemoveFigure(view.customer)
		end
		view.orderId = order.Id
		view.customer, view.actor = self:Figure(
			"Customer_" .. lane.Id,
			self.origin * CFrame.new(view.offset, 0, -43),
			nil,
			order.AppearanceId,
			order.Customer
		)
		view.carriedDevice = self.devices:Carry(view.customer)
		view.actor:MoveTo(
			self.origin * CFrame.new(view.offset, 0, -21),
			(order.Step == "Waiting" or order.Step == "Return") and 0 or self.c.ArrivalSeconds
		)
	end
	Devices.ShowCarried(view.carriedDevice, order and order.Step == "Arriving")
	view.lastStep = order and order.Step
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
	local sticker = view.phone:FindFirstChild("ServiceSticker", true)
	if sticker and (sticker:IsA("BasePart") or sticker:IsA("Decal")) then
		sticker.Transparency = visible and order.UpdateRequired and 0 or 1
	end
	view.tray.Transparency = order and order.PartDelivered and 0 or 1
end

function World:Shutdown()
	if self.closing then
		return
	end
	self.closing = true
	if self.storage then
		self.storage:Destroy()
	end
	if self.doorTween then
		self.doorTween:Cancel()
	end
	for player in pairs(self.avatars) do
		self:Remove(player)
	end
	for _, connection in ipairs(self.connections) do
		connection:Disconnect()
	end
	for key, value in pairs(self.originalLighting or {}) do
		self.s.Lighting[key] = value
	end
	if self.workshop then
		self.workshop:Destroy()
	end
	if self.devices then
		self.devices:Destroy()
	end
	for model in pairs(self.figures) do
		self:RemoveFigure(model)
	end
	for item, state in pairs(self.saved) do
		for key, value in pairs(state.Props) do
			item[key] = value
		end
		item:SetAttribute("DPU_Enabled", state.Enabled)
		item:SetAttribute("DPU_Label", state.Label)
		item:SetAttribute("DPU_Direct", state.Direct)
		item:SetAttribute("DPU_Range", state.Range)
	end
	for item, parent in pairs(self.detached) do
		item.Parent = parent
	end
end

return World
