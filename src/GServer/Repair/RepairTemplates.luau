-- Source art is authored in Studio and is never generated or deleted by gameplay.
local Templates = {}
function Templates.Get(storage)
	local assets = storage:FindFirstChild("Assets")
	local devices = assets and assets:FindFirstChild("Devices")
	local template = devices and devices:FindFirstChild("Phone")
	assert(template and template:IsA("Model"), "[DPU] Missing ReplicatedStorage.Assets.Devices.Phone (Model)")
	return template
end
return Templates
