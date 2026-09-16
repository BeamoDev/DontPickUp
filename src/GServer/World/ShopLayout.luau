-- Two-room blockout: the repair shop and one shared stockroom.
local Layout = {}
Layout.Bounds = { -22, 22, -19, 23 }
Layout.Rooms = {
	Shop = { -21.5, 21.5, -18.5, 7.5 },
	Stockroom = { -21.5, 21.5, 8.5, 22.5 },
}
Layout.Access = {
	Fax = "Shop",
	Counter = "Shop",
	Secret_DeskNote = "Shop",
	Secret_Directive = "Shop",
	Secret_Warning = "Stockroom",
	Secret_RepairLog = "Shop",
	Secret_CustomerFile = "Stockroom",
	Secret_Newspaper = "Shop",
	Secret_Photograph = "Shop",
	Secret_Message = "Stockroom",
	Secret_Redacted = "Stockroom",
	Secret_Correction = "Shop",
	Answer = "Stockroom",
	Bench = "Shop",
	Bench2 = "Shop",
	Tools = "Shop",
	DeskLamp = "Shop",
	Records = "Shop",
	Secret_Timecard = "Stockroom",
	Secret_Tape = "Stockroom",
	Secret_Locker = "Stockroom",
	Tool_BrassKey = "Shop",
	Radio = "Stockroom",
	Fuse = "Stockroom",
	Phone = "Stockroom",
	Stock = "Stockroom",
	Part_Battery = "Stockroom",
	Part_Speaker = "Stockroom",
	Part_Keypad = "Stockroom",
}
local WALL = Color3.fromRGB(91, 87, 79)
function Layout.Build(p, sign)
	p("Ground", Vector3.new(90, 1, 110), Vector3.new(0, -0.5, 0), Color3.fromRGB(36, 36, 34), Enum.Material.Concrete)
	p(
		"ShopFloor",
		Vector3.new(44, 0.3, 42),
		Vector3.new(0, 0.15, 2),
		Color3.fromRGB(92, 86, 77),
		Enum.Material.Concrete
	)
	p("BackWall", Vector3.new(44, 13, 1), Vector3.new(0, 6.5, 23), WALL)
	p("LeftWall", Vector3.new(1, 13, 42), Vector3.new(-22, 6.5, 2), WALL)
	p("RightWallFront", Vector3.new(1, 13, 20), Vector3.new(22, 6.5, -9), WALL)
	p("RightWallBack", Vector3.new(1, 13, 14), Vector3.new(22, 6.5, 16), WALL)
	p("StaffDoorLintel", Vector3.new(1, 6, 8), Vector3.new(22, 10, 5), WALL)
	p("Roof", Vector3.new(45, 1, 43), Vector3.new(0, 13, 2), Color3.fromRGB(48, 47, 44))
	p("FrontLower", Vector3.new(44, 3, 1), Vector3.new(0, 1.5, -19), WALL)
	p("FrontUpper", Vector3.new(44, 3, 1), Vector3.new(0, 11.5, -19), WALL)
	for _, x in ipairs({ -17, 17 }) do
		p("WindowSide", Vector3.new(10, 7, 1), Vector3.new(x, 6.5, -19), WALL)
	end
	for y = 4, 9, 2 do
		p(
			"WindowBar",
			Vector3.new(24, 0.15, 0.2),
			Vector3.new(0, y, -19),
			Color3.fromRGB(90, 55, 37),
			Enum.Material.CorrodedMetal
		)
	end
	-- One wide doorway, no corridors or separate testing/software rooms.
	for _, x in ipairs({ -13, 13 }) do
		p("StockroomWall", Vector3.new(18, 12, 0.5), Vector3.new(x, 6, 8), WALL)
	end
	local doorway = p("StockroomDoorway", Vector3.new(8, 4, 0.5), Vector3.new(0, 10, 8), WALL)
	sign(doorway, "Stockroom", Vector3.new(0, -0.3, 0))
	local shelf = p("PartsShelf", Vector3.new(12, 3, 2.8), Vector3.new(-15, 1.5, 15), Color3.fromRGB(79, 80, 78))
	sign(shelf, "Replacement parts", Vector3.new(0, 2, 0))
	local chair = p("WaitingChair", Vector3.new(3, 1.4, 2.5), Vector3.new(-18, 0.9, -13), Color3.fromRGB(83, 69, 57))
	sign(chair, "Waiting chair")
	local shelter = p("Shelter", Vector3.new(8, 0.1, 5), Vector3.new(8, 0.4, 12), Color3.fromRGB(89, 85, 78))
	shelter.CanCollide = false
	sign(shelter, "Hide here", Vector3.new(0, 3, 0))
	return shelter
end
return Layout
