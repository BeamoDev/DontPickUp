-- Public repair vocabulary only. No generated answers, seeds, story content or run state.
local Definitions = {
	Gear = {
		Diagnose = "Tester",
		Repair = "Screwdriver",
		Install = "Cartridge",
		Test = "Tester",
		Secure = "Screwdriver",
	},
	NextStep = {
		Diagnose = "Collect",
		Collect = "Repair",
		Repair = "Secure",
		Secure = "Install",
		Install = "Test",
		Test = "ReadyForPickup",
	},
	Benches = { Bench = true, Bench2 = true },
	TaskKinds = { Probes = true, BatteryFit = true, Wires = true, Circuit = true, Dials = true, Memory = true },
	PartNames = { "BATTERY", "SPEAKER", "KEYPAD" },
	StepNames = {
		Arriving = "Customer on the way",
		Waiting = "Take the phone",
		Diagnose = "Find the broken part",
		Collect = "Get a new part",
		Repair = "Put in the new part",
		Secure = "Put the phone back together",
		Install = "Open the customer phone",
		Evidence = "Vote on the strange message",
		Test = "Check that the phone works",
		ReadyForPickup = "Call the customer on the fax phone",
		PickupArriving = "Customer coming to collect",
		Return = "Give the phone back",
	},
}
for _, value in pairs(Definitions) do
	table.freeze(value)
end
return table.freeze(Definitions)
