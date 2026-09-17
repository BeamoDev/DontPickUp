local Roblox = require("@lune/roblox")
local Signal = require("./TagFixture").Signal
local Fixture = {}
function Fixture.Install(h)
	local make = h.env.Instance.new
	h.env.Instance.new = function(class)
		local item = make(class)
		if class == "CFrameValue" then
			local changed = Signal()
			item.GetPropertyChangedSignal = function()
				return changed
			end
		end
		return item
	end
end
function Fixture.Build(h, storage)
	local function node(class, name, parent)
		local item = h.env.Instance.new(class)
		item.Name, item.Parent = name, parent
		return item
	end
	local assets = storage:FindFirstChild("Assets") or node("Folder", "Assets", storage)
	local folder = assets:FindFirstChild("NPC") or node("Folder", "NPC", assets)
	for index = 1, 3 do
		local model = node("Model", index < 3 and "Character_11" or "Character_2", folder)
		model.Archivable, model.WorldPivot = true, Roblox.CFrame.new()
		model.GetPivot = function(self)
			return self.WorldPivot
		end
		model.GetBoundingBox = function(self)
			local low, high = Roblox.Vector3.one * math.huge, -Roblox.Vector3.one * math.huge
			for _, item in ipairs(self:GetDescendants()) do
				if item:IsA("BasePart") then
					low = low:Min(item.CFrame.Position - item.Size / 2)
					high = high:Max(item.CFrame.Position + item.Size / 2)
				end
			end
			return Roblox.CFrame.new((low + high) / 2), high - low
		end
		for _, spec in ipairs({ { "HumanoidRootPart", 2.5 }, { "Head", 4.5 } }) do
			local part = node("Part", spec[1], model)
			part.CFrame, part.Position, part.Size =
				Roblox.CFrame.new(0, spec[2], 0), Roblox.Vector3.new(0, spec[2], 0), Roblox.Vector3.new(2, 2, 1)
			part.Transparency, part.Color = 0, Roblox.Color3.fromRGB(40 * index, 60, 70)
			part.GetConnectedParts = function()
				return {}
			end
		end
		node("Script", "AuthoredScript", model)
	end
	return folder
end
return Fixture
