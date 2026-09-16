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
	Waiting = "Go to INTAKE and accept the customer's phone.",
	Diagnose = "Sit at the REPAIR BENCH and diagnose the phone.",
	Collect = "Stand up and collect the marked part from the back STOCKROOM.",
	Repair = "Carry the replacement to the bench, place it down, then sit to fit it.",
	Secure = "Reassemble the phone and tighten all four screws at the bench.",
	Install = "Install the government software at REPAIR BENCH.",
	Evidence = "Read the recovered message. Your team must choose what to do.",
	Test = "Run the final checks at the REPAIR BENCH.",
	Return = "Go to INTAKE and return the phone to its customer.",
}

return {
	WORK = WORK,
	BENCHES = BENCHES,
	STATIONS = STATIONS,
	OPTIONAL = OPTIONAL,
	BULLETINS = BULLETINS,
	OBJECTIVES = OBJECTIVES,
}
