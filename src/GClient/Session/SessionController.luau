-- Active shift client; started explicitly after the server selects the mode.
local Controller = {}
function Controller.Start(entrypoint, network)
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local player = Players.LocalPlayer
	assert(script:IsDescendantOf(player:WaitForChild("PlayerScripts")), "GClient must sync into StarterPlayerScripts")
	local Shared = ReplicatedStorage:WaitForChild("GShared", 30)
	assert(Shared, "Sync src/GShared to ReplicatedStorage.GShared in the Game place")
	local Requests = require(script.Parent.SessionRequests)
	local PickupTelephone = require(script.Parent.Parent.Effects.TelephoneController)
	local Television = require(script.Parent.Parent.Effects.TelevisionController)
	local InspectionView = require(script.Parent.Parent.Interface.InspectionView)
	local WorldInteraction = require(script.Parent.Parent.Interaction.WorldInteractionController)
	local FirstPersonCamera = require(script.Parent.Parent.Camera.CameraController)
	local View = require(script.Parent.Parent.Interface.HUDController)
	local ShiftPanels = require(script.Parent.Parent.Interface.ShiftPanelController)
	local SubtitleView = require(script.Parent.Parent.Interface.DialogueController)
	local RepairPresentation = require(script.Parent.Parent.Repair.RepairPresentation)
	local RepairAssembly = require(script.Parent.Parent.Repair.RepairAssembly)
	local ScarePresentation = require(script.Parent.Parent.Effects.HorrorController)
	local PuzzleView = require(script.Parent.Parent.Repair.PuzzleView)
	local StationInteraction = require(script.Parent.Parent.Interaction.StationInteractionController)
	local state = { Revision = -1, Phase = "Waiting" }
	local request, pending, view, presentation, assembly, scares, puzzles, stationInteraction
	local subtitles, inspection, worldInteraction, fax, television
	local refreshInteractions
	local stopped = false
	local connections = {}
	local playerGui = player:WaitForChild("PlayerGui")
	local function settingsOpen()
		return playerGui:GetAttribute("DPU_SettingsOpen") == true
	end
	assert(playerGui:WaitForChild("DPU_PrototypeHUD", 30), "[DPU] Missing StarterGui.DPU_PrototypeHUD")
	assert(playerGui:WaitForChild("DPU_Cursor", 30), "[DPU] Missing StarterGui.DPU_Cursor")
	local scene = assert(workspace:WaitForChild("Prototype", 30), "[DPU] Missing Workspace.Prototype")
	assert(scene:WaitForChild("DPU_Prototype", 30), "[DPU] Missing Workspace.Prototype.DPU_Prototype")
	assert(scene:WaitForChild("DPU_InteractFocus", 30), "[DPU] Missing saved interaction highlight")
	assert(scene:WaitForChild("DPU_RepairFocus", 30), "[DPU] Missing saved repair highlight")

	local function updateRepairTasks()
		-- Release puzzle visibility before the fitting animation captures the phone.
		if puzzles and puzzles.physical and (not state.Work or not state.Work.Puzzle) then
			puzzles.physical:Clear()
		end
		if assembly then
			assembly:Update(state)
		end
		if puzzles then
			puzzles:Update(
				state,
				pending ~= nil,
				((view:IsModalOpen() or settingsOpen()) or state.Inspection ~= nil or state.Fax ~= nil)
			)
		end
	end

	local function apply(snapshot)
		if type(snapshot) ~= "table" or type(snapshot.Revision) ~= "number" or snapshot.Revision < state.Revision then
			return
		end
		state = snapshot
		if view then
			view:SetState(state)
			if presentation then
				presentation:Update(
					state,
					((view:IsModalOpen() or settingsOpen()) or state.Inspection ~= nil or state.Fax ~= nil)
				)
			end
			updateRepairTasks()
			if scares then
				scares:Update(state)
			end
			if stationInteraction then
				stationInteraction:Update(state, pending ~= nil)
			end
			if refreshInteractions then
				refreshInteractions()
			end
		end
	end

	local requests = Requests.new({
		state = function()
			return state
		end,
		remote = function()
			return request
		end,
		clock = os.clock,
		spawn = task.spawn,
		apply = apply,
		busy = function(value)
			pending = value and true or nil
			if view then
				view:SetBusy(value)
			end
			if fax then
				fax.busy = value
			end
		end,
		error = function(code)
			if view then
				view:Error(code)
				if fax then
					fax:Error(code)
				end
			end
		end,
	})
	local function send(action, choice)
		requests:Send(action, choice)
	end

	view = View.new(player:WaitForChild("PlayerGui"), {
		act = send,
		lobby = function()
			send("ReturnLobby")
		end,
	})
	local guiService = game:GetService("GuiService")
	local firstPerson = FirstPersonCamera.new(view.gui, player, game:GetService("UserInputService"), {
		authored = true,
		render = game:GetService("RunService"),
		menuOpen = function()
			return guiService.MenuIsOpen or settingsOpen()
		end,
		needsPointer = function()
			return (view:IsModalOpen() or settingsOpen())
				or view.signalMenu.Visible
				or state.Seated == true
				or (fax and fax:NeedsPointer())
				or (television and television:NeedsPointer())
				or state.Focus ~= nil
				or state.Inspection ~= nil
				or (state.Work ~= nil and state.Work.Puzzle ~= nil)
				or state.Phase == "Results"
				or state.Alive ~= true
		end,
	})
	inspection = InspectionView.new(view.gui, {
		input = game:GetService("UserInputService"),
		gui = game:GetService("GuiService"),
		clock = function()
			return workspace:GetServerTimeNow()
		end,
		send = send,
	})
	local function uiAction(position)
		for _, object in ipairs(playerGui:GetGuiObjectsAtPosition(position.X, position.Y)) do
			if object == view.night then
				return "Rules"
			elseif object == view.clock then
				return "Team"
			end
		end
	end
	local function shortcut(key)
		if key == "Rules" or key == Enum.KeyCode.Tab or key == Enum.KeyCode.ButtonSelect then
			view:ToggleRules()
			return true
		end
		if key == "Team" or key == Enum.KeyCode.T then
			view:ToggleSignals()
			return true
		end
	end
	worldInteraction = WorldInteraction.new(view.gui, {
		collection = game:GetService("CollectionService"),
		tweens = game:GetService("TweenService"),
		frameDriven = true,
		uiAction = uiAction,
		shortcut = shortcut,
		telephone = function()
			return fax
		end,
		television = function()
			return television
		end,
		menuOpen = function()
			return guiService.MenuIsOpen or settingsOpen()
		end,
		input = game:GetService("UserInputService"),
		workspace = workspace,
		player = player,
		locked = function()
			return firstPerson:IsLocked()
		end,
		send = function(action, payload)
			if payload.Station == "Answer" then
				view.confirmAnswer = state.Event and state.Event.Id
				view:Render()
			else
				send(action, payload)
			end
		end,
	})
	local function reducedMotion()
		local data = player:FindFirstChild("PlayerData")
		local settings = data and data:FindFirstChild("Settings")
		local reduced = settings and settings:FindFirstChild("ReducedFlashes")
		return guiService.ReducedMotionEnabled or (reduced ~= nil and reduced.Value == true)
	end

	local authoredHud = playerGui:FindFirstChild("HUD") or playerGui:WaitForChild("HUD", 10)
	if authoredHud then
		authoredHud:WaitForChild("Frames", 5)
	end
	view.panels = ShiftPanels.new(playerGui, {
		changed = function()
			view:Render()
		end,
		userId = player.UserId,
		assets = game:GetService("AssetService"),
		tweens = game:GetService("TweenService"),
		reduced = reducedMotion,
		act = send,
		understood = function()
			if state.NeedsRules then
				send("ReadRules")
			else
				view.rulesOpen = false
				view:Render()
			end
		end,
	})

	television = Television.new({
		player = player,
		workspace = workspace,
		input = game:GetService("UserInputService"),
		render = game:GetService("RunService"),
		tweens = game:GetService("TweenService"),
		reduced = reducedMotion,
		blocked = function()
			return view:IsModalOpen()
				or settingsOpen()
				or guiService.MenuIsOpen
				or view.signalMenu.Visible
				or pending ~= nil
				or state.Alive ~= true
				or state.NeedsClockIn
				or state.NeedsRules
				or state.Phase == "Results"
				or state.Phase == "Waiting"
				or state.Work ~= nil
				or state.Seated
				or state.Focus ~= nil
				or state.Inspection ~= nil
				or state.Fax ~= nil
				or (state.WorkBlocked == true or state.WorkBlocked == nil and state.Event ~= nil)
		end,
		uiBlocked = function(position)
			return worldInteraction:UIBlocked(position)
		end,
		cursor = function(returning)
			if returning then
				firstPerson.manualFree = false
			end
			firstPerson:Step()
		end,
	})
	fax = PickupTelephone.new({
		player = player,
		input = game:GetService("UserInputService"),
		workspace = workspace,
		collection = game:GetService("CollectionService"),
		render = game:GetService("RunService"),
		tweens = game:GetService("TweenService"),
		selection = worldInteraction.selection,
		send = send,
		reduced = reducedMotion,
		clock = function()
			return workspace:GetServerTimeNow()
		end,
		menuOpen = function()
			return guiService.MenuIsOpen or settingsOpen()
		end,
		uiBlocked = function(position)
			return worldInteraction:UIBlocked(position)
		end,
		cursor = function(returning)
			if returning then
				firstPerson.manualFree = false
			end
			firstPerson:Step()
		end,
	})
	refreshInteractions = function()
		fax:Update(state, (view:IsModalOpen() or settingsOpen()) or guiService.MenuIsOpen, pending ~= nil)
		worldInteraction:Update(
			state,
			(view:IsModalOpen() or settingsOpen()) or guiService.MenuIsOpen or pending ~= nil
		)
	end
	subtitles = SubtitleView.new(view.gui, {
		storage = ReplicatedStorage,
		tweens = game:GetService("TweenService"),
		guiService = guiService,
		player = player,
		enabled = function()
			local data = player:FindFirstChild("PlayerData")
			local settings = data and data:FindFirstChild("Settings")
			local setting = settings and settings:FindFirstChild("Subtitles")
			return not setting or setting.Value
		end,
		clock = function()
			return workspace:GetServerTimeNow()
		end,
		workspace = workspace,
		render = game:GetService("RunService"),
		reduced = reducedMotion,
	})
	puzzles = PuzzleView.new(view.gui, send, {
		storage = ReplicatedStorage,
		input = game:GetService("UserInputService"),
		workspace = workspace,
		player = player,
		render = game:GetService("RunService"),
		tweens = game:GetService("TweenService"),
		cameraReady = function()
			return presentation and presentation.saved ~= nil and not presentation.saved.Returning
		end,
		isBusy = function()
			return pending ~= nil
		end,
		reduced = reducedMotion,
		menuOpen = function()
			return guiService.MenuIsOpen or settingsOpen()
		end,
	})
	stationInteraction = StationInteraction.new({
		workspace = workspace,
		player = player,
		tweens = game:GetService("TweenService"),
		render = game:GetService("RunService"),
		input = game:GetService("UserInputService"),
		reduced = reducedMotion,
		menuOpen = function()
			return guiService.MenuIsOpen or settingsOpen()
		end,
		send = send,
	}, view.gui)
	assembly = RepairAssembly.new({
		workspace = workspace,
		tweens = game:GetService("TweenService"),
		reduced = reducedMotion,
	})
	scares = ScarePresentation.new({
		shake = function()
			return player:GetAttribute("DPU_CameraShake") ~= false
		end,
		workspace = workspace,
		storage = ReplicatedStorage,
		tweens = game:GetService("TweenService"),
		reduced = reducedMotion,
		menuOpen = function()
			return guiService.MenuIsOpen or settingsOpen()
		end,
		volume = function()
			local data = player:FindFirstChild("PlayerData")
			local settings = data and data:FindFirstChild("Settings")
			local volume = settings and settings:FindFirstChild("MasterVolume")
			return volume and volume.Value or 1
		end,
	}, view.gui)
	presentation = RepairPresentation.new({
		stand = function()
			local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.Sit = false
			end
			send("Stand")
		end,
		workspace = workspace,
		player = player,
		tweens = game:GetService("TweenService"),
		render = game:GetService("RunService"),
		input = game:GetService("UserInputService"),
		reduced = reducedMotion,
		menuOpen = function()
			return guiService.MenuIsOpen or settingsOpen()
		end,
	}, view.gui)
	local renderService = game:GetService("RunService")
	renderService:BindToRenderStep("DPU_PrototypeInteractions", Enum.RenderPriority.Camera.Value + 2, function()
		worldInteraction:Step()
		fax:Step()
		firstPerson:SetHover(worldInteraction.hovered, reducedMotion())
	end)
	local function cleanup()
		if stopped then
			return
		end
		stopped = true
		renderService:UnbindFromRenderStep("DPU_PrototypeInteractions")
		requests:Destroy()
		for _, connection in ipairs(connections) do
			connection:Disconnect()
		end

		presentation:Destroy()
		assembly:Destroy()
		scares:Destroy()
		puzzles:Destroy()
		stationInteraction:Destroy()
		subtitles:Destroy()
		inspection:Destroy()
		television:Destroy()
		fax:Destroy()
		worldInteraction:Destroy()
		firstPerson:Destroy()
		local camera = workspace.CurrentCamera
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if camera and camera.CameraType ~= Enum.CameraType.Scriptable and humanoid then
			camera.CameraSubject = humanoid
		end
		view:Destroy()
	end
	table.insert(connections, entrypoint.Destroying:Connect(cleanup))
	task.spawn(function()
		local net = network or ReplicatedStorage:WaitForChild("Remotes", 30)
		local remote = net and net:WaitForChild("Request", 10)
		local changed = net and net:WaitForChild("StateChanged", 10)
		if stopped then
			return
		end
		if net and net:GetAttribute("PrototypeEnabled") == false then
			cleanup()
			return
		end
		if not remote or not changed then
			view:Error("ConnectionError")
			warn("[DPU][Prototype] Game remotes missing. Sync GServer into the Game place.")
			return
		end
		request = remote
		table.insert(
			connections,
			changed.OnClientEvent:Connect(function(snapshot)
				if snapshot.Kind == "Prototype" then
					apply(snapshot)
				end
			end)
		)
		send("GetPrototype")
	end)

	task.spawn(function()
		local renderedSecond, viewport
		while not stopped and script.Parent and view.gui.Parent do
			requests:Tick()
			presentation:Update(
				state,
				((view:IsModalOpen() or settingsOpen()) or state.Inspection ~= nil or state.Fax ~= nil)
			)
			updateRepairTasks()
			scares:Update(state)
			stationInteraction:Update(state, pending ~= nil)
			inspection:Update(
				state,
				(view:IsModalOpen() or settingsOpen()) or guiService.MenuIsOpen or state.Fax ~= nil
			)
			refreshInteractions()
			subtitles:Update(
				state,
				(view:IsModalOpen() or settingsOpen()) or guiService.MenuIsOpen,
				puzzles.physical and puzzles.physical.folder ~= nil
			)
			local camera = workspace.CurrentCamera
			if
				camera
				and camera.CameraType == Enum.CameraType.Custom
				and not presentation:OwnsCamera()
				and state.Outcome == "Died"
				and state.Phase ~= "Results"
			then
				for _, member in ipairs(state.Roster or {}) do
					local other = member.Alive and Players:GetPlayerByUserId(member.UserId)
					local humanoid = other and other.Character and other.Character:FindFirstChildOfClass("Humanoid")
					if humanoid then
						if camera.CameraSubject ~= humanoid then
							camera.CameraSubject = humanoid
						end
						break
					end
				end
			elseif
				camera
				and camera.CameraType == Enum.CameraType.Custom
				and not presentation:OwnsCamera()
				and player.Character
			then
				local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
				if humanoid then
					if camera.CameraSubject ~= humanoid then
						camera.CameraSubject = humanoid
					end
				end
			end
			local second = math.floor(workspace:GetServerTimeNow())
			local size = camera and camera.ViewportSize
			local timed = state.Phase == "Night"
				or state.Phase == "Closing"
				or state.Notice
				or state.Work
				or state.Event
				or state.Vote
				or (state.Order and state.Order.ExpiresAt)
				or (view.errorUntil and os.clock() < view.errorUntil + 1)
			if (timed and second ~= renderedSecond) or size ~= viewport then
				renderedSecond, viewport = second, size
				view:Render()
			end
			task.wait(0.2)
		end
		cleanup()
	end)

	return cleanup
end
return Controller
