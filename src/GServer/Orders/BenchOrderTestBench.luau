-- A deliberately small Studio fixture, separate from the real order lifecycle.
-- Never replaces authored scenery or creates an entire generated map.
local Bench = {}
local function part(parent, name, size, frame, color, marker)
	local item = Instance.new("Part")
	item.Name, item.Size, item.CFrame = name, size, frame
	item.Anchored, item.CanTouch = true, false
	item.CanCollide, item.CanQuery = not marker, not marker
	item.Color, item.Material = color or Color3.fromRGB(70, 74, 66), Enum.Material.SmoothPlastic
	item.Transparency = marker and 1 or 0
	item.TopSurface, item.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	item.Parent = parent
	return item
end
function Bench.Create(world)
	local marker = world:FindFirstChild("OrderBenchOrigin")
	local frame
	if marker and marker:IsA("BasePart") then
		frame = marker.CFrame
	else
		local spawn = world:FindFirstChildWhichIsA("SpawnLocation", true)
		local origin = spawn and spawn.CFrame * CFrame.new(0, 0, -14) or CFrame.new(0, 0, -14)
		local hit = world:Raycast(origin.Position + Vector3.yAxis * 8, -Vector3.yAxis * 80)
		frame = CFrame.new(origin.Position.X, hit and hit.Position.Y or 0, origin.Position.Z) * origin.Rotation
	end
	local model = Instance.new("Model")
	model.Name = "DPU_OrderTestBench"
	part(model, "Worktop", Vector3.new(10, 0.4, 6), frame * CFrame.new(0, 3, 0), Color3.fromRGB(97, 82, 64))
	for _, x in ipairs({ -4.4, 4.4 }) do
		for _, z in ipairs({ -2.4, 2.4 }) do
			part(model, "Leg", Vector3.new(0.4, 2.8, 0.4), frame * CFrame.new(x, 1.4, z))
		end
	end
	part(model, "RepairMat", Vector3.new(7, 0.03, 4.4), frame * CFrame.new(0, 3.215, 0), Color3.fromRGB(42, 63, 50))
	for name, offset in pairs({
		PhoneSpot = Vector3.new(0, 3.24, 0.8),
		CustomerStand = Vector3.new(0, 0, -3.8),
		CustomerStart = Vector3.new(0, 0, -12),
		CustomerExit = Vector3.new(0, 0, -12),
	}) do
		-- Customers face the operator on the +Z side of the bench.
		part(
			model,
			name,
			Vector3.one * 0.2,
			frame * CFrame.new(offset) * CFrame.Angles(0, name == "CustomerExit" and 0 or math.pi, 0),
			nil,
			true
		)
	end
	local sign = part(model, "ServiceSign", Vector3.new(4.8, 0.7, 0.1), frame * CFrame.new(0, 2.3, 3.08))
	local gui = Instance.new("SurfaceGui")
	gui.Face, gui.PixelsPerStud, gui.SizingMode = Enum.NormalId.Back, 70, Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.Parent = sign
	local label = Instance.new("TextLabel")
	label.Size, label.BackgroundTransparency = UDim2.fromScale(1, 1), 1
	label.Text, label.TextScaled, label.Font = "REPAIR SERVICE / TEST BENCH", true, Enum.Font.Code
	label.TextColor3, label.Parent = Color3.fromRGB(225, 215, 190), gui
	model.Parent = world
	return model
end
function Bench.Phone()
	local model = Instance.new("Model")
	model.Name = "TestPhone"
	local gray, dark = Color3.fromRGB(105, 104, 93), Color3.fromRGB(32, 36, 31)
	local function make(parent, name, size, position, color)
		local item = part(parent, name, size, CFrame.new(position), color)
		item.CanCollide = false
		return item
	end
	-- Long axis Y, front -Z: compatible with the existing disassembly geometry.
	model.PrimaryPart = make(model, "Phone", Vector3.new(1.35, 2.5, 0.24), Vector3.zero, gray)
	make(model, "Screen", Vector3.new(1.06, 0.8, 0.04), Vector3.new(0, 0.57, -0.15), Color3.fromRGB(84, 119, 73))
	make(model, "Battery", Vector3.new(0.82, 1.25, 0.16), Vector3.new(0, -0.1, 0.21), dark)
	make(model, "BackCover", Vector3.new(1.3, 2.4, 0.12), Vector3.new(0, 0, 0.37), gray)
	local screws, pipes, wires, keys =
		Instance.new("Folder"), Instance.new("Folder"), Instance.new("Folder"), Instance.new("Folder")
	screws.Name, pipes.Name, wires.Name, keys.Name = "Screws", "Pipes", "Wires", "Keys"
	screws.Parent, pipes.Parent, wires.Parent, keys.Parent = model, model, model, model
	for i = 1, 4 do
		make(
			screws,
			"Screw" .. i,
			Vector3.one * 0.12,
			Vector3.new(i % 2 == 0 and 0.53 or -0.53, i <= 2 and 1.02 or -1.02, 0.47),
			dark
		)
	end
	local colors = {
		Color3.fromRGB(220, 60, 55),
		Color3.fromRGB(235, 207, 62),
		Color3.fromRGB(63, 134, 223),
		Color3.fromRGB(226, 118, 174),
	}
	local names = { "Red", "Yellow", "Blue", "Pink" }
	for i = 1, 4 do
		local y = (i - 2.5) * 0.43
		for _, endpoint in ipairs({ { "EntryPoint" .. i, -0.51 }, { "ExitPoint" .. (5 - i), 0.51 } }) do
			local socket = make(pipes, endpoint[1], Vector3.one * 0.15, Vector3.new(endpoint[2], y, 0.3), colors[i])
			socket.Transparency = 1
		end
		local wire = make(wires, names[i], Vector3.new(0.94, 0.055, 0.055), Vector3.new(0, y, 0.32), colors[i])
		wire.Transparency = 1
	end
	for i = 1, 12 do
		make(
			keys,
			"Keypad" .. i,
			Vector3.new(0.25, 0.16, 0.05),
			Vector3.new(((i - 1) % 3 - 1) * 0.34, -0.12 - math.floor((i - 1) / 3) * 0.27, -0.15),
			dark
		)
	end
	return model
end
return Bench
