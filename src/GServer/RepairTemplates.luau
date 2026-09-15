-- Replace RepairPhone in ReplicatedStorage.DontPickUpTemplates with an authored Model.
-- Its pivot is the bottom center; named components are optional presentation targets.
local Templates = {}

function Templates.Build(storage, parent, frame)
	local folder = storage:FindFirstChild("DontPickUpTemplates")
	local ownedFolder, ownedTemplate
	if not folder then
		folder = Instance.new("Folder")
		folder.Name, folder.Parent = "DontPickUpTemplates", storage
		ownedFolder = folder
	end
	local template = folder:FindFirstChild("RepairPhone")
	if not template then
		template = Instance.new("Model")
		template.Name = "RepairPhone"
		local specs = {
			{
				"Contact1",
				Vector3.new(0.16, 0.1, 0.16),
				Vector3.new(-0.72, 0.33, -1.25),
				Color3.fromRGB(214, 179, 86),
			},
			{
				"Contact2",
				Vector3.new(0.16, 0.1, 0.16),
				Vector3.new(0.72, 0.33, -1.25),
				Color3.fromRGB(214, 179, 86),
			},
			{
				"Contact3",
				Vector3.new(0.16, 0.1, 0.16),
				Vector3.new(0, 0.33, 1.25),
				Color3.fromRGB(214, 179, 86),
			},
			{ "Body", Vector3.new(1.8, 0.22, 3), Vector3.new(0, 0.11, 0), Color3.fromRGB(44, 48, 38) },
			{
				"Screen",
				Vector3.new(1.35, 0.12, 0.9),
				Vector3.new(0, 0.28, -0.85),
				Color3.fromRGB(94, 151, 71),
			},
			{
				"Battery",
				Vector3.new(0.6, 0.18, 0.95),
				Vector3.new(-0.43, 0.31, 0.3),
				Color3.fromRGB(123, 117, 85),
			},
			{
				"Speaker",
				Vector3.new(0.55, 0.16, 0.4),
				Vector3.new(0.43, 0.3, -0.1),
				Color3.fromRGB(102, 104, 95),
			},
			{
				"Keypad",
				Vector3.new(0.65, 0.12, 0.85),
				Vector3.new(0.43, 0.28, 0.7),
				Color3.fromRGB(155, 143, 115),
			},
		}
		for _, spec in ipairs(specs) do
			local part = Instance.new("Part")
			part.Name, part.Size, part.CFrame, part.Color = spec[1], spec[2], CFrame.new(spec[3]), spec[4]
			part.Anchored, part.CanCollide, part.CanTouch, part.CastShadow = true, false, false, false
			part.TopSurface, part.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
			part.Parent = template
		end
		-- Explicit pivot keeps modeller replacements independent of component bounds.
		template.WorldPivot = CFrame.new()
		template.Parent, ownedTemplate = folder, template
	end
	assert(template:IsA("Model"), "DontPickUpTemplates.RepairPhone must be a Model")
	local phone = template:Clone()
	for _, descendant in ipairs(phone:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored, descendant.CanCollide, descendant.CanTouch = true, false, false
		end
	end
	phone:PivotTo(frame)
	phone.Parent = parent
	return phone,
		function()
			if ownedTemplate then
				ownedTemplate:Destroy()
			end
			if ownedFolder and #ownedFolder:GetChildren() == 0 then
				ownedFolder:Destroy()
			end
		end
end

return Templates
