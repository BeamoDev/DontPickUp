local Harness = require("./Harness")
local Fixture = require("./TagFixture")
local Roblox = require("@lune/roblox")
local h, total = Harness.Environment(), 0
local function check(value, label)
	assert(value, label)
	total += 1
end
for _, name in ipairs({ "Vector3", "Vector2", "CFrame", "Color3", "UDim2" }) do
	h.env[name] = Roblox[name]
end
local V, C = Roblox.Vector3, Roblox.CFrame
h.env.Enum, h.env.RaycastParams = Roblox.Enum, {
	new = function()
		return {}
	end,
}
h.env.TweenInfo = {
	new = function()
		return {}
	end,
}
local function bounds(model)
	local low, high = V.one * math.huge, -V.one * math.huge
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			for _, x in ipairs({ -0.5, 0.5 }) do
				for _, y in ipairs({ -0.5, 0.5 }) do
					for _, z in ipairs({ -0.5, 0.5 }) do
						local point = part.CFrame:PointToWorldSpace(part.Size * V.new(x, y, z))
						low, high = low:Min(point), high:Max(point)
					end
				end
			end
		end
	end
	return C.new((low + high) / 2), high - low
end
local function instance(class, name, parent)
	local item = h.instance(class)
	item.Name, item.Parent = name or class, parent
	item.AncestryChanged, item.Destroying = Fixture.Signal(), Fixture.Signal()
	local signals = {}
	item.GetPropertyChangedSignal = function(_, key)
		signals[key] = signals[key] or Fixture.Signal()
		return signals[key]
	end
	if class == "Part" then
		item.CFrame, item.Position, item.Size, item.Transparency = C.new(), V.zero, V.one, 0
		item.GetConnectedParts = function()
			return {}
		end
	elseif class == "Model" then
		item.GetBoundingBox = bounds
		item.GetPivot = function(self)
			return self.WorldPivot or C.new()
		end
	end
	return item
end
h.env.Instance.new = instance
local world, storage, serverStorage = instance("Workspace"), instance("ReplicatedStorage"), instance("ServerStorage")
require("./CustomerFixture").Build(h, storage)
local collection = Fixture.Collection()
local blocked = false
local wall = instance("Part", "Wall", world)
wall.CanCollide = true
world.Raycast = function()
	return blocked and { Instance = wall, Position = V.zero } or nil
end
local marker = instance("Part", "OrderBenchOrigin", world)
marker.CFrame = C.new(0, 0, 0)
local tweenService = {}
function tweenService:Create(target, _, goals)
	local tween = { Completed = Fixture.Signal() }
	function tween:Play()
		for key, value in pairs(goals) do
			target[key] = value
			target:GetPropertyChangedSignal(key):Fire()
		end
	end
	function tween:Cancel()
		self.cancelled = true
	end
	return tween
end
local studio = true
local services = {
	Workspace = world,
	ReplicatedStorage = storage,
	ServerStorage = serverStorage,
	Players = h.players,
	CollectionService = collection,
	TweenService = tweenService,
	RunService = {
		IsStudio = function()
			return studio
		end,
		Heartbeat = Fixture.Signal(),
	},
	HttpService = {
		GenerateGUID = function()
			h.serial += 1
			return "test-" .. h.serial
		end,
	},
}
-- Imported NPCs use a +X calibrated heading after their authored rotation.
do
	local Actor = h:load("src/GServer/Customers/CustomerActor.luau")
	local npc = Actor.new(services, world, C.new(10, 2, 20), {})
	local rotation = C.fromOrientation(math.rad(90), math.rad(180), 0)
	local function nearRotation(a, b)
		return (a.RightVector - b.RightVector).Magnitude < 0.0001
			and (a.UpVector - b.UpVector).Magnitude < 0.0001
			and (a.LookVector - b.LookVector).Magnitude < 0.0001
	end
	check(nearRotation(npc.driver.Value, rotation), "NPC defaults to authored 90,180,0 pose")
	local height = npc.heightOffset
	for _, direction in ipairs({ V.xAxis, -V.xAxis, V.zAxis, -V.zAxis, V.new(1, 0, 1).Unit }) do
		local start = npc.driver.Value.Position
		local floor = V.new(start.X, 2, start.Z) + direction * 8
		npc:MoveTo(C.new(floor), 2)
		local heading = npc.driver.Value.Rotation * rotation:Inverse()
		check(
			heading.RightVector:Dot(direction) > 0.9999,
			"calibrated +X faces travel, including departure and diagonal routes"
		)
		check(math.abs(npc.driver.Value.Position.Y - (2 + height)) < 0.0001, "turns preserve floor grounding")
	end
	local previous = npc.tween
	npc:MoveTo(C.new(1, 2, 3), 0)
	check(
		previous.cancelled and npc.tween == nil and nearRotation(npc.driver.Value, rotation),
		"instant placement cancels old movement and restores authored marker pose"
	)
	npc:Destroy()
	check(npc.model.Parent == nil, "actor cleanup still removes owned NPC")
