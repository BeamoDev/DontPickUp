-- Converts only the disposable viewport clone. No world effects, camera changes or render loops.
local Grayscale = require(script.Parent.GrayscaleImage)
local Portrait = {}
Portrait.__index = Portrait
local MAX_IMAGES, MAX_PIXELS = 8, 1024 * 1024
function Portrait.new(model, assets)
	local self = setmetatable({ model = model, assets = assets, images = {}, pixels = 0, count = 0 }, Portrait)
	local jobs = {}
	for _, item in ipairs(model:GetDescendants()) do
		if item:IsA("BasePart") then
			item.Color = Grayscale.Color(item.Color)
		elseif item:IsA("BodyColors") then
			for _, name in ipairs({ "Head", "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg" }) do
				item[name .. "Color3"] = Grayscale.Color(item[name .. "Color3"])
			end
		elseif item:IsA("Decal") or item:IsA("Texture") then
			item.Color3 = Grayscale.Color(item.Color3)
		end
		local uri, property, target, surface
		if item:IsA("MeshPart") then
			surface = item:FindFirstChildWhichIsA("SurfaceAppearance")
			uri = surface and surface.ColorMap ~= "" and surface.ColorMap or item.TextureID
			property, target = "TextureContent", item
		elseif item:IsA("Decal") or item:IsA("Texture") then
			uri, property, target = item.Texture, "ColorMapContent", item
		elseif
			(item:IsA("SpecialMesh") and item.TextureId ~= "")
			or (item:IsA("Shirt") and item.ShirtTemplate ~= "")
			or (item:IsA("Pants") and item.PantsTemplate ~= "")
			or (item:IsA("ShirtGraphic") and item.Graphic ~= "")
		then
			-- These legacy texture properties do not accept an EditableImage. Keep the authored outfit.
			self.partial = true
		end
		if type(uri) == "string" and uri ~= "" then
			table.insert(jobs, { uri = uri, target = target, property = property, surface = surface })
		end
	end
	model:SetAttribute("DPU_GrayscaleReady", false)
	task.spawn(function()
		for _, job in ipairs(jobs) do
			if self.closed then
				return
			end
			local image = self:Image(job.uri)
			if self.closed then
				return
			end
			if image then
				local ok = pcall(function()
					job.target[job.property] = Content.fromObject(image)
					-- Viewports use the mesh texture; replacing its color map avoids retaining colored PBR art.
					if job.surface then
						job.surface:Destroy()
					end
				end)
				self.partial = self.partial or not ok
			else
				self.partial = true
			end
		end
		if not self.closed then
			model:SetAttribute("DPU_GrayscaleReady", not self.partial)
			model:SetAttribute("DPU_GrayscalePartial", self.partial == true)
		end
	end)
	return self
end
function Portrait:Image(uri)
	if self.images[uri] ~= nil then
		return self.images[uri]
	end
	self.images[uri] = false -- Failed assets are not repeatedly requested for each limb.
	if self.count >= MAX_IMAGES or self.pixels >= MAX_PIXELS then
		return nil
	end
	self.count += 1
	local image
	local ok = pcall(function()
		local assets = self.assets or game:GetService("AssetService")
		image = assets:CreateEditableImageAsync(Content.fromUri(uri))
		if not image or self.closed or self.pixels + image.Size.X * image.Size.Y > MAX_PIXELS then
			return
		end
		-- Small strips bound CPU work per frame even for 1024px customer textures.
		for y = 0, image.Size.Y - 1, 16 do
			if self.closed then
				return
			end
			local position, size = Vector2.new(0, y), Vector2.new(image.Size.X, math.min(16, image.Size.Y - y))
			image:WritePixelsBuffer(position, size, Grayscale.Pixels(image:ReadPixelsBuffer(position, size)))
			if y + 16 < image.Size.Y then
				task.wait()
			end
		end
		self.pixels += image.Size.X * image.Size.Y
		self.images[uri] = image
	end)
	if image and (not ok or self.closed or self.images[uri] ~= image) then
		image:Destroy()
		self.images[uri] = false
	end
	return not self.closed and self.images[uri] or nil
end
function Portrait:Destroy()
	if self.closed then
		return
	end
	self.closed = true
	for _, image in pairs(self.images) do
		if image then
			image:Destroy()
		end
	end
	table.clear(self.images)
end
return Portrait
