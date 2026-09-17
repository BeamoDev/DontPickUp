-- Authored shop access bounds, relative to ShopFloor. No map construction.
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
	Answer = "Shop",
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
	Phone = "Shop",
	Stock = "Stockroom",
	Part_Battery = "Stockroom",
	Part_Speaker = "Stockroom",
	Part_Keypad = "Stockroom",
}
return Layout