end
local config = h:load("src/LServer/Configuration/ServerConfig.luau")
local data = h:load("src/LServer/PlayerData/DataService.luau").new(services, config)
local player, other = h:player(1), h:player(2)
local function character(who)
	local model = instance("Model", "Character", world)
	who.Character = model
	local root = instance("Part", "HumanoidRootPart", model)
	root.CFrame, root.Position = C.new(0, 3, 3.7), V.new(0, 3, 3.7)
	local head = instance("Part", "Head", model)
	head.CFrame, head.Position = C.new(0, 5, 3.7), V.new(0, 5, 3.7)
	local humanoid = instance("Humanoid", "Humanoid", model)
	humanoid.Health, humanoid.Sit = 100, false
	return root, head, humanoid
end
local root, head, humanoid = character(player)
character(other)
data:Load(player)
data:Load(other)
local interactions = h:load("src/GServer/Interaction/InteractionService.luau").new(services, function(who)
	return data:IsReady(who)
end)
local packets, busy = {}, false
local Orders = h:load("src/GServer/Orders/BenchOrderService.luau")
local orders = Orders.new(services, {
	data = data,
	repairs = interactions.repairs,
	busy = function()
		return busy
	end,
	changed = function(state, lines)
		table.insert(packets, { state, lines })
	end,
})
local function tick(seconds)
	h.time += seconds
	orders:Tick()
end
local function request(who, payload)
	return orders:Request(
		who or player,
		"ServeCustomer",
		payload or { Id = orders.order.id, Revision = orders.revision }
	)
