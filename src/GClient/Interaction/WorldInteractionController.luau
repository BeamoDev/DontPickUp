local UI = require(script.Parent.Parent.Interface.AuthoredUI)
local Selection = require(script.Parent.SelectionHighlight)
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("GShared", 30)
local Query = require(Shared:WaitForChild("Interaction", 30):WaitForChild("InteractionQuery", 30))
local Scene = require(Shared:WaitForChild("World", 30):WaitForChild("SceneReferences", 30))
local Containers = require(Shared:WaitForChild("Interaction", 30):WaitForChild("ContainerConfig", 30))
local Interaction = {}
Interaction.__index = Interaction
function Interaction.new(gui, deps)
	local self = setmetatable(
		{ d = deps, connections = {}, blocked = true, focused = true, state = {}, raycast = RaycastParams.new() },
		Interaction
	)
	self.highlight =
		UI.Bind("Highlight", deps.workspace:FindFirstChild("Prototype"), "DPU_InteractFocus", { Enabled = false })
	self.selection = Selection.Bind(deps.workspace, self.highlight, deps.tweens)
	self.hint = UI.Bind("TextLabel", gui, "ObjectAction", { Visible = false })
	local function connect(signal, callback)
		table.insert(self.connections, signal:Connect(callback))
	end
	local function phone()
		local television = deps.television and deps.television()
		if television and television:OwnsInput() then
			return television
		end
		return deps.telephone and deps.telephone()
	end
	connect(deps.input.InputBegan, function(input, processed)
		local telephone = phone()
		if telephone and telephone:OwnsInput() then
			telephone:InputBegan(input, processed)
			return
		end
		if self.touch and input.UserInputType == Enum.UserInputType.Touch and input ~= self.touch then
			self:CancelPress()
			return
		end
		if processed or not self.focused or deps.input:GetFocusedTextBox() or (deps.menuOpen and deps.menuOpen()) then
			return
		end
		if deps.shortcut and deps.shortcut(input.KeyCode) then
			return
		end
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			local position = Vector2.new(input.Position.X, input.Position.Y)
			local ui = deps.uiAction and deps.uiAction(position)
			if not ui and (self.blocked or self:UIBlocked(position)) then
				return
			end
			self.touch, self.touchStart, self.started, self.touchUI = input, input.Position, os.clock(), ui
			self.touchTarget = not ui and self:Pick(position) or nil
		end
	end)
	connect(deps.input.InputChanged, function(input)
		local telephone = phone()
		if telephone and telephone:OwnsInput() then
			telephone:InputChanged(input)
			return
		end
		if
			self.touch
			and (input == self.touch or (self.touch.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseMovement))
			and (input.Position - self.touchStart).Magnitude > 18
		then
			self:CancelPress()
		end
	end)
	connect(deps.input.InputEnded, function(input, processed)
		local telephone = phone()
		if telephone and telephone:OwnsInput() then
			self:CancelPress()
			telephone:InputEnded(input, processed)
			return
		end
		local tap = input == self.touch
			and (input.Position - self.touchStart).Magnitude <= 18
			and os.clock() - self.started <= 0.6
		local target, ui = self.touchTarget, self.touchUI
		if input == self.touch then
			self:CancelPress()
		end
		if processed or not self.focused then
			return
		end
		local position = tap and Vector2.new(input.Position.X, input.Position.Y) or nil
		if tap and ui and deps.uiAction(position) == ui then
			deps.shortcut(ui)
			return
		end
		if self.blocked then
			return
		end
		if tap and target and self:Pick(position) == target then
			self:Activate(position)
		elseif input.KeyCode == Enum.KeyCode.ButtonR2 then
			self:Activate()
		end
	end)
	connect(deps.input.WindowFocusReleased, function()
		self.focused = false
		self:CancelPress()
		local telephone = phone()
		if telephone then
			if telephone.phone then
				telephone.phone.focused = false
				telephone.phone:Close()
			else
				telephone:Close()
			end
		end
	end)
	connect(deps.input.WindowFocused, function()
		self.focused = true
		local telephone = phone()
		if telephone and telephone.phone then
			telephone.phone.focused = true
		end
	end)
	return self
end
function Interaction:CancelPress()
	self.touch, self.touchStart, self.touchTarget, self.touchUI = nil, nil, nil, nil
end
function Interaction:UIBlocked(position)
	if self.d.input:GetFocusedTextBox() or (self.d.menuOpen and self.d.menuOpen()) then
		return true
	end
	local playerGui = self.d.player:FindFirstChild("PlayerGui")
	if not position or not playerGui then
		return false
	end
	if self.d.uiAction and self.d.uiAction(position) then
		return true
	end
	for _, item in ipairs(playerGui:GetGuiObjectsAtPosition(position.X, position.Y)) do
		if item:IsA("GuiButton") and item.Active then
			return true
		end
	end
	return false
