-- Authored pickup surfaces move with their matching drawer, without new welds.
local Contents = {}
local function restore(item, state)
	if state.tween then
		state.tween:Cancel()
	end
	if item.Parent then
		item.CFrame = state.closed
		if state.anchored ~= nil then
			item.Anchored = state.anchored
		end
	end
end
function Contents.Clear(record)
	for item, state in pairs(record.contents or {}) do
		restore(item, state)
	end
	record.contents = nil
end
function Contents.Pair(record)
	record.contents = record.contents or {}
	for item, state in pairs(record.contents) do
		if item.Parent ~= record.folder or not item.Name:match("^Part_%w+" .. record.box.Name .. "$") then
			restore(item, state)
			record.contents[item] = nil
		end
	end
	for _, item in ipairs(record.folder:GetChildren()) do
		if
			item:IsA("BasePart")
			and item.Name:match("^Part_%w+" .. record.box.Name .. "$")
			and not record.contents[item]
		then
			record.contents[item] = { closed = record.closed * record.box.CFrame:ToObjectSpace(item.CFrame) }
		end
	end
end
function Contents.Tween(record, services, config)
	Contents.Pair(record)
	for item, state in pairs(record.contents) do
		if state.tween then
			state.tween:Cancel()
		end
		state.target = record.open and state.closed + config.OpenOffset or state.closed
		-- Loose welded contents already follow the box's assembly.
		local follows = not item.Anchored and table.find(item:GetConnectedParts(true), record.box) ~= nil
		if not follows then
			if state.anchored == nil then
				state.anchored = item.Anchored
			end
			item.Anchored = true
			state.tween = services.TweenService:Create(
				item,
				TweenInfo.new(config.TweenSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
				{ CFrame = state.target }
			)
			state.tween:Play()
		end
	end
end
function Contents.Finish(record)
	for item, state in pairs(record.contents or {}) do
		if state.tween then
			state.tween:Cancel()
			state.tween = nil
			if item.Parent == record.folder then
				item.CFrame = state.target
			end
		end
	end
end
return Contents
