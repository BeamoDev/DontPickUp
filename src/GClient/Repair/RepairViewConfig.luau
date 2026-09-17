-- Client-only close-up fitted to the installed endpoints, never the loose parts.
local View = {}
function View.Wiring(reply, rig)
	local plane = reply.Plane
	local low, high = Vector3.one * math.huge, Vector3.one * -math.huge
	for key, part in pairs(rig.keys) do
		if key:match("^EntryPoint") or key:match("^ExitPoint") then
			local frame = reply.Slots[key]
			for _, x in ipairs({ -0.5, 0.5 }) do
				for _, y in ipairs({ -0.5, 0.5 }) do
					for _, z in ipairs({ -0.5, 0.5 }) do
						local point =
							plane:PointToObjectSpace(frame:PointToWorldSpace(part.Size * Vector3.new(x, y, z)))
						low, high = low:Min(point), high:Max(point)
					end
				end
			end
		end
	end
	return { Plane = plane, Center = (low + high) / 2, Size = high - low }
end
function View.Frame(view, viewport)
	local fov = 38
	local aspect = math.max(viewport.X, 1) / math.max(viewport.Y, 1)
	local tangent = math.tan(math.rad(fov / 2))
	-- Overhead keeps both ends equally readable. Reserve room for labels/fingers.
	local width = math.max(view.Size.X + 0.24, 0.5)
	local height = math.max(view.Size.Z + 0.24, 0.5)
	local distance = math.max(width / (2 * tangent * aspect * 0.78), height / (2 * tangent * 0.68)) + view.Size.Y / 2
	distance = math.max(distance, 0.65)
	local focus = view.Plane:PointToWorldSpace(view.Center)
	local back = view.Plane.UpVector
	local right = view.Plane.RightVector
	return CFrame.fromMatrix(focus + back * distance, right, back:Cross(right), back), CFrame.new(focus), fov
end
return View
