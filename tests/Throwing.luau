local Harness = require("./Harness")
local Fixture = require("./TagFixture")
local Roblox = require("@lune/roblox")
local h, total = Harness.Environment(), 0
local function check(value, label)
	assert(value, label)
	total += 1
end
for _, name in ipairs({
	"Vector3",
	"Vector2",
	"CFrame",
	"Color3",
	"ColorSequence",
	"NumberSequence",
	"NumberSequenceKeypoint",
	"NumberRange",
}) do
	h.env[name] = Roblox[name]
end
local preferred = { KeyboardAndMouse = "Mouse", Touch = "Touch", Gamepad = "Gamepad" }
h.env.Enum = setmetatable({ PreferredInput = preferred }, {
	__index = function(_, key)
		return Roblox.Enum[key]
	end,
})
h.env.RaycastParams = {
	new = function()
		return {}
	end,
}
local delays, effects = {}, {}
h.env.task.delay = function(seconds, callback)
	table.insert(delays, { at = h.time + seconds, fn = callback })
end
h.env.Instance.new = function(class)
	local item = h.instance(class)
	if class == "Part" then
		item.SetNetworkOwner = function(_, owner)
			item.serverOwned = owner == nil
		end
	end
	if class == "ParticleEmitter" then
		item.Emit = function(_, amount)
			item.emitted = amount
		end
	end
	table.insert(effects, item)
	return item
end
local function advance(seconds)
	h.time += seconds
	for index = #delays, 1, -1 do
		if delays[index].at <= h.time then
			local job = table.remove(delays, index)
			job.fn()
		end
	end
end
local signal, collection = Fixture.Signal, Fixture.Collection()
local world, render = h.instance("Workspace"), { Heartbeat = signal(), RenderStepped = signal() }
local function node(class, name, parent, position)
	local item = h.instance(class)
	item.Name, item.Parent = name, parent
	item.AncestryChanged, item.Destroying, item.ChildAdded, item.ChildRemoved = signal(), signal(), signal(), signal()
	item.GetPivot = function()
		return item.WorldPivot or item.CFrame or Roblox.CFrame.new()
	end
	if item:IsA("BasePart") then
		item.Touched = signal()
		item.LocalTransparencyModifier = 0
		item.Color, item.Material = Roblox.Color3.fromRGB(130, 80, 60), Roblox.Enum.Material.Brick
		item.Position, item.CFrame = position or Roblox.Vector3.zero, Roblox.CFrame.new(position or Roblox.Vector3.zero)
		item.Size, item.Anchored, item.CanCollide, item.CanTouch, item.CanQuery =
			Roblox.Vector3.one, true, true, true, true
		item.GetConnectedParts = function()
			return item.connected or {}
		end
		item.CanSetNetworkOwnership = function()
			return not item.Anchored
		end
		item.SetNetworkOwner = function(_, owner)
			item.serverOwned = owner == nil
		end
		item.PivotTo = function(self, frame)
			self.CFrame, self.Position = frame, frame.Position
		end
	end
	return item
end
local player, teammate = h:player(1), h:player(2)
player.Character = node("Model", "Character", world)
player.CharacterAdded = signal()
local root = node("Part", "HumanoidRootPart", player.Character)
local head = node("Part", "Head", player.Character, Roblox.Vector3.new(0, 2, 0))
local humanoid = node("Humanoid", "Humanoid", player.Character)
humanoid.Health, humanoid.Sit = 100, false
teammate.Character = player.Character
local prop = node("Part", "Mug", world, Roblox.Vector3.new(0, 0, -4))
collection:AddTag(prop, "throw")
local blocked, ready = false, true
world.Raycast = function()
	return blocked and { Instance = root } or nil
end
local services = {
	Workspace = world,
	Players = h.players,
	RunService = render,
	CollectionService = collection,
	HttpService = {
		GenerateGUID = function()
			h.serial += 1
			return "throw-" .. h.serial
		end,
	},
}
local central = h:load("src/GServer/Interaction/InteractionService.luau").new(services, function()
	return ready
end)
local throws = central.throws
local config = h:load("src/GShared/Interaction/ThrowConfig.luau")
local tags = h:load("src/GShared/Interaction/InteractionTags.luau")
check(
	tags.Kind(collection, prop) == "throw" and prop:GetAttribute("DPU_ThrowId") ~= nil,
	"lowercase throw joins central registry"
)
local wrongCase = node("Part", "WrongCase", world)
collection:AddTag(wrongCase, "Throw")
check(tags.Kind(collection, wrongCase) == nil, "throw tag is case sensitive")
local function grab(item, who)
	advance(0.25)
	return central:Request(who or player, "GrabThrow", { Id = (item or prop):GetAttribute("DPU_ThrowId") })
