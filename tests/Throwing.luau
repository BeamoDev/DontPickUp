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
		item.PivotTo = function(_, frame)
			item.CFrame, item.Position = frame, frame.Position
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
local central = h:load("src/GServer/Interactions/InteractionService.luau").new(services, function()
	return ready
end)
local throws = central.throws
local config = h:load("src/GShared/Interactions/ThrowConfig.luau")
local tags = h:load("src/GShared/Interactions/InteractionTags.luau")
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
prop.Position = Roblox.Vector3.new(50, 0, 0)
check(grab().Code == "OutOfReach", "remote grab rejected")
prop.Position = prop.CFrame.Position
blocked = true
check(grab().Code == "OutOfReach", "wall blocks grab")
blocked = false
prop.connected = { root }
check(grab().Code == "InvalidProp", "prop welded outside tagged root cannot grab character or scenery")
prop.connected = nil
local original = prop.CFrame
local first = grab()
check(first.Ok and throws.holds[player] and prop:GetAttribute("DPU_ThrowHeld"), "grab reserves item immediately")
check(
	prop.Anchored and not prop.CanCollide and prop.Position.Z < 0 and prop.Position.X > 0,
	"held object moves to front-right without pushing player"
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
check(release(short.Token).Ok, "quick release launches")
local lightSpeed = prop.AssemblyLinearVelocity.Magnitude
check(
	math.abs(lightSpeed - config.MinSpeed) < 0.01 and not prop.Anchored and prop.serverOwned,
	"tap uses minimum speed with server-owned physics"
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
	trail and trail.Enabled and emitter and emitter.emitted == 6,
	"release creates a short trail and small particle burst"
)
check(release(short.Token).Code == "Changed", "replayed release cannot launch twice")
advance(1.2)
check(trail.Parent == nil and emitter.Parent == nil, "effects clean themselves up")
local strong = grab()
advance(config.ChargeSeconds + 1)
check(
	release(strong.Token).Ok and math.abs(prop.AssemblyLinearVelocity.Magnitude - config.MaxSpeed) < 0.01,
	"long hold increases speed and caps at maximum"
)
local fullSpeed = prop.AssemblyLinearVelocity.Magnitude
check(fullSpeed > lightSpeed, "long holds are stronger than taps")
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
local camera = { ViewportSize = Roblox.Vector2.new(800, 600) }
camera.ViewportPointToRay = function()
	return { Origin = head.Position, Direction = Roblox.Vector3.new(0, 0, -1) }
end
camera.ScreenPointToRay = camera.ViewportPointToRay
world.CurrentCamera = camera
local calls, menu, meter, power = {}, false, false, 0
local client = h:load("src/GClient/Interactions/ThrowInteraction.luau").new({
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
local router = h:load("src/GClient/Interactions/TaggedInteraction.luau").new({
	player = player,
	input = input,
	collection = collection,
	workspace = world,
	throw = client,
	config = h:load("src/GShared/Containers/ContainerConfig.luau"),
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
h:drain()
check(
	#calls == 2 and calls[1][1] == "GrabThrow" and calls[2][1] == "ReleaseThrow" and not client:Busy(),
	"release before grab reply is queued exactly once"
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
render.RenderStepped:Fire()
check(
	meter and math.abs(power - 0.5) < 0.01 and #calls == beforeFrames,
	"charge meter updates locally without pointer-stream remotes"
)
menu = true
render.RenderStepped:Fire()
h:drain()
check(not client:Busy() and not throws.holds[player], "menu interrupts a held prop")
menu = false
advance(0.25)
local touch = { UserInputType = Roblox.Enum.UserInputType.Touch, Position = Roblox.Vector3.new(300, 300, 0) }
input.PreferredInput = preferred.Touch
input.InputBegan:Fire(touch, false)
h:drain()
check(client:Busy() and throws.holds[player], "touch begins holding rather than waiting for a tap")
local unrelated = { UserInputType = Roblox.Enum.UserInputType.Touch }
input.InputEnded:Fire(unrelated, false)
check(client:Busy(), "another finger cannot release held prop")
advance(0.8)
input.InputEnded:Fire(touch, false)
h:drain()
check(
	not client:Busy() and calls[#calls][1] == "ReleaseThrow",
	"long touch releases charged throw without short-tap restriction"
)
advance(0.25)
input.PreferredInput = preferred.Gamepad
input.InputBegan:Fire({ KeyCode = Roblox.Enum.KeyCode.ButtonR2 }, false)
h:drain()
check(client:Busy(), "controller trigger holds a prop")
input.InputEnded:Fire({ KeyCode = Roblox.Enum.KeyCode.ButtonR2 }, false)
h:drain()
check(not client:Busy() and calls[#calls][1] == "ReleaseThrow", "controller trigger release throws")
input.PreferredInput = preferred.KeyboardAndMouse
mouseDown()
h:drain()
collection:RemoveTag(prop, "throw")
render.RenderStepped:Fire()
h:drain()
check(not client:Busy() and not throws.holds[player], "client exits when server unbinds the held item")
collection:AddTag(prop, "throw")
mouseDown()
router:Destroy()
h:drain()
check(not throws.holds[player] and not meter, "teardown cancels even an in-flight grab")
world.Raycast = raycast
central:Shutdown()
advance(2)
check(
	prop:GetAttribute("DPU_ThrowId") == nil and throws.heartbeat == nil,
	"shutdown clears identities and held-object loop"
)
print(string.format("PASS: %d charge, throw, effects and input checks (mocked Roblox).", total))
