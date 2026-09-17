-- Public authored appearance lookup. Order selection and gameplay stay on the server.
local Templates = {}
Templates.Attribute = "DPU_AppearanceId"
Templates.GenderAttribute = "DPU_AnimationGender"
function Templates.Gender(model)
	local gender = model:GetAttribute(Templates.GenderAttribute)
	if gender == "Female" or gender == "Male" then
		return gender
	end
	local parent = model.Parent
	if parent and (parent.Name == "Female" or parent.Name == "Male") then
		return parent.Name
	end
	return "Male" -- Legacy Assets.NPC rigs used the male animation set.
end
function Templates.List(storage)
	local assets = storage:FindFirstChild("Assets")
	local result = {}
	local function append(root)
		for _, item in ipairs(root and (root:IsA("Model") and { root } or root:GetChildren()) or {}) do
			if item:IsA("Model") and item:FindFirstChildWhichIsA("BasePart", true) then
				table.insert(result, item)
			end
		end
	end
	local characters = assets and assets:FindFirstChild("Characters")
	if characters then
		append(characters:FindFirstChild("Female"))
		append(characters:FindFirstChild("Male"))
	end
	if #result == 0 then
		append(assets and (assets:FindFirstChild("NPC") or assets:FindFirstChild("npc")))
	end
	return result
end
function Templates.Find(storage, id)
	local list = Templates.List(storage)
	if id then
		for _, model in ipairs(list) do
			if model:GetAttribute(Templates.Attribute) == id then
				return model
			end
		end
		return nil
	end
	return #list > 0 and list[math.random(1, #list)] or nil
end
return table.freeze(Templates)
