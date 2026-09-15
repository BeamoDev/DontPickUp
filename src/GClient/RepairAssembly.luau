-- Cosmetic replacement motion. Server work and stock never depend on tween completion.
local Assembly = {}
Assembly.__index = Assembly
function Assembly.new(deps)
	return setmetatable({ d = deps }, Assembly)
end
function Assembly:Clear()
	if self.connection then
		self.connection:Disconnect()
		self.connection = nil
	end
	if self.tween then
		self.tween:Cancel()
		self.tween = nil
	end
	if self.target and self.target.Parent then
		self.target.LocalTransparencyModifier = self.alpha
	end
	if self.tray and self.tray.Parent then
		self.tray.LocalTransparencyModifier = self.trayAlpha
	end
	if self.part then
		self.part:Destroy()
	end
	self.target, self.tray, self.part, self.key = nil, nil, nil, nil
end
function Assembly:Update(state)
	local work, order = state.Work, state.Order
	local now = self.d.workspace:GetServerTimeNow()
	if
		not work
		or work.Action ~= "Repair"
		or work.Interactive
		or not state.Alive
		or state.Event
		or state.Phase == "Results"
		or now >= work.EndsAt
		or self.d.reduced()
	then
		if self.part then
			self:Clear()
		end
		return
	end
	local world = self.d.workspace:FindFirstChild("DPU_Prototype")
	local phone = world and world:FindFirstChild("RepairPhone")
	local target = phone and order and order.Fault and phone:FindFirstChild(order.Fault, true)
	local tray = world and world:FindFirstChild("ReplacementTray")
	if not target or not target:IsA("BasePart") or not tray then
		self:Clear()
		return
	end
	local key = state.RunId .. ":" .. order.Id .. ":" .. tostring(work.StartedAt)
	if key == self.key and self.target == target and self.tray == tray then
		return
	end
	self:Clear()
	self.key, self.target, self.tray = key, target, tray
	self.alpha, self.trayAlpha = target.LocalTransparencyModifier, tray.LocalTransparencyModifier
	local clone = target:Clone()
	clone.Name = "DPU_FittingPart"
	clone.Anchored, clone.CanCollide, clone.CanTouch, clone.CanQuery = true, false, false, false
	clone.LocalTransparencyModifier, clone.Transparency = 0, target.Transparency
	self.part = clone
	local finish = target.CFrame
	local start = CFrame.new(tray.Position) * finish.Rotation
	local lift = finish + Vector3.new(0, 1.1, 0)
	local duration = math.max(0.01, work.EndsAt - work.StartedAt)
	local t = math.clamp((now - work.StartedAt) / duration, 0, 1)
	clone.CFrame = t < 0.65 and start:Lerp(lift, t / 0.65) or lift:Lerp(finish, (t - 0.65) / 0.35)
	target.LocalTransparencyModifier, tray.LocalTransparencyModifier = 1, 1
	clone.Parent = self.d.workspace
	local function lower()
		if self.key ~= key or self.part ~= clone then
			return
		end
		if self.connection then
			self.connection:Disconnect()
			self.connection = nil
		end
		local remaining = math.max(0.01, work.EndsAt - self.d.workspace:GetServerTimeNow())
		self.tween = self.d.tweens:Create(
			clone,
			TweenInfo.new(remaining, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
			{ CFrame = finish }
		)
		self.tween:Play()
	end
	if t < 0.65 then
		self.tween = self.d.tweens:Create(
			clone,
			TweenInfo.new(duration * (0.65 - t), Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
			{ CFrame = lift }
		)
		self.connection = self.tween.Completed:Connect(lower)
		self.tween:Play()
	else
		lower()
	end
end
Assembly.Destroy = Assembly.Clear
return Assembly
