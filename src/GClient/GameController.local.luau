local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local input = game:GetService("UserInputService")
local guiService = game:GetService("GuiService")
local collection = game:GetService("CollectionService")
local player = Players.LocalPlayer
local net = ReplicatedStorage:WaitForChild("DontPickUpGameNet", 30)
if not net then
	return
end
while net:GetAttribute("PrototypeEnabled") == nil do
	net:GetAttributeChangedSignal("PrototypeEnabled"):Wait()
end
if net:GetAttribute("PrototypeEnabled") ~= false then
	return
end
local remote = net:WaitForChild("Request", 10)
if not remote then
	return
end
local Shared = ReplicatedStorage:WaitForChild("GShared", 30)
assert(Shared, "Sync src/GShared to ReplicatedStorage.GShared")
local Config = require(Shared:WaitForChild("Containers", 30):WaitForChild("ContainerConfig", 30))
local TaggedInteraction = require(script.Parent.Interactions.TaggedInteraction)
local Tags = require(Shared:WaitForChild("Interactions", 30):WaitForChild("InteractionTags", 30))
local TelephoneConfig = require(Shared:WaitForChild("Telephone", 30):WaitForChild("TelephoneConfig", 30))
local TelephoneInteraction = require(script.Parent.Telephone.TelephoneInteraction)
local FirstPersonCamera = require(script.Parent.Interactions.FirstPersonCamera)
local ModelInspection = require(script.Parent.Interactions.ModelInspection)
local ThrowInteraction = require(script.Parent.Interactions.ThrowInteraction)
local ThrowConfig = require(Shared.Interactions.ThrowConfig)
local playerGui = player:WaitForChild("PlayerGui")
local gui = Instance.new("ScreenGui")
gui.Name, gui.ResetOnSpawn, gui.Parent = "DPU_GameInteractions", false, playerGui
local function needsPointer()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local camera = workspace.CurrentCamera
	return not humanoid
		or humanoid.Health <= 0
		or humanoid.Sit
		or playerGui:GetAttribute("DPU_ModalOpen") == true
		or (camera ~= nil and camera.CameraType == Enum.CameraType.Scriptable)
end
local function reduced()
	local data = player:FindFirstChild("PlayerData")
	local settings = data and data:FindFirstChild("Settings")
	local flashes = settings and settings:FindFirstChild("ReducedFlashes")
	return guiService.ReducedMotionEnabled or (flashes ~= nil and flashes.Value == true)
end
local cursor = FirstPersonCamera.new(gui, player, input, {
	render = RunService,
	menuOpen = function()
		return guiService.MenuIsOpen
	end,
	needsPointer = needsPointer,
})
local warned = false
local function highlightTemplate()
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local template = (assets and assets:FindFirstChild("SelectionHighlight"))
		or ReplicatedStorage:FindFirstChild("SelectionHighlight")
	if (not template or not template:IsA("Highlight")) and not warned then
		warned = true
		warn("[DPU][Interactions] Put your SelectionHighlight in ReplicatedStorage.Assets")
	end
	return template
end
local close = Instance.new("TextButton")
close.Name, close.Text = "CloseInspection", "CLOSE [Q / B]"
close.Size, close.Position, close.AnchorPoint =
	UDim2.fromOffset(220, 44), UDim2.new(0.5, 0, 1, -28), Vector2.new(0.5, 1)
close.BackgroundColor3, close.BackgroundTransparency = Color3.new(0, 0, 0), 0.5
close.TextColor3, close.TextSize, close.Font = Color3.fromRGB(235, 230, 214), 16, Enum.Font.Code
close.BorderSizePixel, close.Selectable, close.Visible, close.Parent = 0, false, false, gui
local telephone = TelephoneInteraction.new({
	collection = collection,
	player = player,
	input = input,
	workspace = workspace,
	config = TelephoneConfig,
	tweens = game:GetService("TweenService"),
	render = RunService,
	reduced = reduced,
	menuOpen = function()
		return guiService.MenuIsOpen
	end,
	modalOpen = function()
		return playerGui:GetAttribute("DPU_ModalOpen") == true
	end,
	template = highlightTemplate,
	active = function(active)
		close.Text = "CLOSE PHONE [Q / B]"
		close.Visible = active
	end,
})
local interaction
local charge = Instance.new("Frame")
charge.Name, charge.Size, charge.Position, charge.AnchorPoint =
	"ThrowCharge", UDim2.fromOffset(200, 6), UDim2.new(0.5, 0, 1, -80), Vector2.new(0.5, 1)
