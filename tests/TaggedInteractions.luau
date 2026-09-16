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
local preferred = { KeyboardAndMouse = "Mouse", Gamepad = "Gamepad", Touch = "Touch" }
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
h.env.TweenInfo = {
	new = function()
		return {}
	end,
}
local signal, collection = Fixture.Signal, Fixture.Collection()
local world, storage = h.instance("Workspace"), h.instance("Folder")
local function instance(class, name, parent)
	local item = h.instance(class)
	item.Name, item.Parent = name, parent
	item.AncestryChanged, item.Destroying, item.ChildAdded, item.ChildRemoved = signal(), signal(), signal(), signal()
	if item:IsA("BasePart") then
		item.Position, item.CFrame, item.Size = Roblox.Vector3.zero, Roblox.CFrame.new(), Roblox.Vector3.new(1, 1, 1)
		item.Anchored, item.CanQuery, item.Transparency = true, true, 0
	end
	return item
end
local cabinet = instance("Model", "RenamedCabinet", world)
local drawer = instance("Part", "Box1", cabinet)
local nested = instance("Folder", "Room", world)
local cabinet2 = instance("Model", "OtherCabinet", nested)
local drawer2 = instance("Part", "Box1", cabinet2)
local fax = instance("Model", "CallDesk", nested)
local key = instance("Part", "Key1", fax)
local drink = instance("Model", "Soda", world)
local cup = instance("Part", "Cup", drink)
local decal = instance("Decal", "Label", cup)
decal.Transparency = 0
collection:AddTag(cabinet, "Container")
collection:AddTag(cabinet2, "Container")
collection:AddTag(fax, "Fax")
collection:AddTag(drink, "Drink")
local Tags = h:load("src/GShared/Interactions/InteractionTags.luau")
check(Tags.Resolve(collection, world, drawer) == cabinet, "renamed cabinet resolves by tag")
local found, kind = Tags.Resolve(collection, world, key)
check(found == fax and kind == "Fax", "nested renamed fax resolves from key")
check(Tags.Resolve(collection, world, cup) == drink, "drink model resolves from a child")
local unnamed = instance("Model", "Telephone", world)
check(Tags.Kind(collection, unnamed) == nil, "old name alone does not activate props")
local player, teammate = h:player(1), h:player(2)
player.Character = instance("Model", "Character", world)
player.CharacterAdded = signal()
local root = instance("Part", "HumanoidRootPart", player.Character)
local head = instance("Part", "Head", player.Character)
root.Position, head.Position = Roblox.Vector3.new(0, 0, 3), Roblox.Vector3.new(0, 2, 3)
local humanoid = instance("Humanoid", "Humanoid", player.Character)
humanoid.Health, humanoid.Sit = 100, false
teammate.Character = player.Character
local tweens, obstruction, ready = {}, nil, true
world.Raycast = function()
	return obstruction and { Instance = obstruction } or nil
end
local services = {
	Workspace = world,
	Players = h.players,
	CollectionService = collection,
	HttpService = {
		GenerateGUID = function()
			h.serial += 1
			return "tag-" .. h.serial
		end,
	},
	TweenService = {
		Create = function(_, target, _, goal)
			local tween = {
				target = target,
				goal = goal,
				Completed = signal(),
				Play = function(self)
					self.played = true
				end,
			}
			function tween:Cancel()
				self.cancelled = true
			end
			function tween:Finish()
				if self.cancelled then
					return
				end
				for name, value in pairs(goal) do
					target[name] = value
				end
				self.Completed:Fire(Roblox.Enum.PlaybackState.Completed)
			end
			table.insert(tweens, tween)
			return tween
		end,
	},
}
local service = h:load("src/GServer/Interactions/InteractionService.luau").new(services, function()
	return ready
end)
check(
	drawer:GetAttribute("DPU_ContainerId") ~= nil and drawer2:GetAttribute("DPU_ContainerId") ~= nil,
	"multiple tagged containers bind anywhere in workspace"
)
local function request(item, action, who, id)
	h.time += 0.2
	return service:Request(
		who or player,
		action or "Drink",
		{ Id = id or item:GetAttribute("DPU_DrinkId"), Revision = 0 }
	)
