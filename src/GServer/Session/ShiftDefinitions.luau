-- Server-only repair transitions and short player instructions.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("GShared", 30)
assert(Shared, "Sync src/GShared to ReplicatedStorage.GShared in the Game place")
local Public = require(Shared:WaitForChild("Repair", 30):WaitForChild("RepairDefinitions", 30))
local WORK = Public.NextStep
local BENCHES = Public.Benches
local STATIONS = {
	OpenFax = "Fax",
	DialTicket = "Fax",
	TakeOrder = "Counter",
	Diagnose = "Bench",
	Collect = "Stock",
	Repair = "Bench",
	Install = "Bench",
	Test = "Bench",
	Return = "Counter",
	Restock = "Stock",
	RestorePower = "Fuse",
	Silence = "Phone",
	Answer = "Phone",
	Records = "Records",
	Sit = "Bench",
	DepositPart = "Bench",
	Secure = "Bench",
	PuzzleInput = "Bench",
}
local OPTIONAL = { ToggleDoor = "StaffDoor", TuneRadio = "Radio", InspectRecords = "Records", ToggleLamp = "DeskLamp" }
local BULLETINS = {
	"CITY RADIO: The last tram leaves at six. All night staff must carry identification.",
	"SERVICE BAND: Deliveries to Ward Seven have been redirected. Do not record this message.",
	"DEAD AIR: ...we can see the repair shop...",
}
local OBJECTIVES = {
	Arriving = "A customer is approaching the service window.",
	Waiting = "Go to the counter and take the customer's phone.",
	Diagnose = "Sit at the bench. Remove screws, cover and battery, then diagnose the fault.",
	Collect = "Stand up. Get the marked part from the back room.",
	Repair = "Put the new part on the bench. Sit down to put it in the phone.",
	Secure = "Put the phone back together. Tighten all four screws.",
	Install = "Open the customer phone. Install the program, or explore its messages and calls.",
	Evidence = "Read the recovered message. Your team must choose what to do.",
	Test = "Check that the phone works before giving it back.",
	ReadyForPickup = "Use the FAX PHONE. Enter the six-digit ticket to call the customer.",
	PickupArriving = "The customer is on the way to collect their phone.",
	Return = "Go to the counter and give the fixed phone back.",
}

return {
	WORK = WORK,
	BENCHES = BENCHES,
	STATIONS = STATIONS,
	OPTIONAL = OPTIONAL,
	BULLETINS = BULLETINS,
	OBJECTIVES = OBJECTIVES,
}
