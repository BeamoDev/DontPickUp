-- Public presentation/authoring defaults. Only the server accepts an open/close.
local Config = {
	OpenOffset = Vector3.new(0, 0, -0.8), -- Cabinet-local forward (-Z), rotated into world space once when bound.
	TweenSeconds = 0.35,
	Distance = 8,
	IsBox = function(part)
		return part:IsA("BasePart") and part.Name:match("^Box%d*$") ~= nil
	end,
}

-- A drawer surface includes authored descendants and its paired direct label.
function Config.ResolveBox(part, folder)
	if not part or not part:IsDescendantOf(folder) then
		return nil
	end
	local child = part
	while child.Parent ~= folder do
		child = child.Parent
	end
	if Config.IsBox(child) then
		return child
	end
	local suffix = child.Name:match("^Label(%d*)$")
	return suffix and folder:FindFirstChild("Box" .. suffix) or nil
end

return table.freeze(Config)
