local View = {}

local function instance(parent, class, name)
	local found = parent:FindFirstChild(name)
	if found then
		assert(found:IsA(class), "DontPickUp instance collision: " .. name)
		return found
	end
	local item = Instance.new(class)
	item.Name = name
	item.Parent = parent
	return item
end

local function value(parent, class, name, current)
	instance(parent, class, name).Value = current
end

function View.Status(player, status, persistent)
	local folder = instance(player, "Folder", "Session")
	value(folder, "StringValue", "DataStatus", status)
	value(folder, "BoolValue", "DataLoaded", status == "Ready")
	value(folder, "BoolValue", "Persistent", persistent)
	player:SetAttribute("DPU_DataStatus", status)
end

function View.Publish(player, data)
	local stats = instance(player, "Folder", "leaderstats")
	value(stats, "IntValue", "Shifts Survived", data.Stats.ShiftsSurvived)
	value(stats, "IntValue", "Cases Solved", data.Stats.CasesSolved)
	local root = instance(player, "Folder", "PlayerData")
	local progress = instance(root, "Folder", "Progression")
	value(progress, "IntValue", "HighestShift", data.Progress.HighestShift)
	value(progress, "BoolValue", "TutorialComplete", data.Progress.TutorialComplete)
	local endings, evidence = 0, 0
	for _ in pairs(data.Progress.Endings) do
		endings += 1
	end
	for _ in pairs(data.Progress.Evidence) do
		evidence += 1
	end
	value(progress, "IntValue", "EndingsFound", endings)
	value(progress, "IntValue", "EvidenceFound", evidence)
	local lifetime = instance(root, "Folder", "Statistics")
	value(lifetime, "IntValue", "Deaths", data.Stats.Deaths)
	value(lifetime, "IntValue", "PlaytimeSeconds", data.Stats.PlaytimeSeconds)
	local settings = instance(root, "Folder", "Settings")
	for key, current in pairs(data.Settings) do
		value(settings, type(current) == "boolean" and "BoolValue" or "NumberValue", key, current)
	end
end

return View
