-- At most one short conversation per channel. No timers or background tasks.
local Dialogue = {}
Dialogue.__index = Dialogue
function Dialogue.new()
	return setmetatable({ Serial = 0, Pending = {} }, Dialogue)
end
function Dialogue:Start(runId, lines, now)
	self.Pending = {}
	for i = 1, math.min(4, #lines) do
		local source = lines[i]
		table.insert(self.Pending, {
			Speaker = source.Speaker,
			Text = source.Text,
			UserId = source.UserId,
			AppearanceId = source.AppearanceId,
			Animation = source.Animation,
		})
	end
	self.RunId, self.Current = runId, nil
	self:Tick(now)
end
function Dialogue:Tick(now)
	if self.Current and now < self.Current.ExpiresAt then
		return false
	end
	local source = table.remove(self.Pending, 1)
	if not source then
		local changed = self.Current ~= nil
		self.Current = nil
		return changed
	end
	self.Serial += 1
	source.Id = tostring(self.RunId) .. "_dialogue_" .. self.Serial
	source.StartedAt = now
	source.ExpiresAt = now + math.clamp((utf8.len(source.Text) or #source.Text) / 32 + 2.2, 3.5, 12)
	self.Current = source
	return true
end
function Dialogue:Clear()
	self.Current, self.Pending = nil, {}
end
return Dialogue
