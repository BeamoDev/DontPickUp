local Shared = game:GetService("ReplicatedStorage"):WaitForChild("GShared", 30)
-- Presentation descriptors only. The existing server puzzle rules validate every move.
local Tasks = {}
local Public = require(Shared:WaitForChild("Repair", 30):WaitForChild("RepairDefinitions", 30))
local supported = {
	BatteryFit = true,
	Wires = true,
	Assembly = true,
	Screen = true,
	Debris = true,
	Screws = true,
	Clean = true,
	Probes = true,
}
local colors = {
	Color3.fromRGB(197, 116, 90),
	Color3.fromRGB(115, 161, 188),
	Color3.fromRGB(196, 178, 111),
	Color3.fromRGB(135, 195, 140),
}
local paper = Color3.fromRGB(216, 208, 189)
function Tasks.Supports(p)
	return p and supported[p.Kind] == true
end
function Tasks.Build(p)
	local nodes = {}
	local function add(id, role, index, x, z, text, options)
		local node = options or {}
		node.Id, node.Role, node.Index = id, role, index
		node.Position, node.Text = Vector3.new(x, 0.15, z), text
		node.Size = node.Size or Vector3.new(0.62, 0.12, 0.66)
		node.Color = node.Color or paper
		table.insert(nodes, node)
		return node
	end
	local kind = p.Kind
	local hint
	if kind == "BatteryFit" or kind == "Wires" or kind == "Assembly" then
		local names = kind == "Assembly" and { "BOARD", "BATTERY", "COVER" }
			or kind == "Wires" and { "1 RED", "2 BLUE", "3 YELLOW", "4 GREEN" }
			or { "1 +", "2 -", "3 +" }
		local count = #p.Slots
		for i = 1, count do
			local z = (i - (count + 1) / 2) * (count == 4 and 0.7 or 0.95)
			local destination = table.find(p.Slots, i)
			local source = add("item" .. i, "Drag", i, -1.85, z, names[i], { Color = colors[i] })
			source.Done, source.Destination = p.Placed[i], "slot" .. destination
			if kind == "Wires" then
				source.Wire = Vector3.new(-2.4, 0.15, z)
				source.Size = Vector3.new(0.42, 0.14, 0.42)
			end
			add("slot" .. i, "Drop", i, 0, z, names[p.Slots[i]], { Color = colors[p.Slots[i]], Ghost = true })
		end
		hint = kind == "Assembly"
				and ("Next: move the " .. names[math.min(p.Progress + 1, 3)] .. " to its matching space.")
			or kind == "Wires" and "Connect all four wires. Match the color and number at both ends."
			or "Move each battery to the space with the same label."
	elseif kind == "Debris" then
		for i, name in ipairs({ "COIN", "FLUFF", "CLIP" }) do
			add(
				"item" .. i,
				"Drag",
				i,
				i == 2 and -0.4 or 0.3,
				(i - 2) * 0.9,
				name,
				{ Done = p.Removed[i], Destination = "waste", Remove = true }
			)
		end
		add("waste", "Drop", 1, 1.9, 0, "WASTE", { Size = Vector3.new(1, 0.08, 1.8), Ghost = true })
		hint = "Move the loose objects to the waste tray."
	elseif kind == "Screen" then
		if p.Phase <= 2 then
			add(
				"screen",
				"Drag",
				1,
				p.Phase == 1 and 0 or -1.9,
				-0.85,
				p.Phase == 1 and "BROKEN" or "NEW",
				{ Size = Vector3.new(1.2, 0.12, 0.8) }
			)
			add(
				"socket",
				"Drop",
				1,
				p.Phase == 1 and 1.9 or 0,
				-0.85,
				p.Phase == 1 and "WASTE" or (p.Component or "DISPLAY"),
				{ Size = Vector3.new(1.3, 0.07, 0.9), Ghost = true }
			)
			hint = p.Component
					and (p.Phase == 1 and "Move the broken " .. p.Component .. " to the waste tray." or "Fit the new " .. p.Component .. " into the phone.")
				or (
					p.Phase == 1 and "Move the cracked screen to the waste tray."
					or "Move the new screen into the phone."
				)
		else
			for i = 1, 4 do
				add(
					"clip" .. i,
					"Click",
					i,
					i % 2 == 0 and 0.65 or -0.65,
					i <= 2 and -1.3 or -0.4,
					p.Clips[i] and "SET" or "CLIP",
					{ Disabled = p.Clips[i], Size = Vector3.new(0.4, 0.12, 0.38) }
				)
			end
			hint = "Press each clip to hold the screen in place."
		end
	elseif kind == "Screws" then
		for i = 1, 4 do
			add(
				"screw" .. i,
				"Turn",
				i,
				i % 2 == 0 and 0.72 or -0.72,
				i <= 2 and -1.25 or 1.25,
				p.Turns[i] == (p.TurnsRequired or 3) and "SET" or (p.Turns[i] .. "/" .. (p.TurnsRequired or 3)),
				{
					Disabled = p.Turns[i] == (p.TurnsRequired or 3),
					Rotation = p.Turns[i] * math.pi / 2,
					Size = Vector3.new(0.4, 0.15, 0.4),
				}
			)
		end
		hint = p.TurnsRequired == 1 and "Drag each screw sideways once."
			or "Grab a screw and drag sideways to turn it. Three turns per screw."
	elseif kind == "Clean" then
		for i = 1, 6 do
			add("dirt" .. i, "Scrub", i, i % 2 == 0 and 0.4 or -0.4, (math.ceil(i / 2) - 2) * 0.95, "", {
				Hidden = p.Dirt[i] == 0,
				Color = Color3.fromRGB(78, 63, 45),
				Alpha = p.Dirt[i] == 1 and 0.5 or 0.12,
			})
		end
		hint = "Hold a dirty patch and rub back and forth. Clean each patch twice."
	elseif kind == "Probes" then
		for i, name in ipairs(Public.PartNames) do
			local z = (i - 2) * 0.95
			add("probe" .. i, "Click", i, 0, z, name .. "\n" .. (p.Tested[i] and p.Readings[i] or "CHECK"))
			add("diagnosis" .. i, "Click", i + 3, 1.85, z, "REPLACE\n" .. name, { Disabled = p.Progress < 3 })
		end
		hint = p.Progress < 3 and "Check the battery, speaker and keypad."
			or "Choose REPLACE for the part marked BROKEN."
	end
	return nodes, hint
end
return Tasks
