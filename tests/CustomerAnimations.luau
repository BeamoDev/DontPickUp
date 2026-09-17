local Harness = require("./Harness")
local Fixture = require("./TagFixture")
local Roblox = require("@lune/roblox")
local h, total = Harness.Environment(), 0
local function check(value, label)
	assert(value, label)
	total += 1
end
for _, key in ipairs({ "Vector3", "CFrame", "Color3" }) do
	h.env[key] = Roblox[key]
end
h.env.Enum = Roblox.Enum
h.env.TweenInfo = { new = function() return {} end }
require("./CustomerFixture").Install(h)
local make = h.env.Instance.new
h.env.Instance.new = function(class)
	local item = make(class)
	if class == "Animator" then
		item.LoadAnimation = function(_, animation)
			local track = { id = animation.AnimationId }
			function track:Play() self.playing = true end
			function track:Stop() self.playing = false end
			function track:Destroy() self.destroyed = true end
			return track
		end
	end
	return item
end
local function node(class, name, parent)
	local item = h.env.Instance.new(class)
	item.Name, item.Parent = name, parent
	return item
end
local storage = node("ReplicatedStorage", "ReplicatedStorage")
local legacy = require("./CustomerFixture").Build(h, storage)
local Templates = h:load("src/GShared/Customers/CustomerTemplates.luau")
local Animations = h:load("src/GShared/Customers/CustomerAnimations.luau")
check(#Templates.List(storage) == 3, "legacy customers remain a migration fallback")
local characters = node("Folder", "Characters", storage.Assets)
local female, male = node("Folder", "Female", characters), node("Folder", "Male", characters)
local models = legacy:GetChildren()
models[1].Parent, models[2].Parent = female, male -- Deliberately identical model names.
node("Model", "Empty", female)
node("Folder", "NotARig", male)
local Actor = h:load("src/GServer/Customers/CustomerActor.luau")
local prepared = Actor.PrepareTemplates(storage)
check(#prepared == 2, "all valid rigs from both character folders selected; old NPC pool excluded")
check(prepared[1] == models[1] and prepared[2] == models[2], "unequal folder populations use one flattened pool")
check(Templates.Gender(models[1]) == "Female" and Templates.Gender(models[2]) == "Male", "folder selects correct animation set")
check(models[1]:GetAttribute(Templates.Attribute) ~= models[2]:GetAttribute(Templates.Attribute), "duplicate names get distinct appearance IDs")
for _, model in ipairs(prepared) do
	check(Templates.Find(storage, model:GetAttribute(Templates.Attribute)) == model, "exact appearance resolves for pickup and portraits")
end
check(Templates.Find(storage, "missing") == nil, "missing identity never silently chooses another person")
for index = 1, 2 do
	h.env.math = table.clone(math)
	h.env.math.random = function(low, high)
		check(low == 1 and high == 2, "random appearance draw spans every available character")
		return index
	end
	local selector = h:load("src/GShared/Customers/CustomerTemplates.luau")
	check(selector.Find(storage) == models[index], "either folder can supply the random customer")
end
h.env.math = math
local count = 0
for _, gender in ipairs({ "Female", "Male" }) do
	for name, id in pairs(Animations[gender]) do
		count += 1
		check(Animations.Has(name) and id:match("^%d+$") and Animations.Get(gender, name) == id, "catalog resolves " .. gender .. " " .. name)
	end
end
check(count == 30, "all 18 female and 12 male animation assets stored")
check(Animations.Get("Female", "Running") == "124881471754162", "female running never uses male rig asset")
check(Animations.Get("Male", "Idle") == "99979548599754", "male has safe idle fallback")
check(not Animations.Has("MadeUp"), "unknown animation rejected")
local world = node("Workspace", "Workspace")
local services = { ReplicatedStorage = storage, CollectionService = Fixture.Collection(), TweenService = {} }
function services.TweenService:Create(target, _, goals)
	local tween = { Completed = Fixture.Signal() }
	function tween:Play() target.Value = goals.Value end
	function tween:Cancel() self.cancelled = true end
	return tween
end
for index, gender in ipairs({ "Female", "Male" }) do
	local model = models[index]
	node("AnimationController", "AnimationController", model)
	model:SetAttribute("CustomerWalkAnimation", "NormalWalking")
	model:SetAttribute("CustomerIdleAnimation", "HappyIdle")
	local actor = Actor.new(services, world, Roblox.CFrame.new(), { Template = model, CustomerName = "Test Resident" })
	check(actor.model.Name == "Test Resident" and actor.model:GetAttribute("DPU_CustomerName") == "Test Resident", "world name matches ticket")
	check(actor.track.id == "rbxassetid://" .. Animations[gender].HappyIdle and actor.track.playing, "world idle plays on " .. gender .. " rig")
	local old = actor.track
	actor:MoveTo(Roblox.CFrame.new(10, 0, 0), 3)
	check(old.destroyed and not old.playing, "old idle is cleaned up at walk start")
	check(actor.track.id == "rbxassetid://" .. Animations[gender].NormalWalking and actor.track.Priority == Roblox.Enum.AnimationPriority.Movement, "movement uses matching walk and priority")
	local walking = actor.track
	actor.tween.Completed:Fire(Roblox.Enum.PlaybackState.Completed)
	check(walking.destroyed and actor.track.id == "rbxassetid://" .. Animations[gender].HappyIdle, "arrival returns to the same idle")
	local idle = actor.track
	actor:Destroy()
	check(idle.destroyed and not idle.playing and model.Parent ~= nil, "cleanup releases animation and preserves authored rig")
end
local dialogue = h:load("src/GServer/Story/DialogueService.luau").new()
dialogue:Start("run", { { Speaker = "Mara", Text = "Thank you.", Animation = "HeadNodAgree", AppearanceId = "npc_1" } }, 0)
check(dialogue.Current.Animation == "HeadNodAgree" and dialogue.Current.Speaker == "Mara", "server dialogue preserves selected emotion and real name")
print(string.format("PASS: %d customer folder, identity and animation checks (mocked Roblox).", total))