end
local function release(token, who, direction)
	direction = direction or Roblox.Vector3.new(0, 0, -1)
	return central:Request(
		who or player,
		"ReleaseThrow",
		{ Token = token, X = direction.X, Y = direction.Y, Z = direction.Z }
	)
end
ready = false
check(grab().Code == "NotReady", "unready grab rejected")
ready = true
humanoid.Health = 0
check(grab().Code == "Unavailable", "dead grab rejected")
humanoid.Health = 100
local nearFrame = prop.CFrame
prop.Position, prop.CFrame = Roblox.Vector3.new(50, 0, 0), Roblox.CFrame.new(50, 0, 0)
check(grab().Code == "OutOfReach", "remote grab rejected")
prop.CFrame, prop.Position = nearFrame, nearFrame.Position
blocked = true
check(grab().Code == "OutOfReach", "wall blocks grab")
blocked = false
prop.connected = { root }
check(grab().Code == "InvalidProp", "prop welded outside tagged root cannot grab character or scenery")
prop.connected = nil
check(config.ThrowSpeed == 36 and config.UpwardBoost == 4, "launch velocity is half the previous 72 plus 8 arc")
prop:PivotTo(prop.CFrame * Roblox.CFrame.Angles(0.2, 0.6, -0.3))
local original = prop.CFrame
local first = grab()
check(first.Ok and throws.holds[player] and prop:GetAttribute("DPU_ThrowHeld"), "grab reserves item immediately")
check(prop.CFrame == original, "grab reserves the world prop without teleporting it into the hand")
render.Heartbeat:Fire(1 / 60)
check(
	prop.Anchored and not prop.CanCollide and prop.Position.Z < 0 and prop.Position.X > 0,
	"held object moves to front-right without pushing player"
)
local hold = throws.holds[player]
local originalDirection = hold.direction
local function settleAt(fps)
	prop:PivotTo(original)
	hold.velocity = Roblox.Vector3.zero
	for _ = 1, fps / 4 do
		throws:Position(hold, 1 / fps)
	end
	return prop.CFrame
end
local at32, at60, at120 = settleAt(32), settleAt(60), settleAt(120)
check(
	(at32.Position - at60.Position).Magnitude < 0.0001 and (at60.Position - at120.Position).Magnitude < 0.0001,
	"carry spring reaches the same position across frame rates"
)
local heldTarget = head.Position
	+ hold.direction * -config.HoldOffset.Z
	+ root.CFrame.RightVector * config.HoldOffset.X
	+ Roblox.Vector3.new(0, config.HoldOffset.Y, 0)
