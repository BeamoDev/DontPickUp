-- One public definition of the authored tags, shared by client picking and server binding.
local Tags = {
	Names = table.freeze({ "Drink", "Fax", "Container", "throw", "tv", "PhoneRepair", "Customer" }),
	Distance = 8,
	DrinkSeconds = 0.5,
}

function Tags.Kind(collection, item)
	if not item or not (item:IsA("Model") or item:IsA("BasePart")) then
		return nil
	end
	for _, tag in ipairs(Tags.Names) do
		if collection:HasTag(item, tag) and (tag == "Drink" or tag == "throw" or item:IsA("Model")) then
			return tag
		end
	end
	return nil
end

function Tags.Resolve(collection, world, hit)
	if not hit or not hit:IsDescendantOf(world) then
		return nil
	end
	local item = hit
	while item and item ~= world do
		local kind = Tags.Kind(collection, item)
		if kind then
			return item, kind
		end
		item = item.Parent
	end
	return nil
end

return table.freeze(Tags)
