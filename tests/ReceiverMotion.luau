local Harness = require("./Harness")
local Roblox = require("@lune/roblox")
local Fixture = require("./TagFixture")
local h, total = Harness.Environment(), 0
local function check(value, label)
	assert(value, label)
	total += 1
end
h.env.Vector3, h.env.CFrame = Roblox.Vector3, Roblox.CFrame
local world, model = h.instance("Workspace"), h.instance("Model")
model.Parent = world
local pivot = Roblox.CFrame.new(2, 3, 4)
model.GetPivot = function()
	return pivot
end
local phone = h.instance("Part")
phone.Name, phone.Parent, phone.CFrame = "Phone", model, pivot * Roblox.CFrame.new(0, 1, 0)
phone.LocalTransparencyModifier, phone.CanCollide, phone.Anchored = 0.25, true, true
phone.GetPivot = function()
	return phone.CFrame
end
local joint = h.instance("WeldConstraint")
joint.Parent = phone
local script = h.instance("LuaSourceContainer")
script.Parent = phone
local collection, reduced = Fixture.Collection(), false
local motion = h:load("src/GClient/Effects/ReceiverMotion.luau").new({
	workspace = world,
	collection = collection,
	reduced = function()
		return reduced
	end,
})
local camera = { CFrame = Roblox.CFrame.new(0, 5, -4) }
local home = phone.CFrame
motion:Raise(model, camera)
check(
	phone.CFrame == home and phone.LocalTransparencyModifier == 1,
	"receiver hides locally without moving authored welds"
)
check(joint.Parent == phone and script.Parent == phone, "authored joints and scripts remain untouched")
check(
	motion.visual and motion.visual.Anchored and not motion.visual.CanQuery and not motion.visual.CanCollide,
	"visual clone cannot collide or steal clicks"
)
check(#motion.visual:GetChildren() == 0, "clone excludes scripts and joints before entering Workspace")
h.time += 0.175
motion:Update()
check(motion.visual.CFrame ~= home, "receiver animates upward rather than instantly disappearing")
h.time += 0.2
motion:Update()
check(
	camera.CFrame:PointToObjectSpace(motion.visual.Position or motion.visual.CFrame.Position).Z > 0,
	"picked-up visual finishes behind camera"
)
motion:Lower()
check(
	motion.visual ~= nil and phone.LocalTransparencyModifier == 1,
	"hangup begins visible return before restoring original"
)
pivot += Roblox.Vector3.new(1, 0, 0)
h.time += 0.4
motion:Update()
check(
	motion.visual == nil and not motion.lowering and phone.LocalTransparencyModifier == 0.25 and phone.CFrame == home,
	"return cleans local copy and restores exact transparency"
)
motion:Raise(model, camera)
motion:Lower(true)
check(not motion.visual and phone.LocalTransparencyModifier == 0.25, "teardown immediately restores hidden receiver")
motion:Raise(model, camera)
model.Parent = nil
motion:Update()
check(not motion.visual and phone.LocalTransparencyModifier == 0.25, "removed telephone cleans the receiver copy")
model.Parent = world
reduced = true
motion:Raise(model, camera)
motion:Lower()
check(not motion.visual and phone.LocalTransparencyModifier == 0.25, "reduced motion restores immediately")
phone:Destroy()
local receiver = h.instance("Model")
receiver.Name, receiver.Parent = "Phone", model
receiver.GetPivot = function()
	return pivot
end
for i = 1, 2 do
	local part = h.instance("Part")
	part.Parent, part.CFrame, part.LocalTransparencyModifier = receiver, pivot * Roblox.CFrame.new(i, 0, 0), 0
end
motion:Raise(model, camera)
check(#motion.parts == 2, "multi-part receiver moves as one visual without requiring a PrimaryPart")
motion:Lower(true)
print(string.format("PASS: %d local receiver animation and cleanup checks (mocked Roblox).", total))
