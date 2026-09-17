-- One headshot conversion per HUD lifetime; never changes world lighting.
local Mugshot = {}
Mugshot.__index = Mugshot

Mugshot.Grayscale = require(script.Parent.GrayscaleImage).Pixels

function Mugshot.new(label, userId, assets)
	return setmetatable({ label = label, userId = userId, assets = assets }, Mugshot)
end

function Mugshot:Show()
	if self.started or self.destroyed then
		return
	end
	self.started = true
	self.original = self.label.ImageContent
	self.originalColor = self.label.ImageColor3
	self.label.ImageColor3 = Color3.new(1, 1, 1)
	local uri = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(self.userId) .. "&w=150&h=150"
	self.label.Image = uri -- Usable headshot while loading, also the fallback when Image APIs are disabled.
	task.spawn(function()
		local editable
		local ok = pcall(function()
			editable = self.assets:CreateEditableImageAsync(Content.fromUri(uri))
			if not editable or self.destroyed then
				return
			end
			local pixels = editable:ReadPixelsBuffer(Vector2.zero, editable.Size)
			editable:WritePixelsBuffer(Vector2.zero, editable.Size, Mugshot.Grayscale(pixels))
			self.label.ImageContent = Content.fromObject(editable)
			self.image = editable
		end)
		if editable and (not ok or self.destroyed) then
			editable:Destroy()
		end
		if not self.destroyed then
			self.label:SetAttribute("DPU_GrayscaleReady", ok and self.image ~= nil)
			if not ok or not self.image then
				warn("[DPU] Grayscale mugshot unavailable; using the regular headshot. Check Mesh / Image API access.")
			end
		end
	end)
end

function Mugshot:Destroy()
	self.destroyed = true
	if self.started then
		self.label.ImageContent = self.original
		self.label.ImageColor3 = self.originalColor
		self.label:SetAttribute("DPU_GrayscaleReady", nil)
	end
	if self.image then
		self.image:Destroy()
		self.image = nil
	end
end

return Mugshot
