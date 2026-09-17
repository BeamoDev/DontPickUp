-- Public authored scene paths shared by the server and client. No construction.
local Scene = {}
local stock = { Part_Battery = "Part_BatteryBox1", Part_Keypad = "Part_KeypadBox2", Part_Speaker = "Part_SpeakerBox3" }
function Scene.Station(world, name)
	if not world then
		return nil
	end
	if name == "Fax" or name == "Phone" or name == "Answer" then
		local model = world:FindFirstChild("Fax")
		return model and model:IsA("Model") and model or nil
	end
	local storage = stock[name] and world:FindFirstChild("Storage")
	if storage then
		return storage:FindFirstChild(stock[name])
	end
	return world:FindFirstChild(name)
end
function Scene.StockBox(part)
	local suffix = part and part.Name:match("^Part_%w+Box(%d+)$")
	return suffix and part.Parent and part.Parent:FindFirstChild("Box" .. suffix) or nil
end
function Scene.Require(parent, name, class)
	local item = parent and parent:FindFirstChild(name)
	assert(
		item and item:IsA(class),
		"[DPU] Missing authored " .. (parent and parent:GetFullName() or "scene") .. "." .. name .. " (" .. class .. ")"
	)
	return item
end
function Scene.Find(workspace)
	local container = workspace:FindFirstChild("Prototype")
	return container and container:FindFirstChild("DPU_Prototype")
end
function Scene.Television(workspace)
	local world = Scene.Find(workspace)
	local model = world and world:FindFirstChild("CRT")
	local screen = model and model:IsA("Model") and model:FindFirstChild("CRTScreen")
	if screen and screen:IsA("BasePart") then
		return model, screen
	end
end
function Scene.Telephone(workspace)
	return Scene.Station(Scene.Find(workspace), "Fax")
end
function Scene.World(workspace)
	return Scene.Require(Scene.Require(workspace, "Prototype", "Folder"), "DPU_Prototype", "Folder")
end
function Scene.Assets(storage)
	return Scene.Require(storage, "Assets", "Folder")
end
return Scene
