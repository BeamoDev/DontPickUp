local Definition = {
	Tag = "PhoneRepair",
	Distance = 8,
	SessionSeconds = 180,
	DragSeconds = 15,
	DragInterval = 0.05,
	MaxParts = 128,
	MaxSize = 12,
	Pairs = table.freeze({
		table.freeze({ From = "ExitPoint4", To = "EntryPoint1", Wire = "Red" }),
		table.freeze({ From = "ExitPoint3", To = "EntryPoint2", Wire = "Yellow" }),
		table.freeze({ From = "ExitPoint2", To = "EntryPoint3", Wire = "Blue" }),
		table.freeze({ From = "ExitPoint1", To = "EntryPoint4", Wire = "Pink" }),
	}),
}
function Definition.Pair(key)
	for index, pair in ipairs(Definition.Pairs) do
		if pair.From == key then
			return pair, index
		end
	end
	return nil
end
function Definition.All(done)
	for index = 1, 4 do
		if not done[index] then
			return false
		end
	end
	return true
end
function Definition.Allowed(stage, key, wires, screws)
	if stage == "Wires" then
		local _, index = Definition.Pair(key)
		return index ~= nil and not wires[index]
	elseif stage == "Battery" then
		return key == "Battery"
	elseif stage == "Cover" then
		return key == "BackCover"
	elseif stage == "Screws" then
		local index = type(key) == "string" and tonumber(key:match("^Screw([1-4])$"))
		return index ~= nil and not screws[index]
	end
	return false
end
function Definition.Point(plane, half, x, y)
	if type(x) ~= "number" or type(y) ~= "number" or x ~= x or y ~= y or math.abs(x) > 1 or math.abs(y) > 1 then
		return nil
	end
	return plane:PointToWorldSpace(Vector3.new(x * half.X, 0, y * half.Y))
end
return table.freeze(Definition)
