-- Authored speech, never player chat. Future conversations remain server-only.
local Conversations = {}
local normal = {
	{ "Did you try turning it off?", "Yes. That is the part it is good at." },
	{ "Any water damage?", "Only tea. I thought that was different." },
	{ "Anything else wrong with it?", "My boss still calls." },
	{ "It should be a quick fix.", "Good. I left soup in charge of the stove." },
	{ "When did it stop working?", "Just after I said it would last forever." },
	{ "Have you dropped it?", "Not on purpose. Mostly." },
}
local odd = {
	{ "Does it always do that?", "Only when nobody is listening." },
	{ "Who is on the other end?", "Me. Apparently I sound tired tomorrow." },
	{ "Is that your number?", "It was. Before the number moved out." },
}
local function line(speaker, text, userId)
	return { Speaker = speaker, Text = text, UserId = userId }
end
local function customer(order, text)
	return { Speaker = order.Customer, Text = text, AppearanceId = order.AppearanceId }
end
function Conversations.Intake(order, player)
	if order.CaseId then
		return {
			customer(order, order.Complaint),
			line(player.DisplayName, "I'll check the " .. string.lower(order.Fault) .. " first.", player.UserId),
		}
	end
	local pair = (order.Kind == "Normal" and normal or odd)
	pair = pair[(tonumber(order.Id) or 1) % #pair + 1]
	if order.CustomerId == "reed" then
		return {
			customer(order, "Routine inspection. Please act natural."),
			line(player.DisplayName, "I was doing that before you asked.", player.UserId),
			customer(order, "I will put that in the report."),
		}
	end
	return {
		customer(order, order.Complaint),
		line(player.DisplayName, pair[1], player.UserId),
		customer(order, pair[2]),
	}
end
function Conversations.Return(order, player)
	if order.Phone and order.Phone.PassMessage then
		return {
			line(player.DisplayName, "Your family called. They love you. Also: bring bread.", player.UserId),
			customer(order, "You answered my phone? ...Thanks for telling me. Please keep that between us."),
		}
	end
	return {
		customer(order, order.Line),
		line(
			player.DisplayName,
			order.Kind == "Normal" and "Receipt is in the bag. Please keep it dry." or "Have a normal evening. Please.",
			player.UserId
		),
	}
end
function Conversations.Phone(player)
	return {
		line("Phone", "Your repair has been recorded. So have you."),
		line(player.DisplayName, "That was not on the test sheet.", player.UserId),
	}
end
function Conversations.Handoff(player, coworker)
	return {
		line(player.DisplayName, "One replacement. I found it without a map.", player.UserId),
		line(coworker.DisplayName, "Employee of the minute.", coworker.UserId),
	}
end
return Conversations
