local UI = require(script.Parent.Parent.Interface.AuthoredUI)
-- Extra layouts share the repair panel's pooled controls and discrete drag protocol.
local View = {}
local PAIRS = { Debris = true, Screen = true, SIM = true, Fuse = true, Charger = true, Sort = true, Assembly = true }
local KINDS = {
	Clean = true,
	Broken = true,
	Screws = true,
	Buttons = true,
	PhoneNumber = true,
	Waves = true,
	Meter = true,
	Stamp = true,
	Speaker = true,
}
local ACCENT, WHITE = Color3.fromRGB(220, 213, 200), Color3.fromRGB(235, 235, 235)
local NOTCHES = { "TOP", "RIGHT", "BOTTOM", "LEFT" }
local SHAPES = { "ROUND", "SQUARE", "TRIANGLE" }
function View.Supports(p)
	return p and (KINDS[p.Kind] or PAIRS[p.Kind]) == true
end
function View.Pair(p)
	return PAIRS[p.Kind] == true and not (p.Kind == "Screen" and p.Phase == 3)
end
function View.new(root)
	local self = { segments = {}, screwFaces = {}, screwSlots = {} }
	for i = 1, 4 do
		local face = UI.Bind("Frame", root:FindFirstChild("Control" .. i), "ScrewHead", { Visible = false })
		UI.Bind("UICorner", face, nil)
		local slot = UI.Bind("Frame", face, nil)
		for _, horizontal in ipairs({ true, false }) do
			UI.Bind("Frame", slot, nil)
		end
		self.screwFaces[i], self.screwSlots[i] = face, slot
	end
	self.graph = UI.Bind("Frame", root, "SignalDisplay", { Visible = false })
	for wave = 1, 2 do
		self.segments[wave] = {}
		for i = 1, 32 do
			self.segments[wave][i] = UI.Bind("Frame", self.graph, nil)
		end
	end
	self.zone = UI.Bind("Frame", self.graph, nil)
	self.needle = UI.Bind("Frame", self.graph, nil)
	-- Built-in tone avoids an external asset dependency; numbered captions also support muted play.
	self.tone = UI.Bind("Sound", root, "SpeakerTestTone")
	self.tone:Stop()
	return setmetatable(self, { __index = View })
end
function View:Hide()
	self.graph.Visible = false
	for _, face in ipairs(self.screwFaces) do
		face.Visible = false
	end
	self.tone:Stop()
	self.cue = nil
	self.key = nil
