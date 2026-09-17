local Definition = require(script.Parent.RepairDefinition)
local Rig = {}
-- Resolve only the owner's authored names; Keys/SimTray remain part of the body.
function Rig.Read(model)
	if not model or not model:IsA("Model") then
		return nil, "ExpectedModel"
	end
	local result = { model = model, parts = {}, keys = {}, wires = {}, wireParts = {}, markers = {} }
	local function part(parent, name)
		local item = parent and parent:FindFirstChild(name)
		if not item or not item:IsA("BasePart") then
			return nil
		end
		return item
	end
	result.body, result.screen = part(model, "Phone"), part(model, "Screen")
	result.keys.Battery, result.keys.BackCover = part(model, "Battery"), part(model, "BackCover")
	if not result.body or not result.screen or not result.keys.Battery or not result.keys.BackCover then
		return nil, "MissingBodyParts"
	end
	for index = 1, 4 do
		local screw = part(model:FindFirstChild("Screws"), "Screw" .. index)
		if not screw then
			return nil, "MissingScrew"
		end
		result.keys[screw.Name] = screw
	end
	for _, pair in ipairs(Definition.Pairs) do
		local start = part(model:FindFirstChild("Pipes"), pair.From)
		local finish = part(model:FindFirstChild("Pipes"), pair.To)
		local wire = part(model:FindFirstChild("Wires"), pair.Wire)
		if not start or not finish or not wire then
			return nil, "MissingWireParts"
		end
		result.keys[pair.From], result.markers[start], result.markers[finish] = start, true, true
		result.wires[wire], result.keys[pair.To], result.wireParts[pair.Wire] = true, finish, wire
	end
	for _, item in ipairs(model:GetDescendants()) do
		if item:IsA("BasePart") then
			table.insert(result.parts, item)
		end
	end
	local _, size = model:GetBoundingBox()
	if #result.parts > Definition.MaxParts or size.Magnitude > Definition.MaxSize then
		return nil, "PhoneTooLarge"
	end
	return result
end
return Rig
