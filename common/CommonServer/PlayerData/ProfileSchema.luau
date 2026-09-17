-- Maintained in common/CommonServer/PlayerData/ProfileSchema.luau. Deploy with tools/SyncCommon.ps1.
-- Pure schema. Replicated ValueObjects are views, never the save source.
local Schema = { Version = 4 }

function Schema.Copy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, child in pairs(value) do
		copy[key] = Schema.Copy(child)
	end
	return copy
end

local function integer(value, low, high)
	return type(value) == "number" and value == value and value % 1 == 0 and value >= low and value <= high
end

function Schema.Default()
	return {
		Version = Schema.Version,
		EmployeeNumber = 0, -- Assigned atomically when the server first acquires this profile.
		Stats = { Credits = 0, ShiftsSurvived = 0, CasesSolved = 0, Deaths = 0, PlaytimeSeconds = 0 },
		Progress = { HighestShift = 1, TutorialComplete = false, Endings = {}, Evidence = {} },
		Settings = {
			MasterVolume = 0.8,
			MusicVolume = 0.6,
			Subtitles = true,
			ReducedFlashes = false,
			MusicEnabled = true,
			SFXEnabled = true,
			CameraShake = true,
		},
		RecentOutcomes = {},
	}
end

local function identifier(value)
	return type(value) == "string" and #value >= 1 and #value <= 80 and value:match("^[%w_%-]+$") ~= nil
end
Schema.Identifier = identifier

function Schema.Validate(data)
	if type(data) ~= "table" or data.Version ~= Schema.Version then
		return false
	end
	if type(data.Stats) ~= "table" or type(data.Progress) ~= "table" or type(data.Settings) ~= "table" then
		return false
	end
	if data.EmployeeNumber ~= 0 and not integer(data.EmployeeNumber, 1000, 9999) then
		return false
	end
	for _, key in ipairs({ "Credits", "ShiftsSurvived", "CasesSolved", "Deaths", "PlaytimeSeconds" }) do
		if not integer(data.Stats[key], 0, 2000000000) then
			return false
		end
	end
	if not integer(data.Progress.HighestShift, 1, 10000) or type(data.Progress.TutorialComplete) ~= "boolean" then
		return false
	end
	for _, key in ipairs({ "Endings", "Evidence" }) do
		local set = data.Progress[key]
		if type(set) ~= "table" then
			return false
		end
		local count = 0
		for id, unlocked in pairs(set) do
			count += 1
			if count > 1000 or not identifier(id) or unlocked ~= true then
				return false
			end
		end
	end
	for _, key in ipairs({ "MasterVolume", "MusicVolume" }) do
		local n = data.Settings[key]
		if type(n) ~= "number" or n ~= n or n < 0 or n > 1 then
			return false
		end
	end
	for _, key in ipairs({ "Subtitles", "ReducedFlashes", "MusicEnabled", "SFXEnabled", "CameraShake" }) do
		if type(data.Settings[key]) ~= "boolean" then
			return false
		end
	end
	if type(data.RecentOutcomes) ~= "table" or #data.RecentOutcomes > 100 then
		return false
	end
	local count = 0
	for index, id in pairs(data.RecentOutcomes) do
		count += 1
		if not integer(index, 1, #data.RecentOutcomes) or not identifier(id) then
			return false
		end
	end
	return count == #data.RecentOutcomes
end

function Schema.Decode(record)
	if record == nil then
		return Schema.Default()
	end
	-- Unknown/future versions and malformed records fail closed. Add explicit migrations here.
	if type(record) ~= "table" or record.Format ~= 1 then
		return nil
	end
	local data = record.Data
	if type(data) == "table" and data.Version == 1 then
		data = Schema.Copy(data)
		data.Version = 2
		if type(data.Stats) ~= "table" then
			return nil
		end
		data.Stats.Credits = 0
	end
	if type(data) == "table" and data.Version == 2 then
		data = Schema.Copy(data)
		if type(data.Settings) ~= "table" then
			return nil
		end
		data.Version = 3
		data.Settings.MusicEnabled = type(data.Settings.MusicVolume) == "number" and data.Settings.MusicVolume > 0
		data.Settings.SFXEnabled = true
		data.Settings.CameraShake = true
	end
	if type(data) == "table" and data.Version == 3 then
		data = Schema.Copy(data)
		data.Version = Schema.Version
		data.EmployeeNumber = 0
	end
	if not Schema.Validate(data) then
		return nil
	end
	if record.Lease ~= nil then
		local lease = record.Lease
		if type(lease) ~= "table" or type(lease.Token) ~= "string" or not integer(lease.Expires, 0, 100000000000) then
			return nil
		end
	end
	return Schema.Copy(data)
end

return Schema
