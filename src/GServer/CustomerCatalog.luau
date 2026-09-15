-- Server-only customer records. Never replicate the catalog or unrevealed evidence.
local Catalog = {}
local rows = {
	{
		"mara",
		"Mara Ellis",
		"Battery",
		"It dies whenever I try to call home.",
		"Thank you. My daughter is waiting.",
		"Normal",
	},
	{
		"arthur",
		"Arthur Bell",
		"Speaker",
		"The receiver crackles when the bus passes.",
		"Now I can hear the depot again.",
		"Normal",
	},
	{
		"nina",
		"Nina Vale",
		"Keypad",
		"The number seven keeps dialing itself.",
		"Please forget the name in that message.",
		"Unusual",
	},
	{
		"otto",
		"Otto Finch",
		"Battery",
		"It lasts ten minutes after charging.",
		"One less thing to replace this winter.",
		"Normal",
	},
	{
		"ruth",
		"Ruth Moss",
		"Speaker",
		"My sister sounds like she is underwater.",
		"She will be pleased I finally fixed it.",
		"Normal",
	},
	{
		"caleb",
		"Caleb Dunn",
		"Keypad",
		"The zero button sticks down.",
		"I nearly ordered a hundred loaves yesterday.",
		"Normal",
	},
	{
		"vera",
		"Vera Hale",
		"Battery",
		"The battery case feels loose.",
		"I need this for the morning delivery.",
		"Normal",
	},
	{
		"leon",
		"Leon Shaw",
		"Speaker",
		"The bell rings, but no voices come through.",
		"My wife thought I was ignoring her.",
		"Normal",
	},
	{
		"elsie",
		"Elsie Hart",
		"Keypad",
		"I spilled tea over the buttons.",
		"No more cups near the telephone. Understood.",
		"Normal",
	},
	{
		"reed",
		"Officer Reed",
		"Battery",
		"Install the department package. Check the power cell.",
		"Your cooperation has been recorded.",
		"Unusual",
	},
	{
		"david",
		"David Cole",
		"Speaker",
		"The sound cuts out when I tilt it.",
		"That is much clearer. Thank you.",
		"Normal",
	},
	{
		"ada",
		"Ada Marsh",
		"Keypad",
		"The call button needs both thumbs.",
		"My hands are not what they used to be.",
		"Normal",
	},
	{
		"simon",
		"Simon Webb",
		"Battery",
		"It shut off during my work call.",
		"Hopefully my supervisor will believe me.",
		"Normal",
	},
	{
		"iris",
		"Iris Lane",
		"Speaker",
		"Everyone sounds far away.",
		"I can hear the street through it again.",
		"Normal",
	},
	{
		"peter",
		"Peter Holt",
		"Keypad",
		"It dials two numbers whenever I press one.",
		"The butcher kept getting my messages.",
		"Normal",
	},
	{
		"jonas",
		"Jonas Pike",
		"Speaker",
		"A voice reads the same station number every night.",
		"Do not write my name beside that recording.",
		"Unusual",
	},
	{
		"mae",
		"Mae Cross",
		"Battery",
		"It will not stay on outside the charger.",
		"I was starting to miss the corded ones.",
		"Normal",
	},
	{
		"fred",
		"Fred Page",
		"Keypad",
		"The nine key fell into the casing.",
		"You saved me buying a whole new phone.",
		"Normal",
	},
	{
		"lena",
		"Lena Ward",
		"Speaker",
		"I dropped it on the kitchen floor.",
		"It survived better than the floor tile.",
		"Normal",
	},
	{
		"hugo",
		"Hugo Price",
		"Battery",
		"The indicator says full. It is never full.",
		"An honest battery. That makes a change.",
		"Normal",
	},
	{
		"agnes",
		"Agnes North",
		"Keypad",
		"The numbers have stopped responding.",
		"Please put it back in the cloth bag.",
		"Normal",
	},
	{
		"tom",
		"Tom Birch",
		"Speaker",
		"The receiver buzzes after a long call.",
		"The warehouse can finally reach me.",
		"Normal",
	},
	{
		"edna",
		"Edna Frost",
		"Battery",
		"A charge used to last through my shift.",
		"I will be more careful with it.",
		"Normal",
	},
	{
		"silas",
		"Silas Grey",
		"Keypad",
		"There is a number I cannot delete.",
		"If anyone asks, I came for a new keypad.",
		"Unusual",
	},
	{
		"beth",
		"Beth Stone",
		"Speaker",
		"I can barely hear the person calling.",
		"Now I can talk without shouting.",
		"Normal",
	},
	{
		"albert",
		"Albert Nash",
		"Battery",
		"It stopped working in the cold.",
		"I will keep it inside my coat.",
		"Normal",
	},
	{
		"clara",
		"Clara Dean",
		"Keypad",
		"The green button does nothing.",
		"My son said it was beyond repair.",
		"Normal",
	},
	{
		"felix",
		"Felix Roe",
		"Speaker",
		"The speaker rattles against the cover.",
		"You work quickly. Get some rest tonight.",
		"Normal",
	},
	{
		"mira",
		"Mira Voss",
		"Battery",
		"It stays warm after I switch it off.",
		"There was no phone in that photograph before.",
		"Unusual",
	},
	{
		"duplicate",
		"Mara Ellis",
		"Keypad",
		"You repaired this tomorrow. I remember you.",
		"Do not turn around when the lights go out.",
		"Anomaly",
	},
}
local evidence = {
	nina = {
		Id = "prototype_ward7",
		Message = "DELETED MESSAGE: 'Nina, Ward 7 is not empty. They can hear us.'",
		Discovery = "WARD 7. The missing patients are still being moved after curfew.",
	},
	jonas = {
		Id = "prototype_station9",
		Message = "RECORDING: 'Station Nine. Transfer Ward Seven before the morning inspection.'",
		Discovery = "Station Nine and Ward Seven share the same overnight transport route.",
	},
	silas = {
		Id = "prototype_transport",
		Message = "DRAFT: 'The transfer list says discharged. None of them came home.'",
		Discovery = "A transport record links the missing names to a government warehouse.",
	},
}
Catalog.Customers = {}
for index, row in ipairs(rows) do
	table.insert(Catalog.Customers, {
		Id = row[1],
		Name = row[2],
		Fault = row[3],
		Complaint = row[4],
		Line = row[5],
		Kind = row[6],
		Device = ({ "Kestrel C2", "Civic Service 80", "Morrow Portable" })[(index - 1) % 3 + 1],
		Fee = index == 1 and 45 or 40 + (index % 5) * 5,
		Patience = 130 + (index % 4) * 15,
		Coat = ({ { 105, 88, 58 }, { 64, 75, 72 }, { 88, 70, 64 }, { 61, 67, 49 } })[(index - 1) % 4 + 1],
		Evidence = evidence[row[1]],
	})
