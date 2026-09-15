-- Local presentation only. Never tween text, colors, visibility, or queue state owned by the server.
local Motion = {}
Motion.__index = Motion
local FIELDS = {
	Title = { "Title", "PartyLeader" },
	Count = { "Players" },
	Mode = { "Gamemode" },
	Status = { "GreenStatus", "Time" },
	Icon = { "GamemodeIcon", "MapIcon" },
	Background = { "Background" },
}

local function find(board, names)
	for _, name in ipairs(names) do
		local object = board:FindFirstChild(name) or board:FindFirstChild(name, true)
		if object and object:IsA("GuiObject") then
			return object
		end
	end
end

local function content(object)
	if not object then
		return ""
	end
	if object:IsA("TextLabel") or object:IsA("TextButton") then
		return object.Text
	end
	if object:IsA("ImageLabel") or object:IsA("ImageButton") then
		return object.Image
	end
	return ""
end

function Motion.new(deps)
	return setmetatable({ d = deps, boards = {}, nextDiscovery = 0, destroyed = false }, Motion)
end

function Motion:_stop(target)
	if target.Done then
		target.Done:Disconnect()
		target.Done = nil
	end
	if target.Fade then
		target.Fade:Cancel()
		target.Fade = nil
	end
	if target.Tween then
		target.Tween:Cancel()
		target.Tween = nil
	end
	if target.Scale and target.Scale.Parent then
		target.Scale.Scale = target.BaseScale
	end
	if target.Alpha and target.Object.Parent then
		target.Object[target.Alpha] = target.BaseAlpha
	end
end

function Motion:_release(target)
	self:_stop(target)
	if target.OwnScale and target.Scale then
		target.Scale:Destroy()
	end
end

function Motion:_target(object)
	local alpha = (object:IsA("TextLabel") or object:IsA("TextButton")) and "TextTransparency"
		or (object:IsA("ImageLabel") or object:IsA("ImageButton")) and "ImageTransparency"
		or nil
	return { Object = object, Alpha = alpha, BaseAlpha = alpha and object[alpha] or nil }
end

function Motion:_animate(target, scale, fade, duration)
	if not target or not target.Object.Parent or not target.Object.Visible then
		return
	end
	self:_stop(target)
	if not target.Scale or not target.Scale:IsDescendantOf(target.Object) then
		local existing = target.Object:FindFirstChildWhichIsA("UIScale")
		target.Scale, target.OwnScale = existing or Instance.new("UIScale"), not existing
		if not existing then
			target.Scale.Name, target.Scale.Scale = "DPU_QueueMotion", 1
			target.Scale.Parent = target.Object
		end
		target.BaseScale = target.Scale.Scale
	end
	-- Tween away and reverse to the captured baseline. Never rewrite authored UDim2.Size.
	local info = TweenInfo.new(duration / 2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true)
	local tween = self.d.tweens:Create(target.Scale, info, {
		Scale = target.BaseScale * math.clamp(scale, 0.9, 1.1),
	})
	target.Tween = tween
	if fade and target.Alpha then
		target.Object[target.Alpha] = target.BaseAlpha + (1 - target.BaseAlpha) * 0.4
		target.Fade = self.d.tweens:Create(
			target.Object,
			TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ [target.Alpha] = target.BaseAlpha }
		)
		target.Fade:Play()
	end
	target.Done = tween.Completed:Connect(function()
		-- Disconnect before cancellation, and only settle the animation still owning this target.
		if target.Tween == tween then
			self:_stop(target)
		end
	end)
	tween:Play()
end

function Motion:_sample(binding, reduced)
	local board = binding.Board
	local snapshot = { State = binding.Queue:GetAttribute("DPU_QueueState") or "Empty" }
	local replaced = {}
	for key, names in pairs(FIELDS) do
		local object = find(board, names)
		local old = binding.Targets[key]
		if old and old.Object ~= object then
			self:_release(old)
			binding.Targets[key] = nil
		end
		if object and not binding.Targets[key] then
			binding.Targets[key] = self:_target(object)
			replaced[key] = true
		end
		snapshot[key] = content(object)
	end
	local previous = binding.Last
	binding.Last = snapshot
	if reduced or not board.Enabled then
		for _, target in pairs(binding.Targets) do
			self:_stop(target)
		end
		return
	end
	-- Initial replication is a baseline, not a queue transition.
	if not previous then
		return
	end
	local transition = snapshot.State ~= previous.State
	local function animate(key, scale, fade, duration)
		if not replaced[key] then
			local target = binding.Targets[key]
			if target then
				-- Nested labels already pulse independently: scaling their wrapper too
				-- would compound the change beyond ten percent.
				for _, other in pairs(binding.Targets) do
					if other ~= target and other.Object:IsDescendantOf(target.Object) then
						scale = 1
						break
					end
				end
			end
			self:_animate(target, scale, fade, duration)
		end
	end
	if transition then
		animate("Background", 0.9, false, 0.28)
		animate("Title", 0.9, true, 0.24)
		animate("Status", 0.9, true, 0.24)
	elseif snapshot.Title ~= previous.Title then
		animate("Title", 0.9, true, 0.24)
	end
	if snapshot.Count ~= previous.Count then
		animate("Count", 1.1, false, 0.22)
	end
	if snapshot.Mode ~= previous.Mode or snapshot.Icon ~= previous.Icon then
		animate("Mode", 0.9, true, 0.24)
		animate("Icon", 0.9, true, 0.28)
	end
	-- Only the final seconds pulse. Gathering timer changes do not reanimate the board.
	if not transition and snapshot.State == "Countdown" and snapshot.Status ~= previous.Status then
		local seconds = tonumber(snapshot.Status:match("(%d+)%s*s"))
		if seconds and seconds >= 1 and seconds <= 5 then
			animate("Status", 1.1, false, 0.18)
		end
	end
end

function Motion:_discover()
	local folder = self.d.workspace:FindFirstChild("Queues")
	local seen = {}
	if folder then
		for _, queue in ipairs(folder:GetChildren()) do
			local ui = queue:FindFirstChild("UI") or queue:FindFirstChild("UI", true)
			local board = ui and ui:FindFirstChildWhichIsA("BillboardGui", true)
			if board then
				seen[board] = true
				if not self.boards[board] then
					self.boards[board] = { Board = board, Queue = queue, Targets = {} }
				end
			end
		end
	end
	for board, binding in pairs(self.boards) do
		if not seen[board] then
			for _, target in pairs(binding.Targets) do
				self:_release(target)
			end
			self.boards[board] = nil
		end
	end
end

function Motion:Tick()
	if self.destroyed then
		return
	end
	local now = self.d.clock()
	if now >= self.nextDiscovery then
		self.nextDiscovery = now + 1
		self:_discover()
	end
	local reduced = self.d.reduced()
	for board, binding in pairs(self.boards) do
		if board:IsDescendantOf(self.d.workspace) then
			self:_sample(binding, reduced or binding.Queue:GetAttribute("DisableQueueMotion") == true)
		end
	end
end

function Motion:Destroy()
	self.destroyed = true
	for _, binding in pairs(self.boards) do
		for _, target in pairs(binding.Targets) do
			self:_release(target)
		end
	end
	self.boards = {}
end

return Motion
