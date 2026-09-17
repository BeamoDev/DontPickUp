local Grayscale = {}
function Grayscale.Color(color)
	local value = color.R * 0.2126 + color.G * 0.7152 + color.B * 0.0722
	return Color3.new(value, value, value)
end
function Grayscale.Pixels(pixels)
	for offset = 0, buffer.len(pixels) - 4, 4 do
		local value = math.floor(
			buffer.readu8(pixels, offset) * 0.2126
				+ buffer.readu8(pixels, offset + 1) * 0.7152
				+ buffer.readu8(pixels, offset + 2) * 0.0722
				+ 0.5
		)
		buffer.writeu8(pixels, offset, value)
		buffer.writeu8(pixels, offset + 1, value)
		buffer.writeu8(pixels, offset + 2, value)
	end
	return pixels
end
return Grayscale