end
function Interaction:Pick(position)
	if self:UIBlocked(position) then
		return nil
	end
	if self.d.locked and self.d.locked() then
		position = nil
	end
	local camera, character = self.d.workspace.CurrentCamera, self.d.player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not camera or not root then
		return nil
	end
	local ray = position and camera:ViewportPointToRay(position.X, position.Y)
		or camera:ViewportPointToRay(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
	local hit, item = Query.Cast(
		self.d.workspace,
		self.d.collection,
		ray.Origin,
		ray.Direction * 35,
		self.raycast,
		{ character },
		function(part)
			while part and part ~= self.d.workspace do
				if part:GetAttribute("DPU_Direct") then
					return part
				end
				part = part.Parent
			end
		end
	)
	if
		item
		and item:GetAttribute("DPU_Enabled")
		and (root.Position - hit.Position).Magnitude <= (item:GetAttribute("DPU_Range") or 5)
	then
		return item
	end
end
function Interaction:Activate(position)
	local item = self:Pick(position)
	if item and self:CanHover(item, self.state) then
		local station = item:GetAttribute("DPU_Direct")
		if station == "CRT" and self.d.television then
			self.d.television():Open(item)
		elseif station:match("^Storage_Box%d*$") then
			local box = Containers.ResolveBox(item, item.Parent)
			if box then
				self.d.send("ToggleStorage", {
					Station = station,
					Id = box:GetAttribute("DPU_ContainerId"),
					Revision = box:GetAttribute("DPU_ContainerRevision"),
				})
			end
		else
			self.d.send("Interact", { Station = station })
		end
	end
end

function Interaction:CanHover(item, state)
	local station = item:GetAttribute("DPU_Direct")
	if station == "Timeclock" then
		return state.NeedsClockIn == true
	end
	if state.NeedsClockIn then
		return false
	end
	if station == "Fax" or station == "CRT" then
		return not state.NeedsRules
			and not (state.WorkBlocked == true or state.WorkBlocked == nil and state.Event ~= nil)
	end
	if station and station:match("^Storage_Box%d*$") then
		local box = Containers.ResolveBox(item, item.Parent)
		return box ~= nil
			and box:GetAttribute("DPU_ContainerBusy") ~= true
			and not state.NeedsRules
			and not state.CarriedPart
			and not state.Work
			and not (state.WorkBlocked == true or state.WorkBlocked == nil and state.Event ~= nil)
	end
	if station == "Tools" then
		local kit = state.Kit or {}
		return not (kit.Tester and kit.Screwdriver and kit.Cartridge)
	elseif station == "Tool_BrassKey" then
		return not (state.Kit and state.Kit.BrassKey)
	end
	local part = station and station:match("^Part_(.+)$")
	if part then
		local box = Scene.StockBox(item)
		if box and (box:GetAttribute("DPU_ContainerOpen") ~= true or box:GetAttribute("DPU_ContainerBusy") == true) then
			return false
		end
		local order = state.Order
		return not state.NeedsRules
			and not (state.WorkBlocked == true or state.WorkBlocked == nil and state.Event ~= nil)
			and not state.Work
			and not state.CarriedPart
			and order ~= nil
			and order.Step == "Collect"
			and order.Fault == part
			and (state.Stock and state.Stock[part] or 0) > 0
	end
	return true
end

function Interaction:Update(state, blocked)
	self.state, self.externalBlocked = state, blocked
	if not self.d.frameDriven then
		self:Step()
	end
end
function Interaction:Step()
	local state = self.state
	local telephone = self.d.telephone and self.d.telephone()
	local phoneOwns = telephone and telephone:OwnsInput()
	local television = self.d.television and self.d.television()
	local tvOwns = television and television:OwnsInput()
	self.blocked = self.externalBlocked
		or not self.focused
		or not state.Alive
		or state.Seated
		or state.Focus
		or state.Fax
		or state.Inspection
		or state.Phase == "Results"
		or phoneOwns
		or tvOwns
	if self.blocked then
		self:CancelPress()
	end
	if tvOwns then
		self.selection:Set(nil)
		self.hovered, self.hint.Visible = false, not television.camera.exiting
		self.hint.Text = self.d.input.TouchEnabled and "TAP TO STOP WATCHING" or "[Q / B] OR CLICK TO STOP WATCHING"
		return
	end
	if phoneOwns then
		self.hovered, self.hint.Visible = false, false
		return
	end
	local gamepad = self.d.input:GetLastInputType().Name:match("^Gamepad") ~= nil
	local pointer = not gamepad and self.d.input:GetMouseLocation() or nil
	local item = not self.blocked and self:Pick(pointer) or nil
	if item and not self:CanHover(item, state) then
		item = nil
	end
	self.hovered = item ~= nil
	self.selection:Set(item)
	self.hint.Visible = item ~= nil
	if item then
		self.hint.Text = (gamepad and "[RT] " or self.d.input.TouchEnabled and "TAP: " or "CLICK: ")
			.. (item:GetAttribute("DPU_Label") or "Use")
	end
end
function Interaction:Destroy()
	self.hovered = false
	for _, connection in ipairs(self.connections) do
		connection:Disconnect()
	end
	self.selection:Destroy()
	UI.Release(self.highlight)
	UI.Release(self.hint)
end
return Interaction
