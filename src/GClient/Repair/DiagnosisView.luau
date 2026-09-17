-- Reuses the authored TaskSurface controls as a three-channel diagnostic meter.
local Diagnosis = {}
Diagnosis.__index = Diagnosis
local NAMES = { "BATTERY", "SPEAKER", "KEYPAD" }
local PASS, FAIL, PAPER = Color3.fromRGB(146, 205, 154), Color3.fromRGB(232, 173, 105), Color3.fromRGB(220, 213, 200)
function Diagnosis.new()
	return setmetatable({ saved = {}, tweens = {}, tested = {} }, Diagnosis)
end
function Diagnosis:Set(object, key, value)
	self.saved[object] = self.saved[object] or {}
	if self.saved[object][key] == nil then
		self.saved[object][key] = { object[key] }
	end
	object[key] = value
end
function Diagnosis:Hide()
	for _, tween in pairs(self.tweens) do
		tween:Cancel()
	end
	for object, values in pairs(self.saved) do
		for key, value in pairs(values) do
			object[key] = value[1]
		end
	end
	table.clear(self.saved)
	table.clear(self.tweens)
	table.clear(self.tested)
	self.key, self.workId = nil, nil
end
function Diagnosis:Render(view, p, reduced)
	if self.workId ~= view.work.Id then
		self:Hide()
		self.workId = view.work.Id
	end
	local key = tostring(p.Revision) .. tostring(view.busy) .. tostring(reduced)
	if self.key == key then
		return
	end
	self.key = key
	self:Set(view.check, "Visible", false)
	for _, line in ipairs(view.lines) do
		self:Set(line, "Visible", false)
	end
	for index, button in ipairs(view.buttons) do
		self:Set(button, "Visible", index <= 6)
		for _, arm in ipairs(view.arms[index]) do
			self:Set(arm, "Visible", false)
		end
		if index > 6 then
			continue
		end
		local channel, test = (index - 1) % 3 + 1, index <= 3
		local checked = p.Tested[channel]
		local faulty = checked and p.Readings[channel] == "BROKEN"
		local color = checked and (faulty and FAIL or PASS) or PAPER
		self:Set(button, "Position", UDim2.new((channel - 1) / 3, 4, test and 0 or 0.74, 0))
		self:Set(button, "Size", UDim2.new(1 / 3, -8, test and 0.69 or 0.25, -2))
		self:Set(button, "Rotation", 0)
		self:Set(button, "BackgroundColor3", Color3.fromRGB(18, 27, 25))
		self:Set(button, "TextColor3", color)
		self:Set(button, "TextSize", 12)
		self:Set(button, "TextXAlignment", Enum.TextXAlignment.Center)
		self:Set(button, "TextYAlignment", test and Enum.TextYAlignment.Bottom or Enum.TextYAlignment.Center)
		self:Set(button, "Active", not view.busy and (test and not checked or not test and p.Progress == 3))
		self:Set(button, "Selectable", button.Active)
		self:Set(
			button,
			"Text",
			test and (NAMES[channel] .. "\n" .. (checked and (faulty and "FAULT" or "PASS") or "RUN TEST"))
				or (p.Progress == 3 and "REPLACE THIS" or "TEST ALL THREE")
		)
		local stroke = button:FindFirstChildWhichIsA("UIStroke")
		if stroke then
			self:Set(stroke, "Color", color)
		end
		if test then
			local dial, needle, label = view.dials[channel], view.needles[channel], view.dialLabels[channel]
			self:Set(dial, "Visible", true)
			self:Set(dial, "Position", UDim2.fromScale(0.5, 0.36))
			self:Set(dial, "Size", UDim2.fromOffset(42, 42))
			self:Set(dial, "AnchorPoint", Vector2.new(0.5, 0.5))
			self:Set(label, "Text", checked and (faulty and "!" or "OK") or "?")
			self:Set(label, "TextColor3", color)
			local angle = checked and (faulty and -55 or 55) or -100
			if self.tested[channel] ~= checked or reduced then
				if self.tweens[channel] then
					self.tweens[channel]:Cancel()
				end
				self:Set(needle, "Rotation", checked and not reduced and -100 or angle)
				if checked and not reduced and view.d.tweens then
					local tween = view.d.tweens:Create(
						needle,
						TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
						{ Rotation = angle }
					)
					self.tweens[channel] = tween
					tween:Play()
				else
					needle.Rotation = angle
				end
				self.tested[channel] = checked
			end
		end
	end
end
return Diagnosis