end
check(
	orders.station.generated and world:FindFirstChild("DPU_OrderTestBench"),
	"Studio creates only its isolated test bench"
)
local bench, actor = orders.station.model, nil
check(orders:Request(player, "GetOrderState", {}).Order.Stage == "Idle", "late join reads current snapshot")
orders:Tick()
tick(3)
actor = orders.station.actor.model
check(orders.stage == "Arriving" and collection:HasTag(actor, "Customer"), "arrival creates a tagged customer")
check(actor.Name == orders.order.customer.Name and actor:GetAttribute("DPU_CustomerName") == actor.Name, "world customer carries its actual ticket name")
check(orders:Snapshot().AppearanceId == actor:GetAttribute("DPU_AppearanceId"), "order snapshot retains the chosen model")
check(not request().Ok, "cannot accept a customer while arriving")
tick(3)
check(
	orders.stage == "Waiting" and actor:GetAttribute("DPU_OrderRevision") == orders.revision,
	"arrival becomes available with matching revision"
)
local stale = { Id = orders.order.id, Revision = orders.revision }
blocked = true
check(request().Code == "OutOfReach", "actual wall blocks handoff")
blocked = false
root.Position = V.new(50, 3, 3.7)
check(request().Code == "OutOfReach", "distance blocks remote handoff")
root.Position = V.new(0, 3, 3.7)
humanoid.Health = 0
check(not request().Ok, "dead employee cannot accept")
humanoid.Health, humanoid.Sit = 100, true
check(not request().Ok, "seated employee cannot accept")
humanoid.Sit, busy = false, true
check(not request().Ok, "held prop or active repair blocks order action")
busy = false
check(request().Ok and orders.stage == "Repairing", "accept creates one assigned repairable phone")
local phone = orders.order.phone
check(
	not request(other, stale).Ok and orders.order.phone == phone,
	"simultaneous stale accept cannot duplicate the phone"
)
check(packets[#packets][2][1].Speaker == "Customer", "accept uses existing dialogue with customer greeting")
check(packets[#packets][2][1].DisplayName == actor.Name and packets[#packets][2][1].AppearanceId == orders.order.appearanceId, "greeting includes exact name and appearance for portrait")
local rig = h:load("src/GShared/Repair/RepairRig.luau").Read(phone)
check(rig and #rig.parts == 32, "generated phone satisfies the real repair rig contract")
check(rig.screen.Position.Y > rig.keys.BackCover.Position.Y, "test phone starts with screen facing up")
check(not request().Ok, "return is unavailable until a repair actually finishes")
phone:SetAttribute("DPU_RepairStage", "Complete")
orders:Completed(phone)
check(orders.stage == "Repairing", "replicated completion attribute alone cannot grant order progress")
phone:SetAttribute("DPU_RepairStage", "Idle")
-- Use real Begin, disassembly, wire validation, assembly and Finish for this order.
local repair = interactions.repairs
local begin = repair:Request(player, "BeginRepair", { Id = orders.order.repairId })
check(begin.Ok, "generated phone can enter the real inspection repair service")
local session = repair.sessions[player]
h.time += session.motion.duration + 0.1
repair:Tick(5)
check(session.stage == "Wires", "test bench phone disassembles into wire stage")
local definition = h:load("src/GShared/Repair/RepairDefinition.luau")
local function install(key, target)
	local grab = repair:Request(player, "RepairGrab", { Token = session.token, Revision = session.revision, Key = key })
	check(grab.Ok, "grab allowed: " .. key)
	local position = session.motion.plane:PointToObjectSpace(session.motion.slots[target or key].Position)
	local result = repair:Request(player, "RepairDrop", {
		Token = grab.Token,
		Revision = session.revision,
		X = position.X / session.motion.half.X,
		Y = position.Z / session.motion.half.Y,
	})
	check(result.Ok, "validated drop: " .. key)
	h.time += 0.5
	repair:Tick(0.5)
end
for _, pair in ipairs(definition.Pairs) do
	install(pair.From, pair.To)
end
install("Battery")
install("BackCover")
for i = 1, 4 do
	install("Screw" .. i)
end
h.time += 0.7
repair:Tick(0.7)
check(
	orders.stage == "Ready" and repair:IsComplete(phone, orders.order.repairId),
	"real repair completion automatically makes only this order ready"
)
check(data:Get(player).Stats.Credits == 0, "completion alone has no payment")
local returnPayload = { Id = orders.order.id, Revision = orders.revision }
local receipt = "Order_" .. orders.order.id
check(request().Ok and orders.stage == "Leaving", "return settles and starts departure")
check(
	data:Get(player).Stats.Credits == 10 and data:Get(other).Stats.Credits == 10,
	"present loaded crew receives fixed payment"
)
check(
	data:Get(player).Stats.CasesSolved == 1
		and data:Get(player).Stats.Deaths == 0
		and data:Get(player).Stats.ShiftsSurvived == 0,
	"order payment does not finish a shift or count a death"
)
check(
	not request(other, returnPayload).Ok and data:Get(other).Stats.Credits == 10,
	"simultaneous duplicate return cannot pay twice"
)
check(
	data:RecordOrderPayment(player, receipt) and data:Get(player).Stats.Credits == 10,
	"profile receipt is idempotent independently of order state"
)
data:Remove(other)
check(
	data:Load(other) and data:Get(other).Stats.Credits == 10,
	"payment survives profile save and reload in the practice store"
)
check(
	data:RecordOrderPayment(other, receipt) and data:Get(other).Stats.CasesSolved == 1,
	"saved receipt prevents another payment after reload"
)
check(not data:RecordOrderPayment(player, "bad receipt"), "malformed internal receipt is rejected")
check(
	phone.Parent == nil and not collection:HasTag(phone, "PhoneRepair"),
	"returned phone and repair binding are cleaned up"
)
tick(3)
check(orders.stage == "Idle" and actor.Parent == nil, "customer leaves and owned actor is removed")
tick(6)
tick(3)
check(orders.number == 2 and orders.stage == "Waiting", "next customer starts after bounded pause")
check(request(other).Ok, "another employee can start the next order")
player.Parent = nil
orders:Tick()
check(orders.stage == "Repairing", "one employee leaving does not cancel the remaining crew's order")
player.Parent = h.players
local lost = orders.order.phone
collection:RemoveTag(lost, "PhoneRepair")
collection:AddTag(lost, "PhoneRepair")
orders:Tick()
check(orders.stage == "Idle" and lost.Parent == nil, "repair binding replacement invalidates outstanding order")
tick(3)
tick(3)
orders.station.actor.model.Parent = nil
orders.station.actor.model.AncestryChanged:Fire()
orders:Tick()
check(orders.stage == "Idle", "missing customer resets order without reward")
tick(3)
tick(3)
player.Parent, other.Parent = nil, nil
orders:Tick()
check(not orders.order and orders.stage == "Idle", "empty crew cancels order and pauses arrivals")
check(not orders:Request(player, "GetOrderState", {}).Ok, "departed player cannot call order endpoints")
orders:Shutdown()
check(
	bench.Parent == nil and marker.Parent == world and repair.completed == nil,
	"shutdown deletes owned bench only and releases completion callback"
)
interactions:Shutdown()
-- Shipping places cannot accidentally create test geometry.
studio = false
local Station = h:load("src/GServer/Orders/BenchOrderStation.luau")
local catalog = h:load("src/GServer/Orders/BenchOrderCatalog.luau")
check(Station.new(services, catalog) == nil, "live place with no authored station stays disabled")
local authored = instance("Model", "RepairOrderStation", world)
for _, name in ipairs({ "CustomerStart", "CustomerStand", "PhoneSpot" }) do
	instance("Part", name, authored)
end
local production = Station.new(services, catalog)
check(production and not production.generated, "authored station activates without generated world geometry")
local missing, why = production:CreatePhone("authored-order")
check(not missing and why == "MissingPhoneTemplate", "published station requires an authored phone template")
local assets = instance("Folder", "Assets", serverStorage)
local template = h:load("src/GServer/Orders/BenchOrderTestBench.luau").Phone()
template.Name, template.Parent, template.Archivable = "OrderPhone", assets, false
local sourceScript = instance("Script", "OldScript", template)
local authoredPhone = production:CreatePhone("authored-order")
check(
	authoredPhone and authoredPhone ~= template and template.Archivable == false,
	"non-archivable authored template is cloned while preserving source settings"
)
check(
	not authoredPhone:FindFirstChild("OldScript") and sourceScript.Parent == template,
	"only cloned scripts are stripped"
)
production:Destroy()
check(
	authored.Parent == world and template.Parent == assets and authoredPhone.Parent == nil,
	"production teardown preserves authored station and template"
)

-- Client snapshots may race with the initial fetch. Conversations play once.
local renderCount, conversations, notice = 0, 0, nil
local view = {
	Render = function()
		renderCount += 1
	end,
	Notice = function(_, value)
		notice = value
	end,
	Destroy = function() end,
}
local Controller = h:load("src/GClient/Interface/OrderController.luau", {
	["src/GClient/Interface/OrderView.luau"] = {
		new = function()
			return view
		end,
	},
})
local changed = { OnClientEvent = Fixture.Signal() }
local controller = Controller.new({
	changed = changed,
	remote = {
		InvokeServer = function()
			return { Ok = true, Order = { Revision = 1 } }
		end,
	},
	dialogue = {
		Play = function()
			conversations += 1
		end,
	},
})
changed.OnClientEvent:Fire({ Revision = 3 }, { { Speaker = "Customer", Text = "Hello" } })
h:drain()
changed.OnClientEvent:Fire({ Revision = 3 }, {})
changed.OnClientEvent:Fire({ Revision = 2 }, {})
check(
	renderCount == 1 and conversations == 1,
	"stale fetch and duplicate packets neither regress ticket nor replay dialogue"
)
controller:Response({ Ok = false, Code = "OutOfReach" })
check(notice ~= nil, "rejected action gives visible feedback")
controller:Destroy()
changed.OnClientEvent:Fire({ Revision = 4 }, {})
check(renderCount == 1, "destroy disconnects order event")
print(
	string.format(
		"PASS: %d customer, bench, real repair/order integration, payment and client ordering checks (mocked Roblox).",
		total
	)
)