charge.BackgroundColor3, charge.BackgroundTransparency, charge.BorderSizePixel = Color3.new(0, 0, 0), 0.4, 0
charge.Visible, charge.Parent = false, gui
local fill = Instance.new("Frame")
fill.Name, fill.Size, fill.BackgroundColor3, fill.BorderSizePixel, fill.Parent =
	"Power", UDim2.fromScale(0, 1), Color3.fromRGB(232, 220, 180), 0, charge
local chargeLabel = Instance.new("TextLabel")
chargeLabel.Size, chargeLabel.Position, chargeLabel.BackgroundTransparency =
	UDim2.new(1, 0, 0, 22), UDim2.fromOffset(0, -26), 1
chargeLabel.Font, chargeLabel.TextSize, chargeLabel.TextColor3, chargeLabel.Parent =
	Enum.Font.Code, 14, Color3.fromRGB(235, 230, 214), charge
local throwing = ThrowInteraction.new({
	player = player,
	input = input,
	workspace = workspace,
	collection = collection,
	remote = remote,
	config = ThrowConfig,
	render = RunService,
	locked = function()
		return cursor:IsLocked()
	end,
	blocked = function()
		return guiService.MenuIsOpen or needsPointer()
	end,
	meter = function(active, power, label)
		if not charge.Parent then
			return
		end
		charge.Visible = active
		fill.Size = UDim2.fromScale(power, 1)
		chargeLabel.Text = power >= 1 and "FULL POWER - RELEASE" or label or ""
	end,
})
local inspection = ModelInspection.new({
	valid = function(model)
		return Tags.Kind(collection, model) == "Container"
	end,
	player = player,
	input = input,
	workspace = workspace,
	config = Config,
	tweens = game:GetService("TweenService"),
	render = RunService,
	reduced = reduced,
	blocked = function()
		return guiService.MenuIsOpen or playerGui:GetAttribute("DPU_ModalOpen") == true
	end,
	active = function(active)
		close.Text, close.Visible = "CLOSE VIEW [Q / B]", active
		if not active and interaction then
			interaction:Cancel()
		end
	end,
})
interaction = TaggedInteraction.new({
	throw = throwing,
	collection = collection,
	player = player,
	input = input,
	workspace = workspace,
	remote = remote,
	config = Config,
	telephone = telephone,
	inspection = inspection,
	locked = function()
		return cursor:IsLocked()
	end,
	blocked = function()
		return guiService.MenuIsOpen
			or playerGui:GetAttribute("DPU_ModalOpen") == true
			or (needsPointer() and not inspection.saved)
	end,
	hover = function(active)
		cursor:SetHover(active, reduced())
	end,
	template = highlightTemplate,
})
local closeConnection = close.Activated:Connect(function()
	if inspection.saved then
		interaction:CloseView()
	else
		telephone:Close()
	end
end)
local elapsed, stopped = 0, false
local heartbeat = RunService.Heartbeat:Connect(function(dt)
	elapsed += dt
	if elapsed < 0.1 then
		return
	end
	elapsed = 0
	interaction:Update()
	telephone:Update()
end)
local destroying
destroying = script.Destroying:Connect(function()
	if stopped then
		return
	end
	stopped = true
	heartbeat:Disconnect()
	destroying:Disconnect()
	interaction:Destroy()
	inspection:Destroy()
	closeConnection:Disconnect()
	telephone:Destroy()
	cursor:Destroy()
	gui:Destroy()
end)
