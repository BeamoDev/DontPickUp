local Controller = {}
function Controller.Start(entrypoint)
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local RunService = game:GetService("RunService")
	local player = Players.LocalPlayer
	assert(script:IsDescendantOf(player:WaitForChild("PlayerScripts")), "LClient must sync into StarterPlayerScripts")
	local playerGui = player:WaitForChild("PlayerGui")
	local View = require(script.Parent.Parent.Interface.QueueView)
	local Requests = require(script.Parent.QueueRequests)
	local state = { Active = false, Revision = -1 }
	local view, request, busy = nil, nil, nil
	local changedConnection
	local requests
	local lastWarning
	local stopped = false
	local destroying
	local function cleanup()
		if stopped then
			return
		end
		stopped = true
		if destroying then
			destroying:Disconnect()
		end
		if view then
			view:Destroy()
			view = nil
		end
		if requests then
			requests:Destroy()
		end
		if changedConnection then
			changedConnection:Disconnect()
		end
	end
	destroying = entrypoint.Destroying:Connect(cleanup)

	local function apply(snapshot)
		if type(snapshot) ~= "table" or type(snapshot.Revision) ~= "number" or snapshot.Revision < state.Revision then
			return
		end
		state = snapshot
		if requests then
			requests:Observe(snapshot)
		end
		if view then
			view:SetState(state)
		end
		if RunService:IsStudio() then
			print("[DPU][Queue UI]", state.Active and state.State or "Closed", state.QueueId or "", state.Message or "")
		end
	end

	requests = Requests.new({
		clock = os.clock,
		spawn = task.spawn,
		invoke = function(action, payload)
			return request:InvokeServer(action, payload)
		end,
		apply = apply,
		busy = function(action)
			busy = action
			if view then
				view:SetBusy(action)
			end
		end,
		error = function(code)
			if view then
				view:Error(code)
			end
		end,
	})

	local function send(action, payload)
		if not request then
			if view then
				view:Error("DataNotReady")
			end
			return
		end
		requests:Send(action, payload)
	end

	task.spawn(function()
		local net = ReplicatedStorage:WaitForChild("DontPickUpLobbyNet", 30)
		if stopped then
			return
		end
		if not net then
			warn("[DPU][Queue UI] Lobby server remotes are missing; sync LServer and restart Play.")
			return
		end
		local remote = net:WaitForChild("Request", 10)
		local changed = net:WaitForChild("QueueStateChanged", 10)
		if stopped then
			return
		end
		if not remote or not changed then
			warn("[DPU][Queue UI] Queue remotes are incomplete; sync the updated Core.")
			return
		end
		request = remote
		require(script.Parent.Parent.Interface.SettingsController).Start(entrypoint, net)
		changedConnection = changed.OnClientEvent:Connect(apply)
		send("GetQueueState") -- Subscribe first so opening a queue during startup cannot be missed.
	end)

	-- Rebind after ScreenGui replacement/respawn and support late replication of authored descendants.
	task.spawn(function()
		while not stopped and entrypoint.Parent do
			requests:Tick()
			local gui = playerGui:FindFirstChild("Queue")
			if view and (view.gui ~= gui or not view:IsValid()) then
				view:Destroy()
				view = nil
			end
			if not view and gui and gui:IsA("ScreenGui") then
				local mounted, reason = View.new(gui, {
					create = function(capacity, mode)
						send("QueueCreate", { Capacity = capacity, Mode = mode, EntryId = state.EntryId })
					end,
					leave = function()
						send("QueueLeave", { EntryId = state.EntryId })
					end,
				})
				if mounted then
					view = mounted
					view:SetState(state)
					view:SetBusy(busy)
					lastWarning = nil
					print("[DPU][Queue UI] Bound PlayerGui.Queue")
				elseif reason ~= lastWarning then
					warn("[DPU][Queue UI] " .. reason)
					lastWarning = reason
				end
			end
			if view then
				view:Render()
			end
			task.wait(0.25)
		end
		cleanup()
	end)

	return cleanup
end
return Controller
