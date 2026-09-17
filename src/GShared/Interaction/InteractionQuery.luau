-- Bounded world queries used by client picking and server validation.
local Tags = require(script.Parent.InteractionTags)
local Query = {}
Query.MaxHits = 12

function Query.SurfacePoint(part, position)
	local point = part.CFrame:PointToObjectSpace(position)
	local half = part.Size * 0.5
	return part.CFrame:PointToWorldSpace(
		Vector3.new(
			math.clamp(point.X, -half.X, half.X),
			math.clamp(point.Y, -half.Y, half.Y),
			math.clamp(point.Z, -half.Z, half.Z)
		)
	)
end

function Query.Distance(part, position)
	return (position - Query.SurfacePoint(part, position)).Magnitude
end

function Query.Cast(world, collection, origin, direction, params, excluded, resolve, inspectionOwner)
	-- Keep the original segment, never extend reach while skipping decoration.
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true
	params.RespectCanCollide = false
	local skipped = table.clone(excluded)
	for _ = 1, Query.MaxHits do
		params.FilterDescendantsInstances = skipped
		local hit = world:Raycast(origin, direction, params)
		if not hit then
			return nil
		end
		local item = resolve and resolve(hit.Instance)
		if item then
			return hit, item
		end
		local part = hit.Instance
		-- Tagged but unavailable items still occlude. Collidable geometry (including
		-- transparent walls) always blocks; non-collidable untagged decoration does not.
		local tagged = collection and Tags.Resolve(collection, world, part)
		if (tagged and tagged ~= inspectionOwner) or not part:IsA("BasePart") or part.CanCollide ~= false then
			return hit
		end
		table.insert(skipped, part)
	end
	-- Fail closed if the decoration budget is exhausted.
	return { Instance = skipped[#skipped], Position = origin }, nil
end

function Query.Visible(world, collection, character, head, part, owner, resolve)
	local params = RaycastParams.new()
	local half = part.Size * 0.49
	local points = {
		Query.SurfacePoint(part, head.Position),
		part.Position,
		part.CFrame:PointToWorldSpace(Vector3.new(0, 0, -half.Z)),
		part.CFrame:PointToWorldSpace(Vector3.new(0, 0, half.Z)),
		part.CFrame:PointToWorldSpace(Vector3.new(-half.X, 0, 0)),
		part.CFrame:PointToWorldSpace(Vector3.new(half.X, 0, 0)),
		part.CFrame:PointToWorldSpace(Vector3.new(0, half.Y, 0)),
		part.CFrame:PointToWorldSpace(Vector3.new(0, -half.Y, 0)),
	}
	for _, destination in ipairs(points) do
		local hit, target = Query.Cast(
			world,
			collection,
			head.Position,
			destination - head.Position,
			params,
			{ character },
			function(candidate)
				return (
					candidate == part
					or (owner and candidate:IsDescendantOf(owner))
					or (resolve and resolve(candidate))
				)
						and part
					or nil
			end
		)
		if not hit or target then
			return true
		end
	end
	return false
end

return table.freeze(Query)