end

local firstNames = {
	"Agnes",
	"Basil",
	"Celia",
	"Dorian",
	"Esther",
	"Frank",
	"Grace",
	"Harold",
	"Irene",
	"Jasper",
	"Kara",
	"Lewis",
	"Mabel",
	"Norman",
	"Olive",
	"Perry",
	"Quinn",
	"Rose",
	"Simon",
	"Tessa",
}
local surnames = {
	"Abbott",
	"Brooks",
	"Cross",
	"Drake",
	"Everett",
	"Fields",
	"Grant",
	"Hughes",
	"Irwin",
	"Jones",
	"Kent",
	"Lane",
}
local occupations = {
	"tram driver",
	"night nurse",
	"factory worker",
	"postal clerk",
	"teacher",
	"cleaner",
	"caretaker",
	"baker",
	"dock worker",
	"radio operator",
	"mechanic",
	"librarian",
}
local complaints = {
	Battery = {
		"It shuts off when the bell rings.",
		"The charge disappears during my shift.",
		"It only works beside the charger.",
		"The battery was replaced last week. It is dead again.",
		"The power light fades when I lift the receiver.",
		"It loses power whenever the room gets cold.",
		"The battery contacts are loose.",
		"It stopped charging after the delivery.",
		"It runs for one call, then dies.",
		"The battery case gets warm in my pocket.",
		"Someone put the battery in backwards.",
		"It went dead during a call from the depot.",
	},
	Speaker = {
		"Everyone sounds far away.",
		"The receiver crackles when I speak.",
		"It rings but nobody can hear me.",
		"Voices disappear when I tilt the phone.",
		"The speaker rattles inside the case.",
		"All I can hear is a low hum.",
		"The receiver went silent halfway through a call.",
		"My voice comes back as an echo.",
		"There is a clicking noise under every voice.",
		"The bell works. The receiver does not.",
		"Rain got into the earpiece.",
		"A wire came loose inside the receiver.",
	},
	Keypad = {
		"The zero key stays pressed.",
		"Every number appears twice.",
		"I cannot dial the last digit.",
		"The green key no longer responds.",
		"Three buttons stopped working together.",
		"The keys stick when the room gets damp.",
		"The number five needs a hard press.",
		"It dials a different number from the one I enter.",
		"The cancel button does nothing.",
		"The keys stopped after I spilled tea.",
		"Somebody pulled the keypad ribbon loose.",
		"It refuses to dial after curfew.",
	},
}
local strangeLines = {
	"The number on my timecard changed overnight.",
	"Please do not write my address down.",
	"Someone at the exchange already knew I was coming.",
	"The voice sounded like me, only older.",
}
local anomalyLines = {
	"You gave this back to me tomorrow.",
	"The phone rang while the battery was on your table.",
	"There were two of you at the window a moment ago.",
}
Catalog.Devices = {
	"Kestrel C2",
	"Civic Service 80",
	"Morrow Portable",
	"Crown 14",
	"Kestrel Field Unit",
	"Civic Deskline",
	"Morrow S4",
	"Union Receiver",
	"Crown Traveller",
	"State Exchange 6",
	"Harbour Service Set",
	"Railway C3",
}
Catalog.Requirements = {
	{ Name = "Standard service", Contacts = 3, SequenceLength = 4 },
	{ Name = "Quick contact check", Contacts = 2, SequenceLength = 3 },
	{ Name = "Depot acceptance test", Contacts = 3, SequenceLength = 5 },
	{ Name = "Exchange calibration", Contacts = 2, SequenceLength = 6 },
	{ Name = "Cold-weather service", Contacts = 3, SequenceLength = 4 },
	{ Name = "Factory inspection", Contacts = 3, SequenceLength = 6 },
	{ Name = "Receiver certification", Contacts = 2, SequenceLength = 5 },
	{ Name = "Overnight delivery check", Contacts = 3, SequenceLength = 5 },
	{ Name = "Transit safety check", Contacts = 2, SequenceLength = 4 },
	{ Name = "Government acceptance", Contacts = 3, SequenceLength = 6 },
	{ Name = "Workshop recalibration", Contacts = 3, SequenceLength = 3 },
	{ Name = "Archive unit inspection", Contacts = 2, SequenceLength = 6 },
}
for a, first in ipairs(firstNames) do
	for b, last in ipairs(surnames) do
		local n = (a - 1) * #surnames + b
		local fault = ({ "Battery", "Speaker", "Keypad" })[(n - 1) % 3 + 1]
		local kind = n % 20 == 0 and "Anomaly" or n % 20 >= 16 and "Unusual" or "Normal"
		table.insert(Catalog.Customers, {
			Id = "resident_" .. n,
			Name = first .. " " .. last,
			Fault = fault,
			Complaint = complaints[fault][(a + b - 2) % #complaints[fault] + 1],
			Line = kind == "Anomaly" and anomalyLines[n % #anomalyLines + 1]
				or kind == "Unusual" and strangeLines[n % #strangeLines + 1]
				or "Thank you. I need this for my work as a " .. occupations[b] .. ".",
			Kind = kind,
			Device = Catalog.Devices[(n - 1) % #Catalog.Devices + 1],
			Fee = 40 + n % 7 * 5,
			Patience = 145 + n % 5 * 12,
			Coat = { 50 + n % 9 * 6, 55 + n % 7 * 5, 45 + n % 6 * 6 },
		})
	end
end

function Catalog.Job(customer, random, tutorial, night)
	local requirement = tutorial and Catalog.Requirements[1]
		or Catalog.Requirements[random(1, #Catalog.Requirements)]
	local pressure = math.min(math.max(0, (night or 1) - 1), 10)
	return {
		Fault = customer.Fault,
		Complaint = customer.Complaint,
		Device = tutorial and customer.Device or Catalog.Devices[random(1, #Catalog.Devices)],
		Fee = (customer.Fee or 45) + (tutorial and 0 or (requirement.SequenceLength - 3) * 5),
		Patience = math.max(120, (customer.Patience or 160) + requirement.SequenceLength * 3 - pressure * 3),
		Requirement = requirement.Name,
		Contacts = requirement.Contacts,
		SequenceLength = tutorial and 4 or math.min(6, requirement.SequenceLength + math.floor(pressure / 4)),
	}
end

function Catalog.Deck(random, mode, chapterCustomer)
	local deck = {}
	-- Keep the introduction stable; later customers shuffle without repeats per cycle.
	for index = mode == "Endless" and 2 or 4, #Catalog.Customers do
		if mode ~= "Story" or not Catalog.Customers[index].Evidence then
			table.insert(deck, index)
		end
	end
	for index = #deck, 2, -1 do
		local other = random(1, index)
		deck[index], deck[other] = deck[other], deck[index]
	end
	if mode == "Endless" then
		-- The first post-training job is ordinary, but its identity is unpredictable.
		for index, customer in ipairs(deck) do
			if Catalog.Customers[customer].Kind == "Normal" then
				deck[1], deck[index] = deck[index], deck[1]
				break
			end
		end
		table.insert(deck, 1, 1)
		return deck
	end
	local clue = 3
	if mode == "Story" and chapterCustomer then
		for index, customer in ipairs(Catalog.Customers) do
			if customer.Id == chapterCustomer then
				clue = index
				break
			end
		end
	end
	table.insert(deck, 1, clue)
	table.insert(deck, 1, 2)
	table.insert(deck, 1, 1)
	return deck
end

return Catalog
