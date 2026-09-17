local Shared = game:GetService("ReplicatedStorage"):WaitForChild("GShared", 30)
local Animations = require(Shared:WaitForChild("Customers", 30):WaitForChild("CustomerAnimations", 30))
local portraitPosition = CFrame.new(-176.935, -0.063, -51.505)
local Config = {
	TestEnabled = false, -- Customer orders now drive real conversations.
	TestDelay = 10,
	TitleCharactersPerSecond = 28,
	CharactersPerSecond = 34,
	ReadSeconds = 2.2,
	ShowSeconds = 0.3,
	HideSeconds = 0.2,
	PortraitCameraFrame = CFrame.new(-163.297, 6.866, -51.514)
		* CFrame.fromOrientation(math.rad(-2.676), math.rad(90.098), 0),
	PortraitFieldOfView = 10,
	PortraitTransforms = table.freeze({
		NPC = portraitPosition * CFrame.fromOrientation(math.rad(90), math.rad(180), 0),
		You = portraitPosition * CFrame.fromOrientation(0, math.rad(-90), 0),
	}),
	NPCAnimations = Animations.Male, -- Compatibility for existing presentation callers.
	IsNPCAnimation = Animations.Has,
	DefaultNPCAnimation = "HappyIdle",
	PlayerIdleR15 = "507766666",
	PlayerIdleR6 = "180435571",
	YouColor = Color3.fromRGB(166, 202, 161),
	CustomerColor = Color3.fromRGB(224, 185, 143),
	TestConversation = table.freeze({
		table.freeze({ Speaker = "NPC", Animation = "HappyIdle", Text = "The line is working. Can you hear me?" }),
		table.freeze({ Speaker = "You", Text = "I can hear you." }),
		table.freeze({
			Speaker = "NPC",
			Animation = "HeadNodAgree",
			Text = "Good. Take a look at the phone on the desk.",
		}),
		table.freeze({ Speaker = "I", Text = "All right. I'll take a look." }),
	}),
}
function Config.Speaker(value)
	if type(value) ~= "string" then
		return nil
	end
	local key = value:lower()
	if key == "you" or key == "i" then
		return "You", "You"
	end
	if key == "npc" or key == "customer" then
		return "NPC", "Customer"
	end
	return nil
end
return table.freeze(Config)
