-- One pooled authored highlight for every interaction mode.
local Selection = {}
Selection.__index = Selection
function Selection.new(world, template, tweens)
	return setmetatable({ world = world, template = template, tweens = tweens, serial = 0 }, Selection)
end
function Selection.Bind(world, instance, tweens)
	local self = Selection.new(world, nil, tweens)
	self.instance, self.borrowed = instance, true
	self.fill, self.outline = instance.FillTransparency or 0.9, instance.OutlineTransparency or 0
	instance.Enabled, instance.Adornee = false, nil
	instance.FillTransparency, instance.OutlineTransparency = 1, 1
	return self
end
function Selection:CancelTween()
	self.serial += 1
	if self.completed then
		self.completed:Disconnect()
		self.completed = nil
	end
	if self.tween then
		self.tween:Cancel()
		self.tween = nil
	end
end
function Selection:Fade(visible, done)
	self:CancelTween()
	local serial = self.serial
	local goals = { FillTransparency = visible and self.fill or 1, OutlineTransparency = visible and self.outline or 1 }
	if not self.tweens then
		for key, value in pairs(goals) do
			self.instance[key] = value
		end
		if done then
			done()
		end
		return
	end
	self.tween = self.tweens:Create(
		self.instance,
		TweenInfo.new(visible and 0.14 or 0.10, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
		goals
	)
	self.completed = self.tween.Completed:Connect(function()
		if self.destroyed or serial ~= self.serial then
			return
		end
		self.completed:Disconnect()
		self.completed = nil
		self.tween = nil
		if done then
			done()
		end
	end)
	self.tween:Play()
end
function Selection:Reveal()
	self.fadingOut = false
	local target = self.target
	if target and not target:IsDescendantOf(self.world) then
		target = nil
		self.target = nil
	end
	self.instance.Adornee, self.instance.Enabled = target, target ~= nil
	if target then
		self:Fade(true)
	end
end
function Selection:Set(target)
	if self.destroyed then
		return nil
	end
	if target and not target:IsDescendantOf(self.world) then
		target = nil
	end
	if target and not self.instance then
		local template = self.template()
		if template and template:IsA("Highlight") then
			self.instance = template:Clone()
			self.fill, self.outline = self.instance.FillTransparency, self.instance.OutlineTransparency
			self.instance.FillTransparency, self.instance.OutlineTransparency = 1, 1
			self.instance.Enabled, self.instance.Adornee = false, nil
			self.instance.Parent = self.world
		end
	end
	if not self.instance or target == self.target then
		return self.instance
	end
	self.target = target
	local current = self.instance.Adornee
	if current and not current:IsDescendantOf(self.world) then
		self:CancelTween()
		self.instance.FillTransparency, self.instance.OutlineTransparency = 1, 1
		self:Reveal()
	elseif current == target then
		-- Brief ray misses reverse from current opacity instead of flashing off/on.
		self.fadingOut = false
		self:Fade(true)
	elseif self.instance.Enabled then
		if not self.fadingOut then
			self.fadingOut = true
			self:Fade(false, function()
				self:Reveal()
			end)
		end
	else
		self:Reveal()
	end
	return self.instance
end
function Selection:Destroy()
	self.destroyed = true
	self:CancelTween()
	if self.instance then
		if self.borrowed then
			self.instance.Enabled, self.instance.Adornee = false, nil
		else
			self.instance:Destroy()
		end
		self.instance = nil
	end
	self.target = nil
end
return Selection
