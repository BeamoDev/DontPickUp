-- Presentation for the authored world sign. Queue state and timing remain server-owned.
local Billboard = {}
Billboard.__index = Billboard
local GREEN = Color3.fromRGB(4, 255, 0)
local AMBER = Color3.fromRGB(255, 195, 65)

local function find(board, ...)
	for _, name in ipairs({ ... }) do
		local object = board:FindFirstChild(name) or board:FindFirstChild(name, true)
		if object then
			return object
		end
	end
end

local function set(object, property, value)
	if object[property] ~= value then
		object[property] = value
	end
end

local function reveal(object, board)
	while object and object ~= board do
		if object:IsA("GuiObject") then
			set(object, "Visible", true)
		end
		object = object.Parent
	end
end

local function text(label, value, board)
	if not label or not (label:IsA("TextLabel") or label:IsA("TextButton")) then
		return
	end
	set(label, "Text", value)
	-- Keep display names plain text and preserve all authored text sizing settings.
	set(label, "RichText", false)
	reveal(label, board)
end

function Billboard.new(board)
	return setmetatable({ board = board }, Billboard)
end

function Billboard:Render(queue, state, now)
	local board = self.board
	if not board.Parent then
		return
	end
	set(board, "Enabled", true)
	local background = find(board, "Background")
	if background then
		reveal(background, board)
	end
	local title = find(board, "Title", "PartyLeader")
	local status = find(board, "Status", "GreenStatus", "Time")
	local modeLabel = find(board, "Gamemode")
	local players = find(board, "PlayerCount", "Players")
	local icon = find(board, "Icon", "GamemodeIcon", "MapIcon")
	local mode = (state.Mode == "Story" or state.Mode == "Endless") and state.Mode or "Story"
	local remaining = math.max(0, math.ceil((state.ExpiresAt or now) - now))
	local empty = state.State == "Empty"
	local heading = empty and "SHIFT AVAILABLE" or string.upper(state.Host) .. "'S SHIFT"
	local wording, legacyWording, color = "READY", "Walk in to create", GREEN
	if state.State == "Configuring" then
		wording, legacyWording, color = "SETUP " .. remaining .. "s", "Creating: " .. remaining .. "s", AMBER
	elseif state.State == "Open" then
		wording, legacyWording = "STARTS " .. remaining .. "s", "Leaving in " .. remaining .. "s"
	elseif state.State == "Countdown" then
		wording, legacyWording, color =
			"LEAVING " .. remaining .. "s", "Leaving in " .. remaining .. "s", AMBER
	elseif state.State == "Preparing" then
		wording, legacyWording, color = "PREPARING", "Preparing session...", AMBER
	elseif state.State == "Teleporting" then
		wording, legacyWording = "TELEPORTING", "Teleporting..."
	end
	text(title, title and title.Name == "PartyLeader" and state.Host or heading, board)
	text(modeLabel, mode, board)
	text(players, string.format("%d/%d", state.Count, state.Capacity), board)
	text(status, status and status.Name == "Time" and legacyWording or wording, board)
	if status and (status:IsA("TextLabel") or status:IsA("TextButton")) then
		set(status, "TextColor3", color)
	end
	-- Queue state colors only the status text. All authored borders stay untouched.
	if icon and (icon:IsA("ImageLabel") or icon:IsA("ImageButton")) then
		-- Capture each actual image instance before applying a mode override. Replacement
		-- images can replicate without replacing their BillboardGui.
		if self.icon ~= icon then
			self.icon, self.defaultImage = icon, icon.Image
		end
		local override = queue:GetAttribute(mode .. "Icon")
		local image = type(override) == "string" and override ~= "" and override or self.defaultImage
		set(icon, "Image", image)
		reveal(icon, board)
	end
end

return Billboard