check((prop.Position - heldTarget).Magnitude < 0.08, "carry settles responsively without overshooting its target")
check(
	prop.CFrame.LookVector:Dot(original.LookVector) > 0.99999,
	"pickup preserves authored orientation relative to holder"
)
check(
	prop.Parent == world and prop.Position ~= original.Position,
	"carry updates the shared world prop rather than a holder-only visual"
)
throws:Aim(player, "stale", 1, 0, 0)
check(hold.direction == originalDirection, "aim update cannot use a stale hold token")
throws:Aim(player, first.Token, math.huge, 0, 0)
check(hold.direction == originalDirection, "nonfinite aim rejected")
advance(config.AimInterval)
throws:Aim(player, first.Token, 0, 0.6, -0.8)
local acceptedAim = hold.direction
throws:Aim(player, first.Token, 1, 0, 0)
check(hold.direction == acceptedAim, "server bounds aim update rate")
render.Heartbeat:Fire(1)
check(
	prop.Position.Y > head.Position.Y and (prop.Position - head.Position).Magnitude < 4,
	"aim raises carried brick but cannot choose arbitrary position"
)
advance(config.AimInterval)
render.Heartbeat:Fire(0)
check(
	hold.direction == Roblox.Vector3.xAxis and hold.pendingDirection == nil,
	"early final aim is coalesced and applied without another client packet"
)
check(grab(nil, teammate).Code == "Unavailable", "second player cannot steal held item")
check(central:Request(player, "Drink", {}).Code == "AlreadyHolding", "holding blocks other mutations")
check(release(first.Token, teammate).Code == "Changed", "other player cannot launch a stolen token")
check(release("old-token").Code == "Changed", "invented hold token rejected")
check(release(first.Token, nil, Roblox.Vector3.new(0 / 0, 0, 0)).Code == "InvalidRequest", "NaN aim rejected")
check(
	release(first.Token, nil, Roblox.Vector3.new(0, 0, -100)).Code == "InvalidRequest",
	"client cannot encode power in aim magnitude"
)
check(
	central:Request(player, "CancelThrow", { Token = first.Token }).Ok
		and prop.CFrame == original
		and prop.CanCollide
		and prop.Anchored,
	"cancel restores authored position and physics"
)
local short = grab()
local releaseFrame = prop.CFrame
check(release(short.Token).Ok, "quick release launches")
check(prop.CFrame == releaseFrame, "release launches from current smoothed position without snapping")
local lightSpeed = prop.AssemblyLinearVelocity.Magnitude
check(
	math.abs(lightSpeed - Roblox.Vector3.new(0, config.UpwardBoost, -config.ThrowSpeed).Magnitude) < 0.01
		and not prop.Anchored
		and prop.serverOwned,
	"server sets fixed throw speed and arc"
)
local trail, emitter
for _, effect in ipairs(effects) do
	if effect:IsA("Trail") then
		trail = effect
	elseif effect:IsA("ParticleEmitter") then
		emitter = effect
	end
end
check(
	trail and trail.Enabled and not emitter and trail.Color.Keypoints[1].Value == Roblox.Color3.new(1, 1, 1),
	"release creates a small white trail without an airborne debris burst"
)
check(release(short.Token).Code == "Changed", "replayed release cannot launch twice")
advance(1.2)
check(trail.Parent == nil, "effects clean themselves up")
local function liveChips()
	local found = {}
	for _, effect in ipairs(effects) do
		if effect.Name == "DPU_ThrowDebris" and effect.Parent then
			table.insert(found, effect)
		end
	end
	return found
