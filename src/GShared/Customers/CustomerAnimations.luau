-- Public rig animations shared by world customers and dialogue portraits.
local Animations = {}
Animations.Female = table.freeze({
	Walking1 = "98117027734731",
	Walking2 = "103828761142770",
	SadWalking = "102600284986900",
	NormalWalking = "109605378463397",
	TuffWalking = "122931537095334",
	Running = "124881471754162",
	InjuredRunning = "92356860737882",
	GoofyRunning = "103881496028688",
	Angry = "97162108755836",
	Nervous = "88873563061859",
	HeadNodAgree = "126194927763383",
	Idle = "134499613517637",
	InjuredIdle = "83181888707865",
	BoredIdle = "93139162995869",
	AngryIdle = "96083173629081",
	HappyIdle = "99948840586856",
	Dance1 = "103484196758741",
	Dance2 = "75570490279860",
})
Animations.Male = table.freeze({
	TuffWalking = "85787183281728",
	MonkeyWalking = "109644390146731",
	SadWalking = "109257648780450",
	NormalWalking = "92516342133417",
	Running = "74163824001698",
	Angry = "80903870615789",
	Nervous = "83693909579538",
	HeadNodAgree = "100217274713361",
	AngryIdle = "105378302833858",
	HappyIdle = "99979548599754",
	Dance1 = "138369083074302",
	Dance2 = "70608021461333",
})
local walks = {
	Female = { "Walking1", "Walking2", "SadWalking", "NormalWalking", "TuffWalking" },
	Male = { "TuffWalking", "MonkeyWalking", "SadWalking", "NormalWalking" },
}
local idles = { Female = { "Idle", "BoredIdle", "HappyIdle" }, Male = { "HappyIdle", "Nervous" } }
function Animations.Get(gender, name, fallback)
	local catalog = Animations[gender == "Female" and "Female" or "Male"]
	return catalog[name] or catalog[fallback or "HappyIdle"]
end
function Animations.Has(name)
	return type(name) == "string" and (Animations.Female[name] ~= nil or Animations.Male[name] ~= nil)
end
function Animations.Pick(gender, activity, random)
	local key = gender == "Female" and "Female" or "Male"
	local pool = (activity == "Walk" and walks or idles)[key]
	return pool[(random or math.random)(1, #pool)]
end
return table.freeze(Animations)
