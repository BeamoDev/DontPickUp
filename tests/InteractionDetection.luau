local Harness = require("./Harness")
local Fixture = require("./TagFixture")
local Roblox = require("@lune/roblox")
local h, total = Harness.Environment(), 0
local function check(value, label)
	assert(value, label)
	total += 1
end
for _, name in ipairs({ "Vector3", "Vector2", "CFrame" }) do
	h.env[name] = Roblox[name]
end
local preferred = { KeyboardAndMouse = "Mouse", Touch = "Touch", Gamepad = "Pad" }
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
local world, collection = h.instance("Workspace"), Fixture.Collection()
local function part(name, parent, position, size)
	local item = h.instance("Part")
	item.Name, item.Parent, item.Position = name, parent, position or Roblox.Vector3.new(0, 0, -4)
	item.CFrame, item.Size = Roblox.CFrame.new(item.Position), size or Roblox.Vector3.one
	item.CanCollide, item.CanQuery = true, true
	return item
end
local cabinet = h.instance("Model")
cabinet.Parent = world
collection:AddTag(cabinet, "Container")
local drawer = part("Box1", cabinet)
drawer:SetAttribute("DPU_ContainerId", "drawer")
drawer:SetAttribute("DPU_ContainerRevision", 1)
local handle = part("Handle", drawer)
local label = part("Label1", cabinet)
local decor = part("Dust", world)
decor.CanCollide = false
local wall = part("Wall", world)
local terrain = h.instance("Terrain")
terrain.Parent = world
local hits, rayCount = { drawer }, 0
world.Raycast = function(_, origin, direction, params)
	rayCount += 1
	for _, candidate in ipairs(hits) do
		if not table.find(params.FilterDescendantsInstances, candidate) then
			return { Instance = candidate, Position = candidate.Position or Roblox.Vector3.zero }
		end
	end
	return nil
end
local Tags = h:load("src/GShared/Interaction/InteractionTags.luau")
local Query = h:load("src/GShared/Interaction/InteractionQuery.luau")
local function cast()
	rayCount = 0
	return Query.Cast(world, collection, Roblox.Vector3.zero, Roblox.Vector3.new(0, 0, -40), {}, {}, function(hit)
		return Tags.Resolve(collection, world, hit)
	end)
end
hits = { decor, drawer }
local hit, target = cast()
check(target == cabinet and rayCount == 2, "decoration skipped with bounded query")
hits = { wall, drawer }
hit, target = cast()
check(hit.Instance == wall and target == nil and rayCount == 1, "solid wall stops selection")
wall.Transparency = 1
hit, target = cast()
check(target == nil, "invisible collidable barrier still blocks")
hits = { terrain, drawer }
hit, target = cast()
check(target == nil, "terrain stops selection")
hits = {}
for i = 1, 20 do
	local item = part("Decoration" .. i, world)
	item.CanCollide = false
	table.insert(hits, item)
end
table.insert(hits, drawer)
hit, target = cast()
check(hit and not target and rayCount == Query.MaxHits, "query budget fails closed without unbounded work")
hits = { decor, drawer }
local character, root, head, humanoid = h.instance("Model"), nil, nil, h.instance("Humanoid")
character.Parent, character.DescendantAdded = world, Fixture.Signal()
root, head = part("HumanoidRootPart", character, Roblox.Vector3.zero), part("Head", character, Roblox.Vector3.zero)
humanoid.Parent, humanoid.Health, humanoid.Sit, humanoid.MoveDirection = character, 100, false, Roblox.Vector3.zero
check(Query.Visible(world, collection, character, head, drawer), "server sees through identical decoration")
hits = { wall, drawer }
check(not Query.Visible(world, collection, character, head, drawer), "server independently blocks wall")
local wide = part("WideDrawer", world, Roblox.Vector3.new(10, 0, 0), Roblox.Vector3.new(12, 2, 2))
check(Query.Distance(wide, root.Position) == 4, "reach measured to surface instead of remote part center")