end
function View:Render(view, p, watching, lit, reduced)
	local now = workspace:GetServerTimeNow()
	local meterLabel
	if p.Kind == "Meter" then
		local elapsed = math.clamp(now - p.At, 0, 5)
		local value = math.clamp(p.Value + elapsed * p.Drift, 0, 1)
		local held = value >= 0.35
				and value <= 0.65
				and (p.Value >= 0.35 and p.Good + elapsed or (value - 0.35) / p.Drift)
			or 0
		self.needle.Position = UDim2.fromScale(value, 0.1)
		meterLabel = "CHECK / " .. string.format("%.1f", math.min(held, 2.5)) .. " / 2.5s"
		view.check.Text = meterLabel
	end
	local key = view.work.Id
		.. ":"
		.. p.Revision
		.. ":"
		.. tostring(view.busy)
		.. ":"
		.. tostring(view.selected)
		.. ":"
		.. tostring(watching)
		.. ":"
		.. tostring(lit)
		.. ":"
		.. tostring(reduced)
		.. ":"
		.. tostring(view.root.AbsoluteSize)
	if self.key == key then
		return
	end
	self.key = key
	local graph = p.Kind == "Waves" or p.Kind == "Meter"
	self.graph.Visible = graph
	self.zone.Visible, self.needle.Visible = p.Kind == "Meter", p.Kind == "Meter"
	for wave, segments in ipairs(self.segments) do
		for i, dot in ipairs(segments) do
			dot.Visible = p.Kind == "Waves"
			if p.Kind == "Waves" then
				local values = wave == 1 and p.Targets or p.Values
				dot.Position = UDim2.fromScale(
					(i - 1) / 31,
					0.5 + 0.34 * math.sin((i - 1) / 31 * math.pi * 2 * values[1] + values[2] * math.pi / 4)
				)
			end
		end
	end
	local cue = p.Kind == "Speaker"
			and watching
			and lit ~= 0
			and (view.work.Id .. ":" .. p.RevealAt .. ":" .. math.floor((now - p.RevealAt) / 0.7))
		or nil
	if cue and cue ~= self.cue and not reduced then
		self.tone:Stop()
		self.tone.PlaybackSpeed = ({ 0.75, 1, 1.4 })[lit]
		self.tone:Play()
	end
	self.cue = cue
	if p.Kind ~= "Speaker" or reduced then
		self.tone:Stop()
	end
	view.check.Visible = p.Kind == "SIM" or p.Kind == "Speaker" or graph
	view.check.Active = not view.busy and not watching
	view.check.Text = p.Kind == "SIM" and "TURN CARD"
		or p.Kind == "Speaker" and (watching and "WATCH THE NUMBERS" or "WATCH AGAIN")
		or p.Kind == "Meter" and meterLabel
		or "CHECK LINES"
	for _, line in ipairs(view.lines) do
		line.Visible = false
	end
	local sources, targets
	if View.Pair(p) then
		if p.Kind == "Debris" then
			sources, targets = { "COIN", "FLUFF", "PAPER CLIP" }, { "WASTE TRAY" }
		elseif p.Kind == "Screen" then
			sources, targets =
				{
					p.DeviceStage and p.DeviceStage ~= "Exchange" and p.Component or p.Component and ((p.Phase == 1 and "BROKEN " or "NEW ") .. p.Component) or (p.Phase == 1 and "CRACKED SCREEN" or "NEW SCREEN"),
				}, { p.Phase == 1 and (p.DeviceStage and p.DeviceStage ~= "Exchange" and "PARTS TRAY" or "RECYCLE") or "PHONE FRAME" }
		elseif p.Kind == "SIM" then
			sources, targets =
				{ "CARD\nCUT-OUT " .. NOTCHES[p.Rotation + 1] }, { "SLOT\nCUT-OUT " .. NOTCHES[p.Notch + 1] }
		elseif p.Kind == "Fuse" then
			sources, targets =
				p.Phase == 1 and { "BROKEN FUSE" } or { "FUSE 1", "FUSE 2", "FUSE 3" },
				{ p.Phase == 1 and "RECYCLE" or ("SPACE " .. p.Rating) }
		elseif p.Kind == "Charger" then
			sources, targets = SHAPES, { SHAPES[p.Port] .. " HOLE" }
		else
			sources = p.Kind == "Sort" and { "BATTERY", "SPEAKER", "KEYPAD" } or { "1 BOARD", "2 BATTERY", "3 COVER" }
			targets = { sources[p.Slots[1]], sources[p.Slots[2]], sources[p.Slots[3]] }
		end
	end
	for i, button in ipairs(view.buttons) do
		if self.screwFaces[i] then
			self.screwFaces[i].Visible = p.Kind == "Screws"
			if p.Kind == "Screws" then
				self.screwSlots[i].Rotation = p.Turns[i] * 45
			end
		end
		button.Visible, button.Active, button.Rotation = false, not view.busy and not watching, 0
		button.BackgroundColor3, button.TextColor3 = Color3.new(0, 0, 0), WHITE
		button.TextSize, button.TextYAlignment, button.TextXAlignment =
			14, Enum.TextYAlignment.Center, Enum.TextXAlignment.Center
		button.Position = UDim2.new((i - 1) % 3 / 3, 4, math.floor((i - 1) / 3) * 0.37, 0)
		button.Size = UDim2.new(1 / 3, -8, 0.34, -2)
		for _, arm in ipairs(view.arms[i]) do
			arm.Visible = false
		end
		if view.dials[i] then
			view.dials[i].Visible = false
		end
		local label
		if sources then
			label = i <= 3 and sources[i] or i <= 6 and targets[i - 3] or nil
			button.Position = UDim2.new(i <= 3 and 0 or 0.7, 0, ((i - 1) % 3) / 3 * 0.76, 2)
			button.Size = UDim2.new(0.3, 0, 0.24, -4)
			if i <= 3 and ((p.Removed and p.Removed[i]) or (p.Placed and p.Placed[i])) then
				label = nil
			end
			if i > 3 and i <= 6 and p.Placed and p.Placed[p.Slots[i - 3]] then
				label = "FITTED"
				button.Active = false
			end
			if view.selected == i and label then
				label = "[ " .. label .. " ]"
			end
		elseif p.Kind == "Clean" and i <= 6 then
			label = p.Dirt[i] == 0 and "CLEAN" or ("SCRUB " .. i .. "\n" .. p.Dirt[i] .. " more")
			button.BackgroundColor3 = p.Dirt[i] == 0 and Color3.new(0, 0, 0) or Color3.fromRGB(65, 48, 30)
			button.Active = button.Active and p.Dirt[i] > 0
		elseif p.Kind == "Broken" and i <= 6 then
			label = "PART " .. i .. "\n" .. (i == p.Bad and "BROKEN - REMOVE" or "WORKING - KEEP")
		elseif (p.Kind == "Screws" or p.Kind == "Screen") and i <= 4 then
			local done = p.Kind == "Screws" and p.Turns[i] == (p.TurnsRequired or 3)
				or p.Kind == "Screen" and p.Clips[i]
			label = p.Kind == "Screws" and ("SCREW " .. i .. " / " .. p.Turns[i] .. "/" .. (p.TurnsRequired or 3))
				or ("CLIP " .. i)
			if p.Kind == "Screws" then
				button.TextYAlignment = Enum.TextYAlignment.Bottom
			end
			button.Position = UDim2.new((i - 1) % 2 * 0.6, 4, math.floor((i - 1) / 2) * 0.48, 2)
			button.Size = UDim2.new(0.4, -8, 0.46, -4)
			button.TextColor3, button.Active = done and ACCENT or WHITE, button.Active and not done
		elseif p.Kind == "PhoneNumber" and i <= 11 then
			label = i == 11 and "START OVER" or tostring(i % 10)
			button.Position = UDim2.new((i - 1) % 3 / 3, 3, math.floor((i - 1) / 3) / 4, 1)
			button.Size = UDim2.new(1 / 3, -6, 0.25, -3)
		elseif p.Kind == "Buttons" and i <= 6 then
			label = tostring(i)
		elseif p.Kind == "Speaker" and i <= 3 then
			label = ({ "1", "2", "3" })[i]
			if watching and lit == i then
				label = "[ " .. label .. " ]"
				button.TextColor3 = ACCENT
			end
		elseif p.Kind == "Waves" and i <= 4 then
			label = ({ "LESS BUMPS", "MORE BUMPS", "SLIDE RIGHT", "SLIDE LEFT" })[i]
			button.Position = UDim2.new((i - 1) / 4, 2, 0.49, 0)
			button.Size = UDim2.new(0.25, -4, 0.22, 0)
		elseif p.Kind == "Meter" and i <= 2 then
			label = i == 1 and "LEFT" or "RIGHT"
			button.Position = UDim2.new((i - 1) / 2, 2, 0.49, 0)
			button.Size = UDim2.new(0.5, -4, 0.22, 0)
		elseif p.Kind == "Stamp" then
			if p.Retest and i == 3 then
				label = "FIX LOOSE WIRE"
			elseif not p.Retest and i <= 2 then
				label = i == 1 and "PHONE IS READY" or "FIX IT FIRST"
			elseif i == 4 then
				label = "Battery: working\nSound: working\nWire: " .. (p.Failed and "loose - fix it" or "working")
				button.Active = false
			end
		end
		button.Visible, button.Text = label ~= nil, label or ""
	end
end
return View
