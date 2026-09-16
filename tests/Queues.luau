local Harness = require("./Harness")
local Roblox = require("@lune/roblox")
local total = 0
local function check(value, label)
	assert(value, label)
	total += 1
end

local function touchSignal()
	local signal = { Connections = {} }
	function signal:Connect(callback)
		local connection = { Connected = true, Callback = callback }
		function connection:Disconnect()
			self.Connected = false
		end
		table.insert(self.Connections, connection)
		return connection
	end
	function signal:Fire(hit)
		for _, connection in ipairs(self.Connections) do
			if connection.Connected then
				connection.Callback(hit)
			end
		end
	end
	return signal
end

local function fixture()
	local h = Harness.Environment()
	local config = h:load("src/LServer/Core/Config.luau")
	local snapshots, history, moved, exited, ready = {}, {}, {}, {}, {}
	local queues
	local party = h:load("src/LServer/Parties/PartyService.luau").new({
		config = config,
		clock = function()
			return h.time
		end,
		spawn = h.env.task.spawn,
		ready = function(player)
			return ready[player] ~= false
		end,
		present = function(player)
			return player.Parent == h.players
		end,
		friends = function()
			return true
		end,
		changed = function(player)
			if queues then
				queues:PartyChanged(player)
			end
		end,
		canTravel = function()
			return true
		end,
		travel = function(_, _, _, options)
			h.previewMode = options.Mode
			return false, "StudioPreviewComplete"
		end,
	})
	queues = h:load("src/LServer/Queues/WorldQueueService.luau").new({
		config = config,
		party = party,
		clock = function()
			return h.time
		end,
		ready = function(player)
			return ready[player] ~= false
		end,
		present = function(player)
			return player.Parent == h.players
		end,
		alive = function()
			return true
		end,
		inside = function()
			return true
		end,
		far = function()
			return false
		end,
		move = function(player, id, entering, slot)
			table.insert(moved, { player, id, entering, slot })
			return true
		end,
		push = function(player, snapshot)
			snapshots[player] = snapshot
			table.insert(history, { Player = player, State = snapshot })
		end,
		exited = function(player)
			exited[player] = true
		end,
		log = function() end,
	})
	queues:Register("one")
	queues:Register("two")
	return h,
		queues,
		party,
		{
			config = config,
			moved = moved,
			exited = exited,
			ready = ready,
			snapshots = snapshots,
			history = history,
		}
end