local signal = Fixture.Signal
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
		return Roblox.Vector2.new(125, 250)
	end,
}
local pixel
world.CurrentCamera = {
	ViewportSize = Roblox.Vector2.new(800, 600),
	ViewportPointToRay = function(_, x, y)
		pixel = Roblox.Vector2.new(x, y)
		return { Origin = Roblox.Vector3.zero, Direction = -Roblox.Vector3.zAxis }
	end,
	ScreenPointToRay = function()
		error("raw pixels must not add GUI inset")
	end,
}
local player = h:player(1)
player.Character, player.CharacterAdded = character, signal()
local locked, ui, calls = false, false, 0
local template = h.instance("Highlight")
template.FillTransparency = 0.6
local inspection = {
	saved = { Model = cabinet },
	Close = function(self)
		self.saved = nil
	end,
}
local phone = {
	saved = nil,
	InputBegan = function(self)
		self.saved = nil
	end,
	InputChanged = function() end,
}
local router = h:load("src/GClient/Interaction/InteractionController.luau").new({
	workspace = world,
	collection = collection,
	player = player,
	input = input,
	inspection = inspection,
	telephone = phone,
	config = h:load("src/GShared/Interaction/ContainerConfig.luau"),
	template = function()
		return template
	end,
	locked = function()
		return locked
	end,
	blocked = function()
		return false
	end,
	uiBlocked = function()
		return ui
	end,
	hover = function() end,
	remote = {
		InvokeServer = function()
			calls += 1
			return { Ok = true }
		end,
	},
})
hits = { handle }
router:Update()
check(
	pixel == Roblox.Vector2.new(125, 250) and router.highlight.Adornee == drawer,
	"raw pointer ray and nested handle select drawer"
)
hits = { label }
check(router:Pick(router:Pointer()) == drawer, "paired label resolves owning drawer")
ui = true
router:Update()
check(not router.highlight.Enabled, "UI clears hover and blocks world ray")
ui = false
local function touch()
	local event = { UserInputType = Roblox.Enum.UserInputType.Touch, Position = Roblox.Vector3.new(125, 250, 0) }
	input.InputBegan:Fire(event, false)
	return event
end
local event = touch()
event.Position = Roblox.Vector3.new(170, 250, 0)
input.InputChanged:Fire(event)
event.Position = Roblox.Vector3.new(125, 250, 0)
input.InputEnded:Fire(event, false)
h:drain()
check(calls == 0, "drag out and back is never a tap")
event = touch()
input.InputBegan:Fire({ UserInputType = Roblox.Enum.UserInputType.Touch }, true)
input.InputEnded:Fire(event, false)
h:drain()
check(calls == 0, "second UI finger cancels initial tap")
event = touch()
input.InputEnded:Fire(event, false)
input.InputEnded:Fire(event, false)
h:drain()
check(calls == 1, "one valid tap sends one request")
phone.saved = {}
input.InputBegan:Fire({ UserInputType = Roblox.Enum.UserInputType.MouseButton1 }, false)
h:drain()
check(calls == 1 and phone.saved == nil, "phone close event never falls through to drawer behind it")
event = touch()
drawer:SetAttribute("DPU_ContainerId", "replacement-drawer")
input.InputEnded:Fire(event, false)
h:drain()
check(calls == 1, "rebound object identity invalidates an in-flight touch")
-- The shared server visibility policy recognises the same paired label surface.
hits = { label }
local containerConfig = h:load("src/GShared/Interaction/ContainerConfig.luau")
check(
	Query.Visible(world, collection, character, head, drawer, nil, function(candidate)
		return containerConfig.ResolveBox(candidate, cabinet) == drawer
	end),
	"paired label is a valid drawer surface on the server"
)
local trim = part("Trim", cabinet)
trim.CanCollide = false
hits = { trim, handle }
check(router:Pick(router:Pointer()) == drawer, "non-collidable inspection trim does not hide drawer handles")
trim.CanCollide = true
check(router:Pick(router:Pointer()) == nil, "solid cabinet geometry still blocks drawers")
hits = { label }
local clone = router.highlight
drawer:SetAttribute("DPU_ContainerBusy", true)
router:Update()
check(not clone.Enabled, "busy target loses highlight")
drawer:SetAttribute("DPU_ContainerBusy", false)
hits = { handle }
router:Update()
check(router.highlight == clone and clone.Enabled, "available target reuses highlight")
drawer:Destroy()
router:Update()
check(
	router.highlight == clone and clone.Parent == world and not clone.Enabled,
	"target deletion preserves reusable highlight"
)
inspection.saved = nil
hits = { label }
locked = true
router:Update()
check(pixel == Roblox.Vector2.new(400, 300), "locked first person uses viewport center")
-- A late reply cannot clear a later request gate, and timeout never retries.
local originalRemote = router.d.remote
local requests = 0
router.d.remote = {
	InvokeServer = function()
		requests += 1
		return { Ok = true }
	end,
}
router:Request(label, "Test", {})
local oldJob = table.remove(h.jobs, 1)
h.time += 9
router:Update()
check(router.pending == nil and requests == 0, "unanswered local gate expires without retrying the request")
router:Request(label, "Test", {})
local newPending = router.pending
oldJob[1](table.unpack(oldJob[2], 1, oldJob[2].n))
check(router.pending == newPending, "old reply cannot clear a newer pending request")
h:drain()
check(requests == 2 and router.pending == nil, "each explicit intent invokes once")
local customer = h.instance("Model")
customer.Parent = world
collection:AddTag(customer, "Customer")
customer:SetAttribute("DPU_OrderId", "active-order")
customer:SetAttribute("DPU_OrderRevision", 3)
customer:SetAttribute("DPU_OrderStage", "Waiting")
local customerHand = part("Hand", customer)
hits = { customerHand }
check(router:Pick(nil) == customer, "customer child surface resolves through the central picker")
local customerRequests, captured = 0, nil
router.d.remote.InvokeServer = function(_, action, payload)
	customerRequests += 1
	captured = { action, payload }
	return { Ok = true }