end
check(drink:GetAttribute("DPU_DrinkId") ~= nil, "tagged model drink gets server identity")
ready = false
check(request(drink).Code == "NotReady", "unadmitted drink request rejected")
ready = true
check(request(drink, nil, nil, "made-up").Code == "Unavailable", "fabricated identity rejected")
root.Position = Roblox.Vector3.new(100, 0, 0)
check(request(drink).Code == "TooFar", "remote drinking rejected")
root.Position = Roblox.Vector3.new(0, 0, 3)
humanoid.Health = 0
check(request(drink).Code == "Unavailable", "dead drinking rejected")
humanoid.Health, humanoid.Sit = 100, true
check(request(drink).Code == "Unavailable", "seated drinking rejected")
humanoid.Sit = false
obstruction = instance("Part", "Wall", world)
check(request(drink).Code == "Blocked", "wall blocks drinking")
obstruction = cup
local id = drink:GetAttribute("DPU_DrinkId")
check(request(drink).Ok and drink:GetAttribute("DPU_DrinkBusy"), "accepted drink reserves before fading")
check(#tweens == 2 and cup.Transparency == 0 and drink.Parent == world, "drink starts at zero and remains during fade")
check(request(drink, nil, teammate).Code == "PleaseWait", "second player cannot consume same drink")
check(tweens[1].goal.Transparency == 1 and tweens[2].goal.Transparency == 1, "mesh and label both fade to one")
tweens[2]:Finish()
check(drink.Parent == world, "out-of-order tween completion does not delete before every part fades")
tweens[1]:Finish()
check(drink.Parent == nil and cup.Transparency == 1, "finished fade deletes consumed model")
check(request(drink, nil, nil, id).Code == "Unavailable", "consumed identity cannot be replayed")
local bottle = instance("Part", "Bottle", storage)
collection:AddTag(bottle, "Drink")
check(bottle:GetAttribute("DPU_DrinkId") == nil, "tagged stored props are inactive")
bottle.Parent = nested
bottle.AncestryChanged:Fire()
check(bottle:GetAttribute("DPU_DrinkId") ~= nil, "parenting tagged part into nested workspace activates it")
obstruction = bottle
check(request(bottle).Ok, "single Part drink also fades")
local cancelled = tweens[#tweens]
bottle.Transparency = 0.5
collection:RemoveTag(bottle, "Drink")
cancelled:Finish()
check(
	cancelled.cancelled and bottle.Parent == nested and bottle.Transparency == 0,
	"untagging cancels fade, restores geometry and prevents late deletion"
)
collection:AddTag(bottle, "Drink")
local oldId = bottle:GetAttribute("DPU_DrinkId")
bottle.Parent = storage
bottle.AncestryChanged:Fire()
check(bottle:GetAttribute("DPU_DrinkId") == nil, "moving out of workspace unbinds drink")
bottle.Parent = nested
bottle.AncestryChanged:Fire()
check(bottle:GetAttribute("DPU_DrinkId") ~= oldId, "reparenting gets fresh identity")
collection:RemoveTag(cabinet, "Container")
check(
	drawer:GetAttribute("DPU_ContainerId") == nil and drawer2:GetAttribute("DPU_ContainerId") ~= nil,
	"untagging one cabinet preserves the other"
)
collection:AddTag(cabinet, "Container")
obstruction = drawer2
local response = request(drawer2, "ToggleContainer", nil, drawer2:GetAttribute("DPU_ContainerId"))
check(response.Ok, "central endpoint routes second cabinet toggle")
tweens[#tweens]:Finish()
check(math.abs(drawer2.CFrame.Position.Z + 0.8) < 0.001, "second cabinet slides by same relative offset")

-- Real mouse routing/highlight sends one Drink intent through the central server.
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
		return Roblox.Vector2.new(200, 200)
	end,
}
world.CurrentCamera = {
	ViewportSize = Roblox.Vector2.new(800, 600),
	ScreenPointToRay = function()
		return { Origin = head.Position, Direction = Roblox.Vector3.new(0, 0, -1) }
	end,
}
local target = bottle
world.Raycast = function()
	return target and { Instance = target, Position = target.Position } or nil
end
local template, calls = instance("Highlight", "SelectionHighlight"), 0
template.FillTransparency = 0.8
local router = h:load("src/GClient/Interactions/TaggedInteraction.luau").new({
	player = player,
	input = input,
	workspace = world,
	collection = collection,
	config = h:load("src/GShared/Containers/ContainerConfig.luau"),
	locked = function()
		return false
	end,
	blocked = function()
		return false
	end,
	hover = function() end,
	template = function()
		return template
	end,
	remote = {
		InvokeServer = function(_, action, payload)
			calls += 1
			return service:Request(player, action, payload)
		end,
	},
})
router:Update()
check(
	router.highlight.Parent == bottle and router.highlight.FillTransparency == 0.8,
	"drink hover clones authored selection highlight"
)
h.time += 0.2
input.InputBegan:Fire({ UserInputType = Roblox.Enum.UserInputType.MouseButton1 }, false)
h:drain()
check(
	calls == 1 and bottle:GetAttribute("DPU_DrinkBusy") and router.highlight.Parent == nil,
	"click routes drink request and releases highlight before deletion"
)
input.InputBegan:Fire({ UserInputType = Roblox.Enum.UserInputType.MouseButton1 }, false)
h:drain()
check(calls == 1, "busy drink cannot send another click")
tweens[#tweens]:Finish()
check(bottle.Parent == nil, "mouse-to-server drink flow finishes deletion")
target = nil
router:Update()
router:Destroy()
fax.Destroying:Fire()
check(service.bindings.items[fax] == nil, "destroyed tagged model releases registry connections")
service:Shutdown()
check(
	drawer:GetAttribute("DPU_ContainerId") == nil and drawer2:GetAttribute("DPU_ContainerId") == nil,
	"central shutdown clears every cabinet"
)
print(string.format("PASS: %d central tag and drinking checks (mocked Roblox).", total))
