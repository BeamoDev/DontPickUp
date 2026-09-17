-- Maintained in common/CommonClient/Interface/SettingsAudio.luau. Deploy with tools/SyncCommon.ps1.
-- Local event-driven sound muting. Never stop playback or change other players' audio.
local Audio = {}
Audio.__index = Audio
local function category(sound)
	local item = sound
	while item do
		local label = item:GetAttribute("AudioCategory")
		if label == "Music" or label == "SFX" then
			return label
		end
		local name = string.lower(item.Name)
		if name:find("music", 1, true) or name == "bgm" or name == "soundtrack" then
			return "Music"
		end
		item = item.Parent
	end
	local group = sound.SoundGroup
	while group do
		if group:GetAttribute("AudioCategory") == "Music" or string.lower(group.Name):find("music", 1, true) then
			return "Music"
		end
		group = group.Parent
	end
	return "SFX"
end
function Audio.new(roots, defer)
	local self =
		setmetatable({ roots = roots, records = {}, connections = {}, music = true, sfx = true, defer = defer }, Audio)
	for _, root in ipairs(roots) do
		table.insert(
			self.connections,
			root.DescendantAdded:Connect(function(item)
				self:_add(item)
			end)
		)
		table.insert(
			self.connections,
			root.DescendantRemoving:Connect(function(item)
				if self.records[item] then
					defer(function()
						if not self.dead and not self:_inside(item) then
							self:_remove(item)
						end
					end)
				end
			end)
		)
		for _, item in ipairs(root:GetDescendants()) do
			self:_add(item)
		end
	end
	return self
end
function Audio:_inside(item)
	for _, root in ipairs(self.roots) do
		if item:IsDescendantOf(root) then
			return true
		end
	end
	return false
end
function Audio:_apply(sound, record)
	local enabled = if category(sound) == "Music" then self.music else self.sfx
	local goal = enabled and record.volume or 0
	record.applied = goal
	if sound.Volume ~= goal then
		record.writing = true
		sound.Volume = goal
		record.writing = false
	end
end
function Audio:_add(sound)
	if self.dead or not sound:IsA("Sound") then
		return
	end
	if self.records[sound] then
		self:_apply(sound, self.records[sound])
		return
	end
	local record = { volume = sound.Volume, connections = {} }
	self.records[sound] = record
	table.insert(
		record.connections,
		sound:GetPropertyChangedSignal("Volume"):Connect(function()
			if not record.writing and sound.Volume ~= record.applied then
				record.volume = sound.Volume
				self:_apply(sound, record)
			end
		end)
	)
	for _, property in ipairs({ "SoundGroup", "Name" }) do
		table.insert(
			record.connections,
			sound:GetPropertyChangedSignal(property):Connect(function()
				self:_apply(sound, record)
			end)
		)
	end
	table.insert(
		record.connections,
		sound:GetAttributeChangedSignal("AudioCategory"):Connect(function()
			self:_apply(sound, record)
		end)
	)
	self:_apply(sound, record)
end
function Audio:Set(music, sfx)
	self.music, self.sfx = music, sfx
	for sound, record in pairs(self.records) do
		self:_apply(sound, record)
	end
end
function Audio:_remove(sound)
	local record = self.records[sound]
	if not record then
		return
	end
	self.records[sound] = nil
	for _, connection in ipairs(record.connections) do
		connection:Disconnect()
	end
	sound.Volume = record.volume
end
function Audio:Destroy()
	if self.dead then
		return
	end
	self.dead = true
	for _, connection in ipairs(self.connections) do
		connection:Disconnect()
	end
	for sound in pairs(self.records) do
		self:_remove(sound)
	end
end
return Audio
