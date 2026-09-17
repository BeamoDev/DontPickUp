-- Private order content and tuning. Only the active repair ticket is replicated.
return table.freeze({
	StudioBench = true,
	FirstArrivalSeconds = 3,
	ArrivalSeconds = 3,
	DepartureSeconds = 3,
	BetweenOrdersSeconds = 6,
	-- The owner's Assets.NPC has this authored orientation. Override on a world
	-- template with a CustomerRotation Vector3 attribute (degrees) if necessary.
	CustomerRotation = Vector3.new(90, 180, 0),
	Customers = {
		{
			Name = "M. Ellis",
			Problem = "Phone loses power. Reconnect the four internal wires.",
			Greeting = "It keeps cutting out. Could you check the wires inside?",
			Thanks = "It stays on now. Thank you. I need it for work.",
			Mood = "Nervous",
		},
		{
			Name = "A. Ward",
			Problem = "Loose internal connections. Reconnect all four wires.",
			Greeting = "I dropped this on the stairs. It hasn't worked properly since.",
			Thanks = "That's better. I'll try to be more careful this time.",
			Mood = "HappyIdle",
		},
		{
			Name = "R. Hale",
			Problem = "Intermittent power. Repair the internal wiring.",
			Greeting = "The power comes and goes. Please have a look before my shift.",
			Thanks = "Working again. Good. I can still get there on time.",
			Mood = "AngryIdle",
		},
	},
})
