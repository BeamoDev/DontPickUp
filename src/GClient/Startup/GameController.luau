local Controller = {}
function Controller.Start(entrypoint)
	local joinedAt = os.clock()
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local RunService = game:GetService("RunService")
	local input = game:GetService("UserInputService")
	local guiService = game:GetService("GuiService")
	local collection = game:GetService("CollectionService")
	local player = Players.LocalPlayer
	local function settingsOpen()
		local gui = player:FindFirstChild("PlayerGui")
		return gui ~= nil and gui:GetAttribute("DPU_SettingsOpen") == true
	end
	local networkDeadline = os.clock() + 30
	while ReplicatedStorage:GetAttribute("DPU_GameNetwork") == nil and os.clock() < networkDeadline do
		task.wait()
	end
	local networkName = ReplicatedStorage:GetAttribute("DPU_GameNetwork")
	local net = networkName and ReplicatedStorage:WaitForChild(networkName, 10)
	if not net then
		return
	end
	-- Wait for the server's explicit mode before creating any HUD or camera owner.
	local modeDeadline = os.clock() + 10
	while net:GetAttribute("PrototypeEnabled") == nil and os.clock() < modeDeadline do
		task.wait()
	end
	require(script.Parent.Parent.Interface.SettingsController).Start(entrypoint, net)
	if net:GetAttribute("PrototypeEnabled") == true then
		require(script.Parent.Parent.Session.SessionController).Start(entrypoint, net)
		return
	elseif net:GetAttribute("PrototypeEnabled") ~= false then
		warn("[DPU] Game startup mode missing; sync GServer and GClient together.")
		return
	end
	local DialogueController = require(script.Parent.Parent.Interface.DialogueDemoController)
	local dialogue = DialogueController.new({
		player = player,
		storage = ReplicatedStorage,
		render = RunService,
		tweens = game:GetService("TweenService"),
		guiService = guiService,
		joinedAt = joinedAt,
	})
	local dialogueDestroying
	dialogueDestroying = entrypoint.Destroying:Connect(function()
		dialogueDestroying:Disconnect()
		dialogue:Destroy()
	end)
	local remote = net:WaitForChild("Request", 10)
	if not remote then
		return
	end
	local Shared = ReplicatedStorage:WaitForChild("GShared", 30)
	assert(Shared, "Sync src/GShared to ReplicatedStorage.GShared")
	local Config = require(Shared:WaitForChild("Interaction", 30):WaitForChild("ContainerConfig", 30))
	local InteractionController = require(script.Parent.Parent.Interaction.InteractionController)
	local Tags = require(Shared:WaitForChild("Interaction", 30):WaitForChild("InteractionTags", 30))
	local TelephoneConfig = require(script.Parent.Parent.Effects.TelephoneConfig)
	local TelephoneController = require(script.Parent.Parent.Effects.PhysicalTelephoneController)
	local FirstPersonCamera = require(script.Parent.Parent.Camera.CameraController)
	local InspectionCamera = require(script.Parent.Parent.Camera.InspectionCamera)
	local ThrowController = require(script.Parent.Parent.Interaction.CarryController)
	local ThrowConfig = require(Shared:WaitForChild("Interaction", 30):WaitForChild("ThrowConfig", 30))
	local ContainerViewConfig = require(script.Parent.Parent.Camera.ContainerViewConfig)
	local TVConfig = require(script.Parent.Parent.Camera.TelevisionViewConfig)
	local playerGui = player:WaitForChild("PlayerGui")
	local Orders = require(script.Parent.Parent.Interface.OrderController)
	local orderChanged = net:WaitForChild("OrderChanged", 10)
	local orders = orderChanged
		and Orders.new({
			playerGui = playerGui,
			remote = remote,
			changed = orderChanged,
			dialogue = dialogue,
		})
	local gui = Instance.new("ScreenGui")
	gui.Name, gui.ResetOnSpawn, gui.Parent = "DPU_GameInteractions", false, playerGui
	local PhoneRepair = require(script.Parent.Parent.Repair.PhoneRepairController)
	local returningCamera
	local function needsPointer()
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local camera = workspace.CurrentCamera
		return not humanoid
			or humanoid.Health <= 0
			or humanoid.Sit
			or playerGui:GetAttribute("DPU_ModalOpen") == true
			or playerGui:GetAttribute("DPU_SettingsOpen") == true
			or (camera ~= nil and camera.CameraType == Enum.CameraType.Scriptable and camera ~= returningCamera)
	end
	local function reduced()
		local data = player:FindFirstChild("PlayerData")
		local settings = data and data:FindFirstChild("Settings")
		local flashes = settings and settings:FindFirstChild("ReducedFlashes")
		return guiService.ReducedMotionEnabled or (flashes ~= nil and flashes.Value == true)
	end
	local cursor = FirstPersonCamera.new(gui, player, input, {
		render = RunService,
		menuOpen = function()
			return guiService.MenuIsOpen or settingsOpen()
		end,
		needsPointer = needsPointer,
	})
	local function returning(active, camera)
		returningCamera = active and camera or nil
		if active then
			cursor:Relock()
		else
			cursor:Step()
		end
	end
	local warned = false
	local function highlightTemplate()
		local assets = ReplicatedStorage:FindFirstChild("Assets")
		local template = (assets and assets:FindFirstChild("SelectionHighlight"))
			or ReplicatedStorage:FindFirstChild("SelectionHighlight")
		if (not template or not template:IsA("Highlight")) and not warned then
			warned = true
			warn("[DPU][Interactions] Put your SelectionHighlight in ReplicatedStorage.Assets")
		end
		return template
	end
	local Selection = require(script.Parent.Parent.Interaction.SelectionHighlight)
	local selection = Selection.new(workspace, highlightTemplate, game:GetService("TweenService"))
	local close = Instance.new("TextButton")
	close.Name, close.Text = "CloseInspection", "CLOSE [Q / B]"
	close.Size, close.Position, close.AnchorPoint =
		UDim2.fromOffset(220, 44), UDim2.new(0.5, 0, 1, -28), Vector2.new(0.5, 1)
	close.BackgroundColor3, close.BackgroundTransparency = Color3.new(0, 0, 0), 0.5
	close.TextColor3, close.TextSize, close.Font = Color3.fromRGB(235, 230, 214), 16, Enum.Font.Code
	close.BorderSizePixel, close.Selectable, close.Visible, close.Parent = 0, false, false, gui
	-- Raw input positions and GUI hit tests both use screen pixels.
	local function uiBlocked(position)
		local camera = workspace.CurrentCamera
		position = position or (camera and camera.ViewportSize / 2)
		if not position then
			return true
		end
		for _, object in ipairs(playerGui:GetGuiObjectsAtPosition(position.X, position.Y)) do
			if object.Visible and (object.Active or object:IsA("GuiButton") or object:IsA("TextBox")) then
				return true
			end
		end
		return false
	end
	local callChanged = Instance.new("BindableEvent")
	callChanged.Name, callChanged.Parent = "TelephoneCallChanged", gui
	local repairGui = Instance.new("ScreenGui")
	repairGui.Name, repairGui.IgnoreGuiInset, repairGui.ResetOnSpawn, repairGui.Parent =
		"DPU_PhoneRepair", true, false, playerGui
	local repair = PhoneRepair.new({
		gui = repairGui,
		player = player,
		input = input,
		workspace = workspace,
		render = RunService,
		tweens = game:GetService("TweenService"),
		reduced = reduced,
		returning = returning,
		collection = collection,
		selection = selection,
		remote = remote,
		move = net:WaitForChild("RepairDrag", 10),
		uiBlocked = uiBlocked,
		blocked = function()
			return guiService.MenuIsOpen or settingsOpen() or playerGui:GetAttribute("DPU_ModalOpen") == true
		end,
		active = function(active)
			close.Text, close.Visible = "CLOSE REPAIR [Q / B]", active
		end,
	})
	local telephone = TelephoneController.new({
		returning = returning,
		callChanged = function(state)
			callChanged:Fire(state)
		end,
		collection = collection,
		player = player,
		input = input,
		workspace = workspace,
		config = TelephoneConfig,
		tweens = game:GetService("TweenService"),
		render = RunService,
		reduced = reduced,
		menuOpen = function()
			return guiService.MenuIsOpen or settingsOpen()
		end,
		modalOpen = function()
			return playerGui:GetAttribute("DPU_ModalOpen") == true
		end,
		template = highlightTemplate,
		selection = selection,
		uiBlocked = uiBlocked,
		active = function(active)
			close.Text = "CLOSE PHONE [Q / B]"
			close.Visible = active
		end,
	})
	local interaction
	local carryHint = Instance.new("TextLabel")
	carryHint.Name, carryHint.AnchorPoint = "CarryHint", Vector2.new(0.5, 1)
	carryHint.Size, carryHint.Position = UDim2.fromOffset(380, 26), UDim2.new(0.5, 0, 1, -80)
	carryHint.BackgroundTransparency, carryHint.TextSize, carryHint.Font = 1, 14, Enum.Font.Code
	carryHint.TextColor3, carryHint.Visible, carryHint.Parent = Color3.fromRGB(235, 230, 214), false, gui
	local throwing = ThrowController.new({
		aim = net:WaitForChild("ThrowAim", 10),
		player = player,
		input = input,
		workspace = workspace,
		collection = collection,
		remote = remote,
		config = ThrowConfig,
		render = RunService,
		locked = function()
			return cursor:IsLocked()
		end,
		blocked = function()
			return guiService.MenuIsOpen or settingsOpen() or needsPointer()
		end,
		meter = function(active, label)
			if not carryHint.Parent then
				return
			end
			carryHint.Visible, carryHint.Text = active, label or ""
		end,
	})
	local function createInspection(kind, config, label)
		return InspectionCamera.new({
			returning = returning,
			valid = function(model)
				return Tags.Kind(collection, model) == kind
			end,
			player = player,
			input = input,
			workspace = workspace,
			config = config,
			tweens = game:GetService("TweenService"),
			render = RunService,
			reduced = reduced,
			blocked = function()
				return guiService.MenuIsOpen
					or settingsOpen()
					or playerGui:GetAttribute("DPU_ModalOpen") == true
					or playerGui:GetAttribute("DPU_SettingsOpen") == true
			end,
			active = function(active)
				close.Text, close.Visible = label, active
				if not active and interaction then
					interaction:Cancel()
				end
			end,
		})
	end
	local inspection = createInspection("Container", ContainerViewConfig, "CLOSE VIEW [Q / B]")
	local television = createInspection("tv", TVConfig, "STOP WATCHING [Q / B]")
	interaction = InteractionController.new({
		orders = orders,
		repair = repair,
		television = television,
		throw = throwing,
		collection = collection,
		player = player,
		input = input,
		workspace = workspace,
		remote = remote,
		config = Config,
		telephone = telephone,
		inspection = inspection,
		locked = function()
			return cursor:IsLocked()
		end,
		blocked = function()
			return guiService.MenuIsOpen
				or settingsOpen()
				or playerGui:GetAttribute("DPU_ModalOpen") == true
				or (needsPointer() and not inspection.saved)
		end,
		hover = function(active)
			cursor:SetHover(active, reduced())
		end,
		template = highlightTemplate,
		selection = selection,
		uiBlocked = uiBlocked,
	})
	local closeConnection = close.Activated:Connect(function()
		if repair:Busy() or inspection.saved or television.saved then
			interaction:CloseView()
		else
			telephone:Close()
		end
	end)
	local stopped = false
	local hoverBinding = "DPU_InteractionHover"
	RunService:BindToRenderStep(hoverBinding, Enum.RenderPriority.Camera.Value + 2, function(dt)
		throwing:Update(dt)
		if repair:Busy() then
			repair:Update(dt)
			return
		end
		telephone:Update() -- Also completes receiver return after the camera closes.
		if not telephone.saved then
			interaction:Update()
		end
	end)
	local destroying
	destroying = entrypoint.Destroying:Connect(function()
		if stopped then
			return
		end
		stopped = true
		RunService:UnbindFromRenderStep(hoverBinding)
		destroying:Disconnect()
		interaction:Destroy()
		if orders then
			orders:Destroy()
		end
		inspection:Destroy()
		television:Destroy()
		closeConnection:Disconnect()
		telephone:Destroy()
		repair:Destroy()
		repairGui:Destroy()
		selection:Destroy()
		cursor:Destroy()
		gui:Destroy()
	end)
end
return Controller
