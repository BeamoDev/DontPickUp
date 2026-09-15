local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
assert(
	script:IsDescendantOf(player:WaitForChild("PlayerScripts")),
	"GClient must sync into StarterPlayerScripts"
)
local View = require(script.Parent.PrototypeView)
local RepairPresentation = require(script.Parent.RepairPresentation)
local RepairAssembly = require(script.Parent.RepairAssembly)
local ScarePresentation = require(script.Parent.ScarePresentation)
local PuzzleView = require(script.Parent.PuzzleView)
local StationInteraction = require(script.Parent.StationInteraction)
local state = { Revision = -1, Phase = "Waiting" }
local request, pending, view, presentation, assembly, scares, puzzles, stationInteraction
local stopped = false
local connections = {}

local function apply(snapshot)
	if
		type(snapshot) ~= "table"
		or type(snapshot.Revision) ~= "number"
		or snapshot.Revision < state.Revision
	then
		return
	end
	state = snapshot
	if view then
		view:SetState(state)
		if presentation then
			presentation:Update(state, view.modal.Visible)
		end
		if assembly then
			assembly:Update(state)
		end
		if scares then
			scares:Update(state)
		end
		if puzzles then
			puzzles:Update(state, pending ~= nil, view.modal.Visible)
		end
		if stationInteraction then
			stationInteraction:Update(state, pending ~= nil)
		end
	end
end

local function send(action, choice)
	if pending or stopped then
		return
	end
	if not request then
		if view then
			view:Error("DataNotReady")
		end
		return
	end
	local operation = { Started = os.clock(), RunId = state.RunId }
	local name, payload = action, nil
	if action ~= "ReturnLobby" and action ~= "GetPrototype" then
		name = "PrototypeAction"
		payload = { RunId = state.RunId, Action = action }
		if action == "Vote" then
			payload.OrderId, payload.Choice = state.Order and state.Order.Id, choice
		elseif state.Event and table.find({ "RestorePower", "Silence", "Answer", "Records" }, action) then
			payload.EventId = state.Event.Id
		else
			payload.OrderId = state.Order and state.Order.Id
			if action == "Collect" then
				payload.Part = state.Order and state.Order.Fault
			end
			if action == "Secure" then
				payload.Contact = state.Order and (state.Order.Contacts or 0) + 1
			end
			if action == "PickupTool" then
				payload.Tool = state.RequiredTool
			end
		end
		if type(choice) == "table" then
			for _, key in ipairs({ "FocusId", "WorkId", "OrderId", "Move", "PuzzleRevision" }) do
				payload[key] = choice[key]
			end
		end
	end
	pending = operation
	if view then
		view:SetBusy(true)
	end
	task.spawn(function()
		local ok, response = pcall(function()
			return request:InvokeServer(name, payload)
		end)
		if stopped then
			return
		end
		if ok and type(response) == "table" then
			apply(response.State)
		end
		if pending ~= operation then
			return
		end
		pending = nil
		view:SetBusy(false)
		if operation.RunId and operation.RunId ~= state.RunId then
			return
		end
		if not ok or type(response) ~= "table" then
			view:Error("ConnectionError")
		elseif not response.Ok then
			view:Error(response.Code)
		end
	end)
end

view = View.new(player:WaitForChild("PlayerGui"), {
	act = send,
	lobby = function()
		send("ReturnLobby")
	end,
})
local guiService = game:GetService("GuiService")
local function reducedMotion()
	local data = player:FindFirstChild("PlayerData")
	local settings = data and data:FindFirstChild("Settings")
	local reduced = settings and settings:FindFirstChild("ReducedFlashes")
	return guiService.ReducedMotionEnabled or (reduced ~= nil and reduced.Value == true)
end
puzzles = PuzzleView.new(view.gui, send)
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
	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	presentation:Destroy()
	assembly:Destroy()
	scares:Destroy()
	puzzles:Destroy()
	stationInteraction:Destroy()
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
		if pending and os.clock() - pending.Started >= 12 then
			-- Do not start overlapping invocations while the server is still processing one.
			view:Error("ConnectionError")
			pending.Started = os.clock()
		end
		presentation:Update(state, view.modal.Visible)
		assembly:Update(state)
		scares:Update(state)
		puzzles:Update(state, pending ~= nil, view.modal.Visible)
		stationInteraction:Update(state, pending ~= nil)
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
				local humanoid = other
					and other.Character
					and other.Character:FindFirstChildOfClass("Humanoid")
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
