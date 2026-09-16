-- Presentation descriptors only. The existing server puzzle rules validate every move.
local Tasks = {}
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
local colors = { Color3.fromRGB(197, 116, 90), Color3.fromRGB(115, 161, 188), Color3.fromRGB(196, 178, 111) }
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
		local names = kind == "Assembly" and { "BOARD", "BATTERY", "COVER" } or { "1 +", "2 -", "3 +" }
		for i = 1, 3 do
			local destination = table.find(p.Slots, i)
			local source = add("item" .. i, "Drag", i, -1.85, (i - 2) * 0.95, names[i], { Color = colors[i] })
			source.Done, source.Destination = p.Placed[i], "slot" .. destination
			if kind == "Wires" then
				source.Wire = Vector3.new(-2.4, 0.15, (i - 2) * 0.95)
				source.Size = Vector3.new(0.42, 0.14, 0.42)
			end
			add(
				"slot" .. i,
				"Drop",
				i,
				0,
				(i - 2) * 0.95,
				names[p.Slots[i]],
				{ Color = colors[p.Slots[i]], Ghost = true }
			)
		end
		hint = kind == "Assembly" and "Drag BOARD, BATTERY, then COVER into their marked positions."
			or kind == "Wires" and "Drag each numbered wire end to its matching socket."
			or "Drag the power cells from the tray into their matching bays."
	elseif kind == "Debris" then
		for i, name in ipairs({ "COIN", "LINT", "CLIP" }) do
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
		hint = "Drag the loose objects out of the casing into the waste tray."
	elseif kind == "Screen" then
		if p.Phase <= 2 then
			add(
				"screen",
				"Drag",
				1,
				p.Phase == 1 and 0 or -1.9,
				-0.85,
				p.Phase == 1 and "CRACKED" or "NEW",
				{ Size = Vector3.new(1.2, 0.12, 0.8) }
			)
			add(
				"socket",
				"Drop",
				1,
				p.Phase == 1 and 1.9 or 0,
				-0.85,
				p.Phase == 1 and "WASTE" or "DISPLAY",
				{ Size = Vector3.new(1.3, 0.07, 0.9), Ghost = true }
			)
			hint = p.Phase == 1 and "Lift the cracked display into the waste tray."
				or "Drag the new display into the phone."
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
			hint = "Press the four clips around the display to secure it."
		end
	elseif kind == "Screws" then
		for i = 1, 4 do
			add(
				"screw" .. i,
				"Turn",
				i,
				i % 2 == 0 and 0.72 or -0.72,
				i <= 2 and -1.25 or 1.25,
				p.Turns[i] == 3 and "SET" or (p.Turns[i] .. "/3"),
				{
					Disabled = p.Turns[i] == 3,
					Rotation = p.Turns[i] * math.pi / 2,
					Size = Vector3.new(0.4, 0.15, 0.4),
				}
			)
		end
		hint = "Grab a screw and drag sideways to turn it. Three turns per screw."
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
		for i, name in ipairs({ "BATTERY", "SPEAKER", "KEYPAD" }) do
			add("probe" .. i, "Click", i, 0, (i - 2) * 0.95, p.Tested[i] and p.Readings[i] or ("TEST " .. i))
			add("diagnosis" .. i, "Click", i + 3, 1.85, (i - 2) * 0.95, name, { Disabled = p.Progress < 3 })
		end
		hint = "Touch all three test pads, then select the faulty component on the right."
	end
	return nodes, hint
end
return Tasks
