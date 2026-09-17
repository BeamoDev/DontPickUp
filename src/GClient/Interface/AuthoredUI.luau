-- Binds the saved play-session UI without recreating or restyling it.
-- Older generated controls have repeated class names; claim each sibling once.
local UI = {}
local claimed = setmetatable({}, { __mode = "k" })
local saved = setmetatable({}, { __mode = "k" })
local generated = setmetatable({}, { __mode = "k" })
local groups = {
	GuiObject = {
		"Visible",
		"Position",
		"Size",
		"AnchorPoint",
		"BackgroundTransparency",
		"BackgroundColor3",
		"Rotation",
		"Active",
		"BorderSizePixel",
		"ZIndex",
	},
	ScreenGui = { "Enabled", "ResetOnSpawn" },
	TextLabel = {
		"Text",
		"MaxVisibleGraphemes",
		"TextSize",
		"TextScaled",
		"TextWrapped",
		"TextColor3",
		"TextTransparency",
		"TextStrokeTransparency",
		"TextXAlignment",
		"TextYAlignment",
		"Font",
	},
	GuiButton = { "Selectable", "AutoButtonColor" },
	ImageLabel = { "Image", "ImageColor3", "ImageTransparency" },
	ViewportFrame = { "ImageColor3", "ImageTransparency", "CurrentCamera" },
	Highlight = {
		"Enabled",
		"Adornee",
		"FillTransparency",
		"OutlineTransparency",
		"OutlineColor",
		"FillColor",
		"DepthMode",
	},
	Camera = { "CFrame", "FieldOfView" },
	Sound = { "Volume", "PlaybackSpeed", "Looped", "SoundId" },
	BasePart = { "CFrame", "Color", "Transparency" },
	UISizeConstraint = { "MinSize", "MaxSize" },
	UIStroke = { "Color", "Transparency", "Thickness" },
}
function UI.Bind(class, parent, name, initial)
	name = name or class
	assert(parent, "[DPU] Missing parent for authored UI " .. name)
	local item
	for _, child in ipairs(parent:GetChildren()) do
		if child.Name == name and child:IsA(class) and not claimed[child] then
			item = child
			break
		end
	end
	assert(
		item,
		"[DPU] Missing authored "
			.. parent:GetFullName()
			.. "."
			.. name
			.. " ("
			.. class
			.. "). Keep the full cloned HUD hierarchy."
	)
	claimed[item] = true
	local state = { Parent = { item.Parent } }
	for kind, keys in pairs(groups) do
		if
			item:IsA(kind)
			or (kind == "TextLabel" and item:IsA("TextButton"))
			or (kind == "ImageLabel" and item:IsA("ImageButton"))
		then
			for _, key in ipairs(keys) do
				state[key] = { item[key] }
			end
		end
	end
	saved[item] = state
	for key, value in pairs(initial or {}) do
		item[key] = value
	end
	return item
end
function UI.Highlight(parent, name, defaults)
	assert(parent, "[DPU] Missing parent for interaction highlight " .. name)
	for _, child in ipairs(parent:GetChildren()) do
		if child.Name == name and child:IsA("Highlight") and not claimed[child] then
			return UI.Bind("Highlight", parent, name, { Enabled = false, Adornee = nil })
		end
	end
	-- Only this disposable effect may be generated; fixed authored map/UI bindings remain strict.
	local item = Instance.new("Highlight")
	item.Name, item.Enabled, item.Adornee = name, false, nil
	item.FillTransparency, item.OutlineTransparency = 0.9, 0
	for key, value in pairs(defaults or {}) do
		item[key] = value
	end
	item.Parent = parent
	generated[item], claimed[item] = true, true
	return item
end
function UI.Release(item)
	if not item then
		return
	end
	if generated[item] then
		generated[item], claimed[item] = nil, nil
		item:Destroy()
		return
	end
	local descendants = item:GetDescendants()
	table.insert(descendants, item)
	for _, child in ipairs(descendants) do
		local state = saved[child]
		if state then
			for key, value in pairs(state) do
				pcall(function()
					child[key] = value[1]
				end)
			end
			saved[child], claimed[child] = nil, nil
		end
	end
end
return UI