end
event = touch()
customer:SetAttribute("DPU_OrderRevision", 4)
input.InputEnded:Fire(event, false)
h:drain()
check(
	captured[1] == "ServeCustomer" and captured[2].Revision == 3,
	"touch sends captured order revision for server stale-request rejection"
)
event = touch()
input.InputEnded:Fire(event, false)
input.InputEnded:Fire(event, false)
h:drain()
check(customerRequests == 2 and captured[2].Revision == 4, "one valid customer tap sends exactly one request")
customer:SetAttribute("DPU_OrderStage", "Repairing")
check(router:Pick(nil) == nil, "unavailable customer no longer highlights or accepts a click")
hits = { wall, customerHand }
customer:SetAttribute("DPU_OrderStage", "Ready")
check(router:Pick(nil) == nil, "customer picking still respects walls")
router.d.remote = originalRemote
router:Destroy()
check(clone.Parent == nil, "teardown destroys local highlight")
input.InputBegan:Fire({ UserInputType = Roblox.Enum.UserInputType.MouseButton1 }, false)
h:drain()
check(calls == 1, "teardown disconnects world input")
-- Exercise real pooled fades with controllable tween completion.
h.env.TweenInfo = {
	new = function(seconds)
		return { seconds = seconds }
	end,
}
local fadeJobs = {}
local fadeService = {
	Create = function(_, object, info, goals)
		local tween = { Completed = signal(), goals = goals, object = object }
		function tween:Play() end
		function tween:Cancel()
			self.cancelled = true
		end
		function tween:Finish()
			if not self.cancelled then
				for key, value in pairs(self.goals) do
					self.object[key] = value
				end
			end
			self.Completed:Fire()
		end
		table.insert(fadeJobs, tween)
		return tween
	end,
}
local Selection = h:load("src/GClient/Interaction/SelectionHighlight.luau")
local selection = Selection.new(world, function()
	return template
end, fadeService)
local first, second = part("First", world), part("Second", world)
local highlight = selection:Set(first)
check(highlight.Enabled and highlight.FillTransparency == 1, "new target begins fully transparent")
local entrance = fadeJobs[#fadeJobs]
selection:Set(first)
check(fadeJobs[#fadeJobs] == entrance, "same hover does not restart fade every frame")
entrance:Finish()
check(highlight.FillTransparency == 0.6, "fade preserves authored opacity")
selection:Set(nil)
local exitTween = fadeJobs[#fadeJobs]
check(highlight.Enabled and highlight.Adornee == first, "fade-out retains adornment until invisible")
selection:Set(first)
check(exitTween.cancelled and highlight.Adornee == first, "brief miss reverses fade instead of flashing")
exitTween:Finish()
check(highlight.Adornee == first, "obsolete completion cannot clear recovered highlight")
fadeJobs[#fadeJobs]:Finish()
selection:Set(second)
check(highlight.Adornee == first, "target switch fades previous object first")
fadeJobs[#fadeJobs]:Finish()
check(
	highlight.Adornee == second and highlight.FillTransparency == 1,
	"next target starts transparent using same instance"
)
fadeJobs[#fadeJobs]:Finish()
selection:Set(nil)
fadeJobs[#fadeJobs]:Finish()
check(not highlight.Enabled and highlight.Adornee == nil, "completed exit disables pooled highlight")
selection:Set(first)
local pendingFade = fadeJobs[#fadeJobs]
selection:Destroy()
pendingFade:Finish()
check(pendingFade.cancelled and highlight.Parent == nil, "teardown cancels tween and releases highlight")
print(string.format("PASS: %d detection, occlusion, gesture and input ownership checks (mocked Roblox).", total))
