local Shared = game:GetService("ReplicatedStorage"):WaitForChild("GShared", 30)
local Containers = require(Shared:WaitForChild("Interaction", 30):WaitForChild("ContainerConfig", 30))
local frame = require(script.Parent.InspectionFrame)
local Config = { Distance = Containers.Distance, CameraSeconds = 0.35, FieldOfView = 45 }
function Config.CameraFrame(pivot, bounds, size, viewport)
	local offset = bounds:VectorToObjectSpace(Containers.OpenOffset)
	local travel = Vector3.new(math.abs(offset.X), math.abs(offset.Y), math.abs(offset.Z))
	return frame(pivot, bounds, size + travel * 2, viewport, Vector3.new(0, 2.8, -3.4), Config.FieldOfView)
end
return table.freeze(Config)
