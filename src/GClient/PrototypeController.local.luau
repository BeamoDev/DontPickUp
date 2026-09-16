local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
assert(script:IsDescendantOf(player:WaitForChild("PlayerScripts")), "GClient must sync into StarterPlayerScripts")
local Requests = require(script.Parent.Networking.Requests)
local InspectionView = require(script.Parent.UI.InspectionView)
local WorldInteraction = require(script.Parent.Interactions.WorldInteraction)
local FirstPersonCamera = require(script.Parent.Interactions.FirstPersonCamera)
local View = require(script.Parent.UI.PrototypeView)
local SubtitleView = require(script.Parent.Dialogue.SubtitleView)
local RepairPresentation = require(script.Parent.Repair.RepairPresentation)
local RepairAssembly = require(script.Parent.Repair.RepairAssembly)
local ScarePresentation = require(script.Parent.Effects.ScarePresentation)
local PuzzleView = require(script.Parent.Repair.PuzzleView)
local StationInteraction = require(script.Parent.Interactions.StationInteraction)
local state = { Revision = -1, Phase = "Waiting" }
local request, pending, view, presentation, assembly, scares, puzzles, stationInteraction
local subtitles, inspection, worldInteraction
local stopped = false
local connections = {}

local function updateRepairTasks()
	-- Release puzzle visibility before the fitting animation captures the phone.
	if puzzles and puzzles.physical and (not state.Work or not state.Work.Puzzle) then
		puzzles.physical:Clear()
	end
	if assembly then
		assembly:Update(state)
	end
	if puzzles then
		puzzles:Update(state, pending ~= nil, (view.modal.Visible or state.Inspection ~= nil))
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
			presentation:Update(state, (view.modal.Visible or state.Inspection ~= nil))
		end
		updateRepairTasks()
		if scares then
			scares:Update(state)
		end
		if stationInteraction then
			stationInteraction:Update(state, pending ~= nil)
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
	end,
	error = function(code)
		if view then
			view:Error(code)
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
local firstPerson = FirstPersonCamera.new(view.gui, player, game:GetService("UserInputService"))
inspection = InspectionView.new(view.gui, {
	input = game:GetService("UserInputService"),
	gui = game:GetService("GuiService"),
	clock = function()
		return workspace:GetServerTimeNow()
	end,
	send = send,
})
worldInteraction = WorldInteraction.new(view.gui, {
	input = game:GetService("UserInputService"),
	workspace = workspace,
	player = player,
	send = function(action, payload)
		if payload.Station == "Answer" then
			view.confirmAnswer = state.Event and state.Event.Id
			view:Render()
		else
			send(action, payload)
		end
	end,
})
local guiService = game:GetService("GuiService")
local function reducedMotion()
	local data = player:FindFirstChild("PlayerData")
	local settings = data and data:FindFirstChild("Settings")
	local reduced = settings and settings:FindFirstChild("ReducedFlashes")
	return guiService.ReducedMotionEnabled or (reduced ~= nil and reduced.Value == true)
end
subtitles = SubtitleView.new(view.gui, {
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
		return guiService.MenuIsOpen
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
		return guiService.MenuIsOpen
	end,
	send = send,
}, view.gui)
assembly = RepairAssembly.new({
	workspace = workspace,
	tweens = game:GetService("TweenService"),
	reduced = reducedMotion,
})
scares = ScarePresentation.new({
	workspace = workspace,
	storage = ReplicatedStorage,
	tweens = game:GetService("TweenService"),
	reduced = reducedMotion,
	menuOpen = function()
		return guiService.MenuIsOpen
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
		return guiService.MenuIsOpen
	end,
}, view.gui)
local function cleanup()
	if stopped then
		return
	end
	stopped = true
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
	worldInteraction:Destroy()
	firstPerson:Destroy()
	local camera = workspace.CurrentCamera
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if camera and camera.CameraType ~= Enum.CameraType.Scriptable and humanoid then
		camera.CameraSubject = humanoid
	end
	view:Destroy()
end
table.insert(connections, script.Destroying:Connect(cleanup))
task.spawn(function()
	local net = ReplicatedStorage:WaitForChild("DontPickUpGameNet", 30)
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
		presentation:Update(state, (view.modal.Visible or state.Inspection ~= nil))
		updateRepairTasks()
		scares:Update(state)
		stationInteraction:Update(state, pending ~= nil)
		inspection:Update(state, view.modal.Visible or guiService.MenuIsOpen)
		worldInteraction:Update(state, view.modal.Visible or guiService.MenuIsOpen or pending ~= nil)
		subtitles:Update(
			state,
			view.modal.Visible or guiService.MenuIsOpen or state.Event ~= nil,
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
