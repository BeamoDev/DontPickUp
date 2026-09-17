-- Offline fixture captured from the previous play-session builders before removal.
-- This is test data only, never deployed or used as a runtime fallback.
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local Roblox = require("@lune/roblox")
local Assets = {}
function Assets.Build(h, name, gui, workspace, storage)
	local path = "tests/fixtures/prototype/" .. name .. ".json"
	if not fs.isFile(path) then
		return
	end
	local records = serde.decode("json", fs.readFile(path))
	local instances, reused = {}, {}
	local function unpackValue(value)
		if type(value) ~= "table" then
			return value
		end
		if value.ref then
			return instances[value.ref]
		end
		if value.type then
			return Roblox[value.type].new(table.unpack(value.v))
		end
	end
	local prototype
	if workspace and workspace.FindFirstChild then
		prototype = workspace:FindFirstChild("Prototype")
		if not prototype then
			prototype = h.env.Instance.new("Folder")
			prototype.Name, prototype.Parent = "Prototype", workspace
		end
	end
	for i, record in ipairs(records) do
		local props = record.props
		local parent = record.parent and instances[record.parent] or gui
		if record.external == "Workspace" or props.Name == "DPU_InteractFocus" or props.Name == "DPU_RepairFocus" then
			parent = prototype
		end
		if record.external == "ReplicatedStorage" then
			parent = storage
		end
		if name == "FirstPersonCamera" and props.Name == "DPU_Cursor" then
			parent = gui.Parent
		end
		local assetName = props.Name == "DontPickUpTemplates" and "Assets" or props.Name
		if
			record.parent
			and records[record.parent].props.Name == "DontPickUpTemplates"
			and assetName == "RepairPhone"
		then
			assetName = "RepairPhonePrototype"
		end
		local old = not record.parent and parent and parent:FindFirstChild(assetName)
		if old or (record.parent and reused[record.parent]) then
			instances[i] = old or parent:FindFirstChild(assetName)
			reused[i] = true
		else
			instances[i] = h.env.Instance.new(props.ClassName)
			instances[i].Name = assetName
			instances[i].Parent = parent
		end
	end
	for i, record in ipairs(records) do
		if not reused[i] then
			local item = instances[i]
			for key, value in pairs(record.props) do
				if key ~= "Name" and key ~= "ClassName" then
					item[key] = unpackValue(value)
				end
			end
			for key, value in pairs(record.attrs) do
				item:SetAttribute(key, unpackValue(value))
			end
		end
	end
	if name == "PrototypeWorld" then
		require("./CustomerFixture").Build(h, storage)
		local folder, template = prototype.DPU_Prototype, storage.Assets.RepairPhonePrototype
		local devices = h.env.Instance.new("Folder")
		devices.Name, devices.Parent = "Devices", storage.Assets
		local device = template:Clone()
		device.Name, device.Parent = "Phone", devices
		device.Body.Name = "Phone"
		local cover = device.Phone:Clone()
		cover.Name, cover.Parent = "BackCover", device
		cover.CFrame = device.Phone.CFrame + Roblox.Vector3.new(0, -0.1, 0)
		cover.Position = cover.CFrame.Position
		local screws = h.env.Instance.new("Folder")
		screws.Name, screws.Parent = "Screws", device
		for index = 1, 4 do
			local screw = device:FindFirstChild("Contact" .. index) or device.Phone:Clone()
			screw.Name, screw.Parent = "Screw" .. index, screws
		end
		for _, fault in ipairs({ "Speaker", "Keypad" }) do
			local old = device:FindFirstChild(fault)
			if old then
				old:Destroy()
			end
		end

		-- Current authored shop uses one Fax Model, with no separate hazard phone props.
		for _, oldName in ipairs({ "Fax", "DeskPhoneBase", "Receiver", "Phone" }) do
			local old = folder:FindFirstChild(oldName)
			if old then
				old:Destroy()
			end
		end
		local telephone = h.env.Instance.new("Model")
		telephone.Name, telephone.Parent = "Fax", folder
		local base = h.env.Instance.new("Part")
		base.Name, base.CFrame, base.Position, base.Size =
			"Base", Roblox.CFrame.new(-5, 4, 387), Roblox.Vector3.new(-5, 4, 387), Roblox.Vector3.new(3, 1, 2)
		base.CanQuery, base.Parent = true, telephone
		local handset = base:Clone()
		handset.Name, handset.Parent = "Phone", telephone
		for _, spec in ipairs({
			{ "RepairPhone", -12, 3.05, -1 },
			{ "RepairPhone2", 10, 3.05, -1 },
			{ "CounterPhone_Bench", -1.5, 3.4, -13 },
			{ "CounterPhone_Bench2", 1.5, 3.4, -13 },
		}) do
			local model = template:Clone()
			model.Name, model.Parent = spec[1], folder
			model:PivotTo(Roblox.CFrame.new(spec[2], spec[3], spec[4] + 400))
		end
		for _, marker in ipairs({ "RepairFocus", "RepairCamera" }) do
			folder.Bench[marker]:Clone().Parent = folder.Bench2
		end
	end
	return instances
end
function Assets.Install(h)
	local load = h.load
	function h:load(path, overrides, globals)
		local module = load(self, path, overrides, globals)
		local name = path:match("/([^/]+)%.luau$")
		name = ({
			WorldService = "PrototypeWorld",
			HUDController = "PrototypeView",
			HorrorController = "ScarePresentation",
			CameraController = "FirstPersonCamera",
			StationInteractionController = "StationInteraction",
			WorldInteractionController = "WorldInteraction",
		})[name] or name
		if
			name
			and type(module) == "table"
			and module.new
			and fs.isFile("tests/fixtures/prototype/" .. name .. ".json")
		then
			local new = module.new
			module.new = function(...)
				local args = { ... }
				local gui, ws, storage = args[1], self.env.workspace
				if name == "PrototypeWorld" then
					gui, ws, storage = nil, self.env.workspace, args[1].ReplicatedStorage
				elseif name == "ScarePresentation" or name == "RepairPresentation" or name == "StationInteraction" then
					gui, ws = args[2], args[1].workspace
				elseif name == "WorldInteraction" then
					ws = args[2].workspace
				end
				Assets.Build(self, name, gui, ws, storage)
				if name == "PuzzleView" and args[3] and args[3].workspace then
					Assets.Build(self, "PhysicalRepairView", gui, args[3].workspace)
				end
				local construct = self.env.Instance.new
				local runtimeCamera = false
				self.env.Instance.new = function(class)
					if name == "ScarePresentation" and class == "Camera" and not runtimeCamera then
						runtimeCamera = true
						return construct(class)
					end
					error("Fixed authored binding attempted to construct " .. class .. " in " .. name)
				end
				local ok, result = pcall(new, ...)
				self.env.Instance.new = construct
				assert(ok, tostring(result))
				return result
			end
		end
		return module
	end
end
return Assets