do
	local h, queues, party, f = fixture()
	local a, b, c = h:player(1), h:player(2), h:player(3)
	f.ready[a] = false
	check(not queues:Enter(a, "one") and not queues:Get(a).Active, "walk-in waits for data load")
	f.ready[a] = true
	check(queues:Enter(a, "one"), "walk-in claims empty queue")
	check(queues:Get(a).Configuring and queues:Get(a).CanLeave, "setup and exit shown to owner")
	check(not queues:Enter(b, "one"), "second player cannot steal unfinished setup")
	check(not queues:Create(b, 2, "Story"), "remote creation needs physical reservation")
	check(
		not queues:Create(a, 2, "Unknown") and not queues:Create(a, 9, "Story"),
		"server validates mode and capacity"
	)
	check(
		not queues:Create(a, 2, nil) and queues:Get(a).Configuring,
		"missing mode cannot create a partial physical party"
	)
	check(queues:Create(a, 2, "Endless"), "host creates chosen mode")
	check(
		not queues:Get(a).Configuring and queues:Get(a).Active and queues:Board("one").Mode == "Endless",
		"setup closes but exit remains; board has mode"
	)
	check(queues:Enter(b, "one"), "walk-in joins created party")
	check(party:Get(b).Members[2].Ready and queues:Get(b).CanLeave, "physical entry counts as ready")
	check(not queues:Enter(c, "one"), "full physical queue rejects extra player")
	queues:Tick()
	check(party:Get(a).State == "Countdown", "full queue starts final countdown")
	check(queues:Leave(b, false) and f.exited[b], "leave during countdown exits and blocks immediate reentry")
	check(
		party:Get(a).State == "Open" and f.moved[#f.moved][3] == false,
		"leaving cancels countdown and uses ExitPos"
	)
	check(queues:Enter(b, "one"), "member may explicitly reenter after stepping clear")
	queues:Tick()
	h.time += f.config.CountdownSeconds
	party:Tick()
	h:drain()
	check(h.previewMode == "Endless", "selected mode reaches transfer preparation")
	queues:Tick()
	check(
		not queues:Get(a).Active and not queues:Get(b).Active and queues:Board("one").State == "Empty",
		"Studio preview resets whole pad and exits roster"
	)
	check(f.snapshots[a].Message == "StudioPreviewComplete", "Studio success propagated to UI")
end

do
	local h, queues, party, f = fixture()
	local a, b = h:player(1), h:player(2)
	queues:Enter(a, "one")
	h.time += f.config.QueueSetupSeconds + 1
	queues:Tick()
	check(not queues:Get(a).Active and queues:Board("one").State == "Empty", "abandoned setup expires")
	queues:Enter(a, "one")
	queues:Create(a, 4, "Story")
	queues:Enter(b, "one")
	queues:Leave(a, true)
	check(
		party:Get(b).HostUserId == b.UserId and queues:Board("one").Host == b.DisplayName,
		"board follows host migration"
	)
	h.time += f.config.QueueGatherSeconds
	queues:Tick()
	check(party:Get(b).State == "Countdown", "nonfull party starts when gathering timer expires")
	h.time += f.config.CountdownSeconds
	party:Tick()
	check(not queues:Leave(b, false), "leave locked only once transfer preparation begins")
	h:drain()
	queues:Tick()
	check(next(party.parties) == nil, "preview leaves no phantom parties")
	queues:Enter(a, "two")
	queues:Unregister("two")
	check(not queues:Get(a).Active and queues.bays.two == nil, "removed workspace queue releases reservation")
end

do
	local h, queues, party = fixture()
	local a, b = h:player(1), h:player(2)
	queues:Enter(a, "one")
	queues:Create(a, 4, "Story")
	local inside = true
	party.membership[a].Access = "Friends"
	party.d.friends = function()
		inside = false
		return true
	end
	queues.d.inside = function()
		return inside
	end
	check(
		not queues:Enter(b, "one") and not party:Get(b),
		"join rechecks physical entry after yielding lookup"
	)
	queues.d.far = function()
		return true
	end
	queues:Tick()
	check(not queues:Get(a).Active, "walking far from queue releases membership")
end

do
	local h = Harness.Environment()
	local Geometry = h:load("src/LServer/Queues/QueueGeometry.luau")
	local cframe = Roblox.CFrame.new(10, 0, 0) * Roblox.CFrame.Angles(0, math.pi / 2, 0)
	local size = Roblox.Vector3.new(8, 1, 2)
	check(
		Geometry.Contains(cframe, size, cframe:PointToWorldSpace(Roblox.Vector3.new(2, 3, 0))),
		"rotated floor entry includes avatar root above marker"
	)
	check(
		not Geometry.Contains(cframe, size, cframe:PointToWorldSpace(Roblox.Vector3.new(0, 0, 4))),
		"rotated entry rejects outside local bounds"
	)
	check(not Geometry.Contains(cframe, size, Roblox.Vector3.new(10, 40, 0)), "entry rejects another floor")
end

do
	local h = Harness.Environment()
	h.env.Color3 = Roblox.Color3
	h.env.Vector2 = Roblox.Vector2
	h.env.UDim2 = Roblox.UDim2
	local function child(parent, class, name)
		local value = h.instance(class)
		value.Name = name
		value.Parent = parent
		value.Visible = false
		value.ZIndex = 1
		return value
	end
	local gui = child(h.instance("PlayerGui"), "ScreenGui", "Queue")
	gui.Enabled = false
	local panel = child(gui, "Frame", "Party")
	child(panel, "Frame", "Background")
	local scroll = child(panel, "ScrollingFrame", "ScrollingFrame")
	local story = child(scroll, "TextButton", "Story")
	child(story, "UIStroke", "UIStroke")
	local endless = child(scroll, "TextButton", "Endless")
	child(endless, "UIStroke", "UIStroke")
	child(endless, "Frame", "Selected").Size = "authored-size"
	local create = child(panel, "ImageButton", "Create")
	child(create, "TextLabel", "Title")
	local lower = child(panel, "TextButton", "Lower")
	local raise = child(panel, "TextButton", "Raise")
	local leave = child(gui, "TextButton", "Leave")
	child(panel, "TextLabel", "Limit")
	child(panel, "TextLabel", "Expire")
	child(panel, "TextLabel", "Title")
	child(panel, "TextLabel", "PlayerTitle")
	panel.Size, panel.Position = "authored-panel-size", "authored-panel-position"
	local created, left
	local view = h:load("src/LClient/UI/QueueView.luau").new(gui, {
		clock = function()
			return h.time
		end,
		create = function(capacity, mode)
			created = { capacity, mode }
		end,
		leave = function()
			left = true
		end,
	})
	check(view ~= nil and not panel.Visible and not leave.Visible, "queue UI starts hidden")
	view:SetState({
		Active = true,
		Configuring = true,
		CanLeave = true,
		QueueId = "one",
		Mode = "Story",
		Capacity = 4,
		ExpiresAt = h.time + 20,
	})
	check(
		gui.Enabled and panel.Visible and scroll.Visible and panel.Background.Visible and leave.Visible,
		"opening reveals full authored ancestor chain"
	)
	check(
		story.Selected.Visible and not endless.Selected.Visible and story.Selected.Size == "authored-size",
		"missing Story.Selected reuses authored marker"
	)
	check(
		story.UIStroke.Color == Roblox.Color3.fromRGB(4, 255, 0)
			and endless.UIStroke.Color == Roblox.Color3.fromRGB(58, 58, 58),
		"initial selection uses exact requested colors"
	)
	endless.Activated:Fire()
	check(
		endless.Selected.Visible
			and not story.Selected.Visible
			and endless.UIStroke.Color == Roblox.Color3.fromRGB(4, 255, 0)
			and story.UIStroke.Color == Roblox.Color3.fromRGB(58, 58, 58),
		"selecting Endless updates both markers and strokes"
	)
	for _ = 1, 10 do
		lower.Activated:Fire()
	end
	check(panel.Limit.Text == "1", "Lower clamps at one player")
	for _ = 1, 10 do
		raise.Activated:Fire()
	end
	check(panel.Limit.Text == "4", "Raise clamps at four players")
	create.Activated:Fire()
	check(created[1] == 4 and created[2] == "Endless", "Create sends selected mode and capacity")
	check(panel.Expire.Text == "Closes in 20s", "setup expiry text uses server clock")
	view:SetBusy(true)
	story.Activated:Fire()
	check(view.mode == "Endless", "pending request locks draft")
	view:SetBusy(false)
	view:SetState({ Active = true, Configuring = false, CanLeave = true, State = "Open", QueueId = "one" })
	check(not panel.Visible and leave.Visible, "created queue hides setup and keeps exit visible")
	check(gui.DPU_Status.Visible, "queued status remains visible outside setup")
	view:SetBusy("QueueLeave")
	check(
		leave.Text == "Leaving..."
			and not leave.Active
			and create.Title.Text == "Create"
			and not panel.Visible,
		"leave pending label does not say Creating"
	)
	view:SetBusy(false)
	leave.Activated:Fire()
	check(left, "Leave button invokes exit action")
	left = false
	view:SetState({
		Active = true,
		Configuring = false,
		CanLeave = false,
		State = "Preparing",
		QueueId = "one",
	})
	leave.Activated:Fire()
	check(not left and leave.Text == "Preparing...", "committed transfer cannot send leave")
	view:SetState({ Active = false })
	check(not panel.Visible and not leave.Visible, "exit closes setup and leave button")
	view:SetState({ Active = false, Message = "QueueFull" })
	check(
		gui.DPU_Status.Visible and gui.DPU_Status.Text:find("full") and not panel.Visible,
		"entry rejection is visible with setup closed"
	)
	h.time += 6
	view:Render()
	check(not gui.DPU_Status.Visible, "idle feedback expires without opening setup")
	check(
		panel.Size == "authored-panel-size" and panel.Position == "authored-panel-position",
		"authored geometry preserved"
	)
	view:Destroy()
	check(not gui:FindFirstChild("DPU_Status"), "owned status label cleaned up on rebind")
	left = false
	leave.Activated:Fire()
	check(not left, "old UI connections disconnected")
end

do
	local h = Harness.Environment()
	h.env.Vector3, h.env.CFrame = Roblox.Vector3, Roblox.CFrame
	h.env.Color3 = Roblox.Color3
	local workspace = h.instance("Workspace")
	workspace.GetServerTimeNow = function()
		return h.time
	end
	h.env.workspace = workspace
	local function child(parent, class, name)
		local value = h.instance(class)
		value.Name = name
		value.Parent = parent
		return value
	end
	local folder = child(workspace, "Folder", "Queues")
	local function scene(x, legacy)
		local queue = child(folder, "Folder", "Queue")
		child(queue, "Folder", "InQueue")
		local refs = child(queue, "Folder", "Refs")
		for name, z in pairs({ Enter = 0, EnterPos = 10, ExitPos = 0 }) do
			local part = child(refs, "Part", name)
			part.Touched = touchSignal()
			part.CanTouch = false
			part.CFrame = Roblox.CFrame.new(x, 0, z)
			part.Position = part.CFrame.Position
			part.Size = Roblox.Vector3.new(4, 1, 4)
		end
		local ui = child(queue, "Part", "UI")
		local board = child(ui, "BillboardGui", "BillboardGui")
		for _, name in ipairs({
			"Gamemode",
			legacy and "PartyLeader" or "Title",
			"Players",
			legacy and "Time" or "GreenStatus",
		}) do
			child(board, "TextLabel", name)
		end
		child(board, "ImageLabel", legacy and "MapIcon" or "GamemodeIcon").Image = "authored-icon"
		return queue, board
	end
	local one, board = scene(0)
	local two, legacyBoard = scene(100, true)
	local a = h:player(1)
	h.players.GetPlayerFromCharacter = function(_, model)
		for _, player in ipairs(h.players:GetPlayers()) do
			if player.Character == model then
				return player
			end
		end
		return nil
	end
	local character = child(workspace, "Model", "Avatar")
	a.Character = character
	local root = child(character, "Part", "HumanoidRootPart")
	root.Position = Roblox.Vector3.new(0, 3, 0)
	root.Size = Roblox.Vector3.new(2, 2, 1)
	local humanoid = child(character, "Humanoid", "Humanoid")
	humanoid.Health = 100
	humanoid.HipHeight = 2
	character.PivotTo = function(_, cframe)
		root.Position = cframe.Position
	end
	local config = h:load("src/LServer/Core/Config.luau")
	local party = h:load("src/LServer/Parties/PartyService.luau").new({
		config = config,
		clock = function()
			return h.time
		end,
		ready = function()
			return true
		end,
		present = function()
			return true
		end,
		changed = function() end,
		spawn = h.env.task.spawn,
		friends = function()
			return true
		end,
		canTravel = function()
			return true
		end,
	})
	local dataReady = false
	local world = h:load("src/LServer/Queues/QueueWorld.luau").new(
		{ Players = h.players, RunService = {
			IsStudio = function()
				return true
			end,
		} },
		config,
		{
			IsReady = function()
				return dataReady
			end,
		},
		party,
		{ PushQueue = function() end }
	)
	local enter = one.Refs.Enter
	check(enter.CanTouch and #enter.Touched.Connections == 1, "touch detection binds immediately at startup")
	enter.Touched:Fire(root)
	check(not world.queues:Get(a).Active and root.Position.Z == 0, "touch cannot bypass profile readiness")
	dataReady = true
	enter.Touched:Fire(root)
	check(not world.queues:Get(a).Active, "repeated contacts respect failed-admission retry limit")
	h.time += 0.5
	root.Position = Roblox.Vector3.new(50, 3, 0)
	enter.Touched:Fire(root)
	check(not world.queues:Get(a).Active, "touch without server proximity cannot admit a player")
	root.Position = Roblox.Vector3.new(0, 3, 0)
	enter.Touched:Fire(one.UI)
	check(not world.queues:Get(a).Active, "non-character contact cannot create a queue")
	enter.Touched:Fire(root)
	check(
		world.queues:Get(a).Configuring and root.Position.Z == 10,
		"touch moves and admits synchronously without a maintenance tick or scheduler drain"
	)
	check(
		board.Players.Text == "1/4" and one.InQueue:FindFirstChild("DPU_1"),
		"touch immediately updates board and physical roster"
	)
	local entry = world.queues:Get(a).EntryId
	for _ = 1, 10 do
		enter.Touched:Fire(root)
	end
	check(world.queues:Get(a).EntryId == entry, "multiple limb contacts cannot duplicate entry")
	world:Tick()
	h:drain()
	world:Render()
	check(
		one:GetAttribute("DPU_QueueId") ~= two:GetAttribute("DPU_QueueId"),
		"duplicate Queue names receive independent IDs"
	)
	check(
		world.queues:Get(a).Configuring and root.Position.Z == 10,
		"workspace entry moves player to EnterPos and opens setup"
	)
	check(
		board.Enabled
			and board.Title.Text == string.upper(a.DisplayName) .. "'S SHIFT"
			and board.Players.Text == "1/4",
		"authored billboard displays current host and count"
	)
	check(
		board.GreenStatus.Text == "SETUP 20s" and board.Gamemode.Text == "Story",
		"new sign shows setup state and default Story"
	)
	check(
		legacyBoard.Time.Text == "Walk in to create" and legacyBoard.MapIcon.Image == "authored-icon",
		"older pad names remain supported alongside new sign"
	)
	check(one.InQueue:FindFirstChild("DPU_1").Value == a, "InQueue tracks member with owned ObjectValue")
	world.queues:Create(a, 2, "Endless")
	world:Render()
	check(
		board.Gamemode.Text == "Endless" and board.GreenStatus.Text == "STARTS 20s",
		"billboard mode and gathering deadline updated"
	)
	local b = h:player(2)
	local secondCharacter = child(workspace, "Model", "SecondAvatar")
	b.Character = secondCharacter
	local secondRoot = child(secondCharacter, "Part", "HumanoidRootPart")
	secondRoot.Position = Roblox.Vector3.new(0, 3, 0)
	secondRoot.Size = root.Size
	local secondHumanoid = child(secondCharacter, "Humanoid", "Humanoid")
	secondHumanoid.Health, secondHumanoid.HipHeight = 100, 2
	secondCharacter.PivotTo = function(_, cframe)
		secondRoot.Position = cframe.Position
	end
	enter.Touched:Fire(secondRoot)
	check(
		world.queues:Get(b).Active and secondRoot.Position.Z == 13 and board.Players.Text == "2/2",
		"touch joins an existing party and moves to its free slot without polling"
	)
	world.queues:Leave(b, false)
	world.queues:Leave(a, false)
	enter.Touched:Fire(root)
	check(not world.queues:Get(a).Active, "touch at overlapping ExitPos cannot immediately rejoin")
	world:Tick()
	h:drain()
	check(
		root.Position.Z == 0 and not world.queues:Get(a).Active,
		"ExitPos overlap cannot immediately rejoin queue"
	)
	check(
		one.InQueue:FindFirstChild("DPU_1") == nil and board.Players.Text == "0/4",
		"leave clears membership and resets billboard"
	)
	check(
		board.Title.Text == "SHIFT AVAILABLE" and board.GreenStatus.Text == "READY",
		"leaving resets new sign title and status"
	)
	root.Position = Roblox.Vector3.new(50, 3, 0)
	world:Tick()
	h.time += 3
	root.Position = Roblox.Vector3.new(0, 3, 0)
	enter.Touched:Fire(root)
	check(world.queues:Get(a).Active, "stepping outside and back re-enables queue entry")
	humanoid.Health = 0
	world:Tick()
	check(not world.queues:Get(a).Active, "death removes physical reservation")
	enter.Touched:Fire(root)
	check(not world.queues:Get(a).Active, "dead character touches cannot reenter")
	humanoid.Health = 100
	root.Position = Roblox.Vector3.new(50, 3, 0)
	world:Tick()
	root.Position = Roblox.Vector3.new(0, 3, 0)
	world:Tick()
	h:drain()
	check(
		world.queues:Get(a).Active and root.Position.Z == 10,
		"bounds fallback still admits a character when physics sends no touch"
	)
	world.queues:Leave(a, false)
	board:Destroy()
	world:Discover()
	local replacement = child(one.UI, "BillboardGui", "BillboardGui")
	child(replacement, "TextLabel", "Gamemode")
	world:Discover()
	world:Render()
	check(replacement.Gamemode.Text == "Story", "late replacement billboard is rebound")
	one.Parent = nil
	world:Discover()
	check(world.byInstance[one] == nil, "deleted workspace pad unregisters")
	check(not enter.Touched.Connections[1].Connected, "removed pad disconnects touch listener")
	world:Shutdown()
	check(
		not two.Refs.Enter.Touched.Connections[1].Connected,
		"shutdown disconnects remaining touch listeners"
	)
end

do
	local h, queues, party, f = fixture()
	local a, b, c, d = h:player(10), h:player(11), h:player(12), h:player(13)
	queues:Enter(a, "one")
	local oldEntry = queues:Get(a).EntryId
	table.clear(f.history)
	queues:Create(a, 4, "Story")
	check(
		#f.history == 1 and f.history[1].State.Configuring == false,
		"create publishes only completed physical state"
	)
	queues:Enter(b, "one")
	queues:Enter(c, "one")
	queues:Leave(b, false)
	queues:Enter(d, "one")
	check(
		queues.bays.one.Slots[c] == 3 and queues.bays.one.Slots[d] == 2,
		"replacement fills vacant slot without overlapping remaining member"
	)
	check(f.moved[#f.moved][4] == 2, "placement uses allocated slot rather than roster count")
	table.clear(f.history)
	queues:Leave(a, false)
	local own = {}
	for _, item in ipairs(f.history) do
		if item.Player == a then
			table.insert(own, item.State)
		end
	end
	check(#own == 1 and not own[1].Active, "leave publishes one closed state without transient setup")
	queues:Clear(queues.bays.one)
	queues:Enter(a, "one")
	check(queues:Get(a).EntryId ~= oldEntry, "same pad reentry receives new visit identity")
	local result = queues:Request(a, "QueueCreate", { Capacity = 2, Mode = "Endless", EntryId = oldEntry })
	check(
		not result.Ok and not party:Get(a) and queues:Get(a).Configuring,
		"delayed create cannot create party in newer visit"
	)
	result = queues:Request(a, "QueueLeave", { EntryId = oldEntry })
	check(not result.Ok and queues:Get(a).Active, "delayed leave cannot eject a newer visit")
	check(not queues:Request(a, "QueueLeave", {}).Ok, "unscoped physical leave rejected")
	check(queues:Request(a, "QueueLeave", { EntryId = queues:Get(a).EntryId }).Ok, "current visit can leave")
end

do
	local h, queues, party, f = fixture()
	local a, b = h:player(20), h:player(21)
	queues:Enter(a, "one")
	queues:Create(a, 2, "Story")
	local deadline = queues:Get(a).ExpiresAt
	h.time += 15
	queues:Tick()
	check(
		party:Get(a).State == "Countdown" and party:Get(a).CountdownEndsAt == deadline,
		"final countdown is included in twenty-second timer"
	)
	h.time += 5
	party:Tick()
	check(
		party:Get(a).State == "Preparing",
		"departure begins at displayed deadline without extra five seconds"
	)
	h:drain()
	queues:Tick()
	queues:Enter(a, "one")
	queues:Create(a, 2, "Story")
	queues:Enter(b, "one")
	queues:Tick()
	deadline = queues:Get(a).ExpiresAt
	h.time += 2
	queues:Leave(b, false)
	check(queues:Get(a).ExpiresAt == deadline, "member departure never increases displayed time")
	queues:Tick()
	check(party:Get(a).CountdownEndsAt == deadline, "remaining party keeps original departure deadline")
	queues.d.far = function()
		return true
	end
	local moves = #f.moved
	queues:Tick()
	check(not queues:Get(a).Active and #f.moved == moves, "walking away exits without pulling player back")
end

do
	local h = Harness.Environment()
	local active, errors, applied = nil, {}, {}
	local requests = h:load("src/LClient/Networking/QueueRequests.luau").new({
		clock = function()
			return h.time
		end,
		spawn = h.env.task.spawn,
		invoke = function(_, payload)
			return { Ok = false, Code = "QueueChanged", Queue = { EntryId = payload.EntryId } }
		end,
		busy = function(action)
			active = action
		end,
		error = function(code)
			table.insert(errors, code)
		end,
		apply = function(snapshot)
			table.insert(applied, snapshot)
		end,
	})
	check(
		requests:Send("QueueLeave", { EntryId = "old" }) and active == "QueueLeave",
		"request records specific pending operation"
	)
	check(not requests:Send("QueueLeave", { EntryId = "old" }), "double click cannot start duplicate request")
	h.time += 8
	requests:Tick()
	check(
		active == nil and errors[1] == "RequestTimeout",
		"slow response releases busy UI with honest timeout"
	)
	requests:Send("QueueCreate", { EntryId = "new" })
	local oldJob = table.remove(h.jobs, 1)
	oldJob[1](table.unpack(oldJob[2], 1, oldJob[2].n))
	check(
		active == "QueueCreate" and #errors == 1,
		"late old reply cannot clear new busy state or show stale failure"
	)
	check(#applied == 1, "late reply still reaches revision-filtered state handler")
	requests:Observe({ EntryId = "new", Configuring = false })
	check(active == nil, "server push completing create releases busy state before response")
	h:drain()
	check(#errors == 1, "completed operation's delayed reply cannot produce error")
	requests:Send("QueueLeave", { EntryId = "new" })
	requests:Observe({ EntryId = "another", Configuring = true })
	check(active == nil, "new visit clears previous request ownership")
	requests:Destroy()
	h:drain()
	check(#applied == 2, "destroy ignores in-flight callbacks")
end

do
	local h = Harness.Environment()
	h.env.Color3 = Roblox.Color3
	local function child(parent, class, name)
		local object = h.instance(class)
		object.Name, object.Parent = name, parent
		object.Visible = false
		return object
	end
	local queue = h.instance("Folder")
	local board = child(queue, "BillboardGui", "BillboardGui")
	local background = child(board, "Frame", "Background")
	local stroke = child(background, "UIStroke", "UIStroke")
	local title = child(board, "TextLabel", "Title")
	title.Size, title.Position = "original-size", "original-position"
	title.TextScaled, title.TextSize, title.TextWrapped = false, 24, true
	child(board, "TextLabel", "PlayerCount")
	local status = child(board, "TextLabel", "Status")
	status.TextScaled, status.TextSize, status.TextWrapped = false, 18, true
	local icon = child(board, "ImageLabel", "Icon")
	local holder = child(icon, "Frame", "Bar")
	local mode = child(holder, "TextLabel", "Gamemode")
	local iconStroke = child(icon, "UIStroke", "UIStroke")
	iconStroke.Color = Roblox.Color3.fromRGB(58, 58, 58)
	icon.Image = "original-story"
	local view = h:load("src/LServer/Queues/QueueBillboard.luau").new(board)
	local state = { State = "Empty", Host = "-", Mode = "Choose a mode", Count = 0, Capacity = 4 }
	view:Render(queue, state, h.time)
	check(
		board.Enabled and background.Visible and holder.Visible and icon.Visible,
		"new sign reveals authored ancestors including nested icon"
	)
	check(
		title.Text == "SHIFT AVAILABLE" and status.Text == "READY" and mode.Text == "Story",
		"empty sign matches owner design wording"
	)
	check(
		stroke.Color == Roblox.Color3.fromRGB(4, 255, 0) and status.TextColor3 == stroke.Color,
		"ready status and border use matching green"
	)
	state.Host, state.Mode, state.Count, state.Capacity = "Beamo", "Endless", 2, 3
	queue:SetAttribute("EndlessIcon", "endless-image")
	state.State, state.ExpiresAt = "Open", h.time + 19.2
	view:Render(queue, state, h.time)
	check(
		title.Text == "BEAMO'S SHIFT" and board.PlayerCount.Text == "2/3" and icon.Image == "endless-image",
		"party host count capacity and selected icon update together"
	)
	check(status.Text == "STARTS 20s", "open timer rounds up from authoritative deadline")
	check(mode.Visible and holder.Visible and icon.Visible, "nested Icon.Bar.Gamemode is fully revealed")
	check(
		not status.TextScaled and status.TextSize == 18 and status.TextWrapped,
		"Status retains authored text sizing and wrapping"
	)
	check(iconStroke.Color == Roblox.Color3.fromRGB(58, 58, 58), "authored icon stroke remains unchanged")
	state.State = "Countdown"
	state.ExpiresAt = h.time + 4.2
	view:Render(queue, state, h.time)
	check(
		status.Text == "LEAVING 5s" and stroke.Color == Roblox.Color3.fromRGB(255, 195, 65),
		"final countdown uses amber warning"
	)
	view:Render(queue, state, h.time + 10)
	check(status.Text == "LEAVING 0s", "late tick never renders a negative countdown")
	state.State = "Preparing"
	view:Render(queue, state, h.time)
	check(status.Text == "PREPARING", "preparation replaces expired countdown")
	state.State = "Teleporting"
	view:Render(queue, state, h.time)
	check(status.Text == "TELEPORTING", "dispatch has its own status")
	state.Host = "NewLeader"
	view:Render(queue, state, h.time)
	check(
		title.Text == "NEWLEADER'S SHIFT"
			and not title.RichText
			and not title.TextScaled
			and title.TextSize == 24
			and title.TextWrapped,
		"host changes preserve authored title text sizing"
	)
	icon:Destroy()
	icon = child(board, "ImageButton", "Icon")
	holder = child(icon, "Frame", "Bar")
	mode = child(holder, "TextLabel", "Gamemode")
	icon.Image = "replacement-story"
	view:Render(queue, state, h.time)
	check(
		icon.Image == "endless-image",
		"replacement ImageButton receives current mode without board replacement"
	)
	queue:SetAttribute("EndlessIcon", "")
	view:Render(queue, state, h.time)
	check(icon.Image == "replacement-story", "empty override restores replacement's authored image")
	state.State, state.Mode, state.Count = "Empty", "Choose a mode", 0
	view:Render(queue, state, h.time)
	check(
		status.Text == "READY" and mode.Text == "Story" and icon.Image == "replacement-story",
		"reset clears previous mode and departure status"
	)
	check(
		title.Size == "original-size" and title.Position == "original-position",
		"billboard updates preserve authored geometry"
	)
end

print(string.format("PASS: %d world queue, mode selection, and authored UI checks.", total))
