local Harness = require("./Harness")
local Fixture = require("./TagFixture")
local Roblox = require("@lune/roblox")
local h, total = Harness.Environment(), 0
local function check(value, message)
	assert(value, message)
	total += 1
end
for _, name in ipairs({ "Vector3", "Vector2", "CFrame" }) do
	h.env[name] = Roblox[name]
end
h.env.Enum = Roblox.Enum
h.env.RaycastParams = {
	new = function()
		return {}
	end,
}
h.env.TweenInfo = {
	new = function(seconds, style, direction)
		return { seconds, style, direction }
	end,
}
local signal = Fixture.Signal
local world, folder = h.instance("Workspace"), h.instance("Model")
folder.Parent, folder.ChildAdded, folder.ChildRemoved = world, signal(), signal()
local function part(name, x)
	local item = h.instance("Part")
	item.Name, item.Parent = name, folder
	item.CFrame = Roblox.CFrame.new(x, 0, 0) * Roblox.CFrame.Angles(0, 0.3, 0)
	item.Position, item.Size = item.CFrame.Position, Roblox.Vector3.one
	item.Anchored, item.CanQuery = true, true
	item.GetConnectedParts = function()
		return item.connected or {}
	end
	return item
end
local a, b, label1, label2, cover =
	part("Box1", 0), part("Box2", 2), part("Label1", 0.2), part("Label2", 2.2), part("Covers", 3)
local original1, original2, coverFrame = label1.CFrame, label2.CFrame, cover.CFrame
local tweens = {}
world.Raycast = function()
	return nil
end
local services = {
	Workspace = world,
	Players = h.players,
	HttpService = {
		GenerateGUID = function()
			h.serial += 1
			return tostring(h.serial)
		end,
	},
	TweenService = {
		Create = function(_, target, info, goal)
			local tween = { info = info, goal = goal, start = target.CFrame, Completed = signal() }
			function tween:Play()
				self.played = true
			end
			function tween:Cancel()
				self.cancelled = true
			end
			function tween:At(alpha)
				if self.cancelled then
					return
				end
				target.CFrame = self.start:Lerp(goal.CFrame, alpha)
				target.Position = target.CFrame.Position
			end
			function tween:Finish()
				self:At(1)
				self.Completed:Fire()
			end
			tweens[target] = tween
			return tween
		end,
	},
}
local server = h:load("src/GServer/Interaction/ContainerService.luau").new(services, function()
	return true
end)
server:Bind(folder)
local player = h:player(1)
player.Character = h.instance("Model")
local root, head, humanoid = h.instance("Part"), h.instance("Part"), h.instance("Humanoid")
root.Name, root.Position, root.Parent = "HumanoidRootPart", Roblox.Vector3.new(0, 0, 3), player.Character
head.Name, head.Position, head.Parent = "Head", Roblox.Vector3.new(0, 2, 3), player.Character
humanoid.Health, humanoid.Sit, humanoid.Parent = 100, false, player.Character
local function click(box)
	h.time += 0.2
	return server:Request(
		player,
		{ Id = box:GetAttribute("DPU_ContainerId"), Revision = box:GetAttribute("DPU_ContainerRevision") }
	)
end
check(click(a).Ok and tweens[a].played and tweens[label1].played, "Box1 and Label1 start together")
check(
	tweens[a].info[1] == tweens[label1].info[1]
		and tweens[a].info[2] == tweens[label1].info[2]
		and tweens[a].info[3] == tweens[label1].info[3],
	"label uses identical duration and easing"
)
tweens[a]:At(0.5)
tweens[label1]:At(0.5)
check(
	(label1.Position - original1.Position - Roblox.Vector3.new(0, 0, -0.4)).Magnitude < 0.001,
	"label follows halfway through the slide"
)
check(label2.CFrame == original2 and cover.CFrame == coverFrame, "other labels and covers remain untouched")
tweens[a]:Finish()
check(
	(label1.CFrame.Position - original1.Position - Roblox.Vector3.new(0, 0, -0.8)).Magnitude < 0.001,
	"label reaches matching open displacement"
)
check((label1.CFrame.LookVector - original1.LookVector).Magnitude < 0.001, "label keeps authored rotation")
check(click(a).Ok, "paired close accepted")
tweens[a]:Finish()
check((label1.CFrame.Position - original1.Position).Magnitude < 0.001, "paired close restores exact original position")
check(click(b).Ok and tweens[label2].played, "Box2 selects Label2 independently")
tweens[b]:Finish()
check(
	(label2.CFrame.Position - original2.Position - Roblox.Vector3.new(0, 0, -0.8)).Magnitude < 0.001
		and (label1.CFrame.Position - original1.Position).Magnitude < 0.001,
	"second drawer does not move first label"
)
click(a)
local cancelledLabel = tweens[label1]
tweens[a]:At(0.5)
cancelledLabel:At(0.5)
server:Unbind(folder)
check(
	cancelledLabel.cancelled and (label1.CFrame.Position - original1.Position).Magnitude < 0.001,
	"unbinding cancels label tween and restores its closed position"
)

label2.Anchored, label2.connected = false, { b }
tweens[label2] = nil
server:Bind(folder)
click(b)
check(
	tweens[label2] == nil and not label2.Anchored,
	"unanchored welded label follows box without fighting a second tween"
)
tweens[b]:Finish()
server:Unbind(folder)
label2.connected, label2.Anchored = nil, true
label1.Anchored = false
server:Bind(folder)
click(a)
check(label1.Anchored and tweens[label1].played, "loose label is held stable against gravity during sliding")
server:Unbind(folder)
check(not label1.Anchored, "cleanup restores original label anchoring")
label1.Parent = nil
server:Bind(folder)
check(click(a).Ok, "missing label never prevents drawer motion")
tweens[a]:Finish()
server:Shutdown()
print(string.format("PASS: %d paired drawer-label checks (mocked Roblox).", total))
