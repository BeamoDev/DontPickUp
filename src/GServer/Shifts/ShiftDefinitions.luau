-- Server-only repair transitions and short player instructions.
local WORK = {
	Diagnose = "Collect",
	Collect = "Repair",
	Repair = "Secure",
	Secure = "Install",
	Install = "Test",
	Test = "Return",
}
local BENCHES = { Bench = true, Bench2 = true }
local STATIONS = {
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
	Diagnose = "Sit at the repair bench. Find the broken part.",
	Collect = "Stand up. Get the marked part from the back room.",
	Repair = "Put the new part on the bench. Sit down to put it in the phone.",
	Secure = "Put the phone back together. Tighten all four screws.",
	Install = "Stay at the bench. Add the required program to the phone.",
	Evidence = "Read the recovered message. Your team must choose what to do.",
	Test = "Check that the phone works before giving it back.",
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