end
local decoration = node("Part", "Decoration", world)
decoration.CanCollide = false
prop.Touched:Fire(root)
prop.Touched:Fire(prop)
prop.Touched:Fire(decoration)
check(#liveChips() == 0, "thrower, self and noncollidable decoration never trigger impact debris")
local floor = node("Part", "Floor", world, prop.Position - Roblox.Vector3.yAxis)
prop.Touched:Fire(floor)
check(#liveChips() == 0, "landing never creates brick debris")
prop.Touched:Fire(floor)
check(#liveChips() == 0, "repeated impacts never create debris")
local strong = grab()
advance(2)
check(
	release(strong.Token).Ok and math.abs(prop.AssemblyLinearVelocity.Magnitude - lightSpeed) < 0.01,
	"holding longer cannot change server-set throw speed"
)
local fullSpeed = prop.AssemblyLinearVelocity.Magnitude
check(math.abs(fullSpeed - lightSpeed) < 0.01, "throws travel consistently regardless of carry time")
local stale = grab()
central:Request(player, "CancelThrow", { Token = stale.Token })
local latest = grab()
check(
	central:Request(player, "CancelThrow", { Token = stale.Token }).Code == "Changed" and throws.holds[player],
	"late cancel cannot affect a later hold"
)
humanoid.Health = 0
render.Heartbeat:Fire(1 / 60)
check(not throws.holds[player] and throws.heartbeat == nil, "death cancels hold and removes idle frame loop")
humanoid.Health = 100
grab()
advance(config.MaxHoldSeconds + 1)
render.Heartbeat:Fire(1 / 60)
check(not throws.holds[player], "lost release cannot hold item indefinitely")
grab()
collection:RemoveTag(prop, "throw")
check(not throws.holds[player] and prop:GetAttribute("DPU_ThrowId") == nil, "tag removal releases held item")
collection:AddTag(prop, "throw")

local model = node("Model", "LooseModel", world)
local body = node("Part", "Body", model, Roblox.Vector3.new(0, 0, -4))
local lid = node("Part", "Lid", model, Roblox.Vector3.new(0, 1, -4))
model.WorldPivot = body.CFrame
model.GetBoundingBox = function()
	return model:GetPivot(), Roblox.Vector3.new(1, 2, 1)
end
collection:AddTag(model, "throw")
local modelOrigin, bodyOrigin = model:GetPivot(), body.CFrame
local cancelledModel = grab(model)
central:Request(player, "CancelThrow", { Token = cancelledModel.Token })
check(
	model:GetPivot() == modelOrigin and body.CFrame == bodyOrigin,
	"model cancellation restores pivot as well as individual parts"
)
local modelGrab = grab(model)
check(modelGrab.Ok and release(modelGrab.Token).Ok, "whole model can be grabbed and launched")
check(
	not body.Anchored and not lid.Anchored and #throws.items[model].welds == 1,
	"generated weld keeps loose model pieces together"
)

-- Real client state machine plus central mouse/touch/controller routing.
local input = {
	InputBegan = signal(),
	InputEnded = signal(),
	InputChanged = signal(),
	WindowFocusReleased = signal(),
	WindowFocused = signal(),
	PreferredInput = preferred.KeyboardAndMouse,
	GetFocusedTextBox = function()
		return nil
	end,
	GetMouseLocation = function()
		return Roblox.Vector2.new(300, 300)
	end,
}
local camera = { ViewportSize = Roblox.Vector2.new(800, 600), CFrame = Roblox.CFrame.new(head.Position) }
world.Gravity = 196.2
camera.ViewportPointToRay = function()
	return { Origin = head.Position, Direction = Roblox.Vector3.new(0, 0, -1) }
end
camera.ScreenPointToRay = camera.ViewportPointToRay
world.CurrentCamera = camera
local calls, menu, meter, power = {}, false, false, 0
local aimCalls = 0
local client = h:load("src/GClient/Interaction/CarryController.luau").new({
	aim = {
		FireServer = function(_, token, x, y, z)
			aimCalls += 1
			throws:Aim(player, token, x, y, z)
		end,
	},
	player = player,
	input = input,
	collection = collection,
	workspace = world,
	render = render,
	config = config,
	blocked = function()
		return menu
	end,
	locked = function()
		return true
	end,
	meter = function(active, value)
		meter, power = active, value
	end,
	remote = {
		InvokeServer = function(_, action, payload)
			table.insert(calls, { action, payload })
			return central:Request(player, action, payload)
		end,
	},
})
local router = h:load("src/GClient/Interaction/InteractionController.luau").new({
	player = player,
	input = input,
	collection = collection,
	workspace = world,
	throw = client,
	config = h:load("src/GShared/Interaction/ContainerConfig.luau"),
	blocked = function()
		return menu
	end,
	locked = function()
		return true
	end,
	template = function()
		return nil
	end,
	hover = function() end,
})
local raycast = world.Raycast
world.Raycast = function(_, _, _, params)
	if blocked then
		return { Instance = floor, Position = floor.Position }
	end
	if #params.FilterDescendantsInstances == 1 and not throws.holds[player] then
		return { Instance = prop, Position = prop.Position }
	end
	return nil
end
local function mouseDown()
	advance(0.25)
	input.InputBegan:Fire({ UserInputType = Roblox.Enum.UserInputType.MouseButton1 }, false)
end
local function mouseUp()
	input.InputEnded:Fire({ UserInputType = Roblox.Enum.UserInputType.MouseButton1 }, false)
end
mouseDown()
check(client:Busy() and #calls == 0, "mouse down begins grab before asynchronous request reply")
mouseUp()
check(client:Busy() and #calls == 0, "mouse release keeps the brick held")
mouseDown()
h:drain()
check(
	#calls == 2 and calls[1][1] == "GrabThrow" and calls[2][1] == "ReleaseThrow" and not client:Busy(),
	"second click before grab reply is queued exactly once"
)
mouseUp()
h:drain()
check(#calls == 2, "duplicate mouse release sends no second launch")
mouseDown()
input.WindowFocusReleased:Fire()
h:drain()
check(
	calls[#calls][1] == "CancelThrow" and not throws.holds[player] and not meter,
	"focus loss before grab reply cancels instead of throwing"
)
input.WindowFocused:Fire()
mouseDown()
h:drain()
local beforeFrames = #calls
advance(0.75)
client:Update(1 / 60)
check(
	meter and power:find("CLICK", 1, true) and #calls == beforeFrames,
	"carry hint is local and needs no request per frame"
)
local visual = client.session.visual
check(
	visual and visual.clone ~= prop and prop.LocalTransparencyModifier == 1 and not visual.clone.CanQuery,
	"holder sees isolated non-querying prediction while original is locally hidden"
)
local beforeAim = aimCalls
for _ = 1, 20 do
	client:Update(1 / 60)
end
check(aimCalls == beforeAim, "stationary camera never repeats aim messages each render frame")
advance(config.AimInterval)
camera.ViewportPointToRay = function()
	return { Origin = head.Position, Direction = Roblox.Vector3.new(0, 0.6, -0.8) }
end
client:Update(1 / 60)
check(aimCalls == beforeAim + 1, "changed aim sends one bounded unit-direction update")
local serverFrame, visualFrame, sent = prop.CFrame, visual.frame, aimCalls
camera.ViewportPointToRay = function()
	return { Origin = head.Position, Direction = Roblox.Vector3.new(0.6, 0, -0.8) }
end
client:Update(1 / 60)
check(
	visual.frame ~= visualFrame and prop.CFrame == serverFrame and aimCalls == sent,
	"local carry follows turns between network samples without changing authoritative position"
)
local previousRay = camera.ViewportPointToRay
camera.ViewportPointToRay = function()
	return { Origin = camera.CFrame.Position, Direction = camera.CFrame.LookVector }
end
for _ = 1, 120 do
	client:Update(1 / 120)
end
local heldOffset = camera.CFrame:PointToObjectSpace(visual.frame.Position)
for _, yaw in ipairs({ 45, 90, 180, 270, 360 }) do
	camera.CFrame = Roblox.CFrame.new(head.Position) * Roblox.CFrame.Angles(0, math.rad(yaw), 0)
	client:Update(1 / 120)
	check(
		(camera.CFrame:PointToObjectSpace(visual.frame.Position) - heldOffset).Magnitude < 0.001,
		"rapid spinning keeps settled brick at a stable camera-relative offset"
	)
end
camera.CFrame = Roblox.CFrame.new(head.Position)
camera.ViewportPointToRay = previousRay
blocked = true
visualFrame = visual.frame
client:Update(1 / 60)
check(visual.frame == visualFrame, "local prediction does not carry through a wall")
blocked = false
menu = true
client:Update(1 / 60)
h:drain()
check(not client:Busy() and not throws.holds[player], "menu interrupts a held prop")
check(
	visual.clone.Parent == nil and prop.LocalTransparencyModifier == 0,
	"carry cleanup restores original visibility and removes cosmetic clone"
)
menu = false
advance(0.25)
local touch = { UserInputType = Roblox.Enum.UserInputType.Touch, Position = Roblox.Vector3.new(300, 300, 0) }
input.PreferredInput = preferred.Touch
input.InputBegan:Fire(touch, false)
check(not client:Busy(), "touch down alone does not grab")
advance(0.1)
input.InputEnded:Fire(touch, false)
h:drain()
check(client:Busy() and throws.holds[player], "first intentional tap carries the brick")
local unrelated = { UserInputType = Roblox.Enum.UserInputType.Touch }
input.InputEnded:Fire(unrelated, false)
check(client:Busy(), "another finger release cannot throw")
local drag = { UserInputType = Roblox.Enum.UserInputType.Touch, Position = Roblox.Vector3.new(300, 300, 0) }
input.InputBegan:Fire(drag, false)
drag.Position = Roblox.Vector3.new(400, 300, 0)
input.InputChanged:Fire(drag)
input.InputEnded:Fire(drag, false)
h:drain()
check(client:Busy(), "camera dragging while carrying neither launches nor drops")
client:Update(1 / 60)
local departing = client.session.visual
local releaseStart, authoritativeStart = departing.frame, prop.CFrame
input.InputBegan:Fire(touch, false)
input.InputEnded:Fire(touch, false)
check(
	client.releasing == departing and not departing.destroyed and prop.LocalTransparencyModifier == 1,
	"release keeps the owner visual instead of revealing a stale server pose"
)
client:Update(1 / 60)
check(
	departing.frame ~= releaseStart and prop.CFrame == authoritativeStart and not departing.accepted,
	"throw visual moves immediately before server reply without moving server physics"
)
h:drain()
check(not client:Busy() and calls[#calls][1] == "ReleaseThrow", "second tap launches once")
check(
	client.releasing == departing and departing.accepted,
	"server receipt begins a visual handoff instead of destroying the clone"
)
for _ = 1, 12 do
	client:Update(1 / 60)
end
check(
	not client.releasing and departing.destroyed and prop.LocalTransparencyModifier == 0,
	"completed release blend restores the real brick and frees the temporary view"
)
advance(0.25)
input.PreferredInput = preferred.Gamepad
input.InputBegan:Fire({ KeyCode = Roblox.Enum.KeyCode.ButtonR2 }, false)
h:drain()
check(client:Busy(), "controller trigger holds a prop")
input.InputEnded:Fire({ KeyCode = Roblox.Enum.KeyCode.ButtonR2 }, false)
check(client:Busy(), "controller trigger release keeps carrying")
input.InputBegan:Fire({ KeyCode = Roblox.Enum.KeyCode.ButtonR2 }, false)
h:drain()
check(not client:Busy() and calls[#calls][1] == "ReleaseThrow", "second controller trigger press throws")
advance(0.25)
client:Begin(prop, { UserInputType = Roblox.Enum.UserInputType.MouseButton1 })
h:drain()
client:Update(1 / 60)
local rejected = client.session.visual
blocked = true
client:Release()
h:drain()
check(
	rejected.destroyed and not client.releasing and prop.LocalTransparencyModifier == 0 and not throws.holds[player],
	"server rejection cancels cosmetic flight and restores the authoritative prop"
)
blocked = false
input.PreferredInput = preferred.KeyboardAndMouse
mouseDown()
h:drain()
collection:RemoveTag(prop, "throw")
client:Update(1 / 60)
h:drain()
check(not client:Busy() and not throws.holds[player], "client exits when server unbinds the held item")
collection:AddTag(prop, "throw")
mouseDown()
router:Destroy()
h:drain()
check(not throws.holds[player] and not meter, "teardown cancels even an in-flight grab")
-- Frame-rate independent pickup and bounded, collision-aware release visuals.
local CarryView = h:load("src/GClient/Interaction/CarryView.luau")
local reference
for _, fps in ipairs({ 30, 60, 144 }) do
	local preview = CarryView.new(prop, client.d)
	for _ = 1, math.floor(fps * 0.5) do
		preview:Update(Roblox.Vector3.new(0, 0, -1), 1 / fps)
	end
	reference = reference or preview.frame.Position
	check((preview.frame.Position - reference).Magnitude < 0.001, "pickup smoothing agrees at 30, 60 and 144 FPS")
	preview:Destroy()
end
local pending = CarryView.new(prop, client.d)
pending:Release(Roblox.Vector3.new(0, 0, -1))
blocked = true
local beforeContact = pending.frame
pending:UpdateRelease(1 / 60)
check(
	pending.hit and (pending.frame.Position - beforeContact.Position).Magnitude < 0.0001,
	"predicted release stops at an obstruction"
)
blocked = false
for _ = 1, 8 do
	if not pending:UpdateRelease(0.1) then
		pending:Destroy()
		break
	end
end
check(pending.destroyed and prop.LocalTransparencyModifier == 0, "missing receipt has a bounded visibility cleanup")
local replaced = CarryView.new(prop, client.d)
replaced:Release(Roblox.Vector3.new(0, 0, -1))
world.CurrentCamera = {}
check(not replaced:UpdateRelease(1 / 60), "camera replacement terminates pending release presentation")
replaced:Destroy()
world.CurrentCamera = camera
world.Raycast = raycast
central:Shutdown()
advance(2)
check(
	prop:GetAttribute("DPU_ThrowId") == nil and throws.heartbeat == nil,
	"shutdown clears identities and held-object loop"
)
print(string.format("PASS: %d carry, throw, effects and input checks (mocked Roblox).", total))
