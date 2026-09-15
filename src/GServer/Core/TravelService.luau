local Travel = {}
Travel.__index = Travel

function Travel.new(services, config, data, tickets)
	local self = setmetatable({
		s = services,
		config = config,
		data = data,
		tickets = tickets,
		batches = {},
		byPlayer = {},
		closing = false,
	}, Travel)
	self.connection = services.TeleportService.TeleportInitFailed:Connect(
		function(player, result, _, placeId, options)
			local item = self.byPlayer[player]
			if not item or item.State ~= "InFlight" or item.Batch.PlaceId ~= placeId or not options then
				return
			end
			local ok, payload = pcall(function()
				return options:GetTeleportData()
			end)
			if not ok or type(payload) ~= "table" or payload.AttemptId ~= item.AttemptId then
				return
			end
			local retryable = result == Enum.TeleportResult.Failure or result == Enum.TeleportResult.Flooded
			self:_failure(item, retryable, result == Enum.TeleportResult.Flooded and 15 or 2)
		end
	)
	return self
end

function Travel:_failure(item, retryable, delay)
	if item.State ~= "InFlight" then
		return
	end
	if retryable and item.Attempts < self.config.TeleportAttempts then
		item.State = "Retry"
		item.Due = os.clock() + delay + math.random()
	else
		item.State = "Cancelling"
		item.Due = 0
	end
end

function Travel:_send(batch, items)
	if self.closing then
		return
	end
	local players = {}
	local attemptId = self.s.HttpService:GenerateGUID(false)
	for _, item in ipairs(items) do
		if
			self.byPlayer[item.Player] == item
			and item.Player.Parent == self.s.Players
			and (item.State == "Retry" or item.State == "Dispatching")
		then
			item.Attempts += 1
			item.AttemptId = attemptId
			item.State = "InFlight"
			item.Due = os.clock() + self.config.TeleportWatchdogSeconds
			table.insert(players, item.Player)
		end
	end
	if #players == 0 then
		return
	end
	local options = Instance.new("TeleportOptions")
	if batch.AccessCode then
		options.ReservedServerAccessCode = batch.AccessCode
	end
	-- Public loading-screen metadata only. The destination trusts the admission ticket.
	options:SetTeleportData({ TicketId = batch.TicketId, AttemptId = attemptId, GameData = batch.GameData })
	local ok = pcall(function()
		self.s.TeleportService:TeleportAsync(batch.PlaceId, players, options)
	end)
	if not ok then
		for _, player in ipairs(players) do
			local item = self.byPlayer[player]
			if item and item.Batch == batch and item.AttemptId == attemptId then
				self:_failure(item, true, 2 ^ item.Attempts)
			end
		end
	end
	-- Accepted only means initiation. Removal or a matching failure event settles each player.
end

function Travel:Begin(players, destination, cancelled, finished, options)
	local studio = self.s.RunService:IsStudio()
	if self.closing then
		return false, "ServerClosing"
	end
	if studio and not self.config.StudioTeleportPreview then
		return false, "TeleportUnavailableInStudio"
	end
	local mode = options and options.Mode or "Story"
	if mode ~= "Story" and mode ~= "Endless" then
		return false, "InvalidMode"
	end
	if #players < 1 or #players > self.config.MaxPartySize then
		return false, "InvalidRoster"
	end
	local unique = {}
	for _, player in ipairs(players) do
		if unique[player] then
			return false, "InvalidRoster"
		end
		unique[player] = true
	end
	local placeId = destination == "Game" and self.config.GamePlaceId or self.config.LobbyPlaceId
	if placeId <= 0 or placeId == game.PlaceId then
		return false, "PlaceNotConfigured"
	end
	for _, player in ipairs(players) do
		if self.byPlayer[player] or not self.data:IsReady(player) then
			return false, "DataNotReady"
		end
	end
	local batch = { PlaceId = placeId, Items = {}, Finished = finished }
	if destination == "Game" and not studio then
		local privateId
		for attempt = 1, 3 do
			if cancelled() or self.closing then
				return false, "Cancelled"
			end
			local ok, code, id = pcall(function()
				return self.s.TeleportService:ReserveServerAsync(placeId)
			end)
			if ok and type(code) == "string" and type(id) == "string" then
				batch.AccessCode = code
				privateId = id
				break
			end
			task.wait(attempt * 2)
		end
		if not privateId then
			return false, "ReservationUnavailable"
		end
		batch.PrivateId = privateId
	end
	-- Freeze and save the whole roster before any teleport call. Keep renewing ownership
	-- until PlayerRemoving; destination waits for the source's final release.
	local frozen = {}
	local function rollback(reason)
		for _, player in ipairs(frozen) do
			self.data:Thaw(player)
		end
		return false, reason
	end
	for _, player in ipairs(players) do
		if cancelled() or self.closing or player.Parent ~= self.s.Players or not self.data:Freeze(player) then
			return rollback("SaveOrRosterChanged")
		end
		table.insert(frozen, player)
	end
	if cancelled() or self.closing then
		return rollback("Cancelled")
	end
	if studio then
		local roster = {}
		for _, player in ipairs(players) do
			if player.Parent ~= self.s.Players then
				return rollback("RosterChanged")
			end
			table.insert(roster, string.format("%s (%d)", player.Name, player.UserId))
			player:SetAttribute("DPU_TravelStatus", "StudioPreviewComplete")
		end
		print(
			string.format(
				"[DPU][Studio] SAVE/ROSTER CHECKS PASSED | Mode=%s | Players=%d | Destination=%s",
				mode,
				#players,
				tostring(placeId)
			)
		)
		print(
			"[DPU][Studio] WOULD TELEPORT: "
				.. table.concat(roster, ", ")
				.. ". No reservation, admission write, or teleport was attempted."
		)
		print(
			"[DPU][Studio] StudioSaving="
				.. tostring(self.config.StudioSaving)
				.. "; live teleport and storage success are not verified by this preview."
		)
		return rollback("StudioPreviewComplete")
	end
	if destination == "Game" then
		batch.TicketId = self.s.HttpService:GenerateGUID(false)
		local ticket = self.tickets:Create(batch.TicketId, batch.PrivateId, players, mode)
		if not ticket then
			return rollback("AdmissionUnavailable")
		end
		batch.GameData = ticket.GameData and table.clone(ticket.GameData) or nil
		batch.Expires = ticket.Expires
	end
	-- Recheck after every yielding preparation stage, including MemoryStore.
	if cancelled() or self.closing then
		return rollback("Cancelled")
	end
	for _, player in ipairs(players) do
		if player.Parent ~= self.s.Players then
			return rollback("RosterChanged")
		end
	end
	self.batches[batch] = true
	for _, player in ipairs(players) do
		local item = { Player = player, Batch = batch, Attempts = 0, State = "Dispatching", Due = 0 }
		self.byPlayer[player] = item
		table.insert(batch.Items, item)
		player:SetAttribute("DPU_TravelStatus", "Teleporting")
	end
	-- One reservation and one initial group call; retries always reuse that reservation.
	task.spawn(function()
		self:_send(batch, batch.Items)
	end)
	return true
end

function Travel:Remove(player)
	local item = self.byPlayer[player]
	if item then
		item.State = "Departed"
		self.byPlayer[player] = nil
	end
end

function Travel:Tick()
	if self.closing then
		return
	end
	for batch in pairs(self.batches) do
		local retry = {}
		local pending = false
		for _, item in ipairs(batch.Items) do
			if self.byPlayer[item.Player] ~= item then
				continue
			end
			pending = true
			if item.State == "InFlight" and os.clock() >= item.Due then
				-- No definitive failure signal: revoke admission before permitting a new queue.
				self:_failure(item, false, 0)
			end
			if item.State == "Retry" and os.clock() >= item.Due then
				item.State = "Dispatching"
				table.insert(retry, item)
			elseif item.State == "Cancelling" and os.clock() >= item.Due then
				item.State = "Revoking"
				task.spawn(function()
					local safe, reason = true, nil
					if batch.TicketId then
						safe, reason = self.tickets:Revoke(batch.TicketId, item.Player.UserId, batch.Expires)
					end
					if self.byPlayer[item.Player] ~= item then
						return
					end
					if safe then
						self.byPlayer[item.Player] = nil
						item.State = "Failed"
						self.data:Thaw(item.Player)
						item.Player:SetAttribute("DPU_TravelStatus", "Failed")
					elseif reason == "AlreadyClaimed" then
						-- A destination already owns admission. Never resume this source session.
						item.Player:Kick(
							"Your private session has already started. Please rejoin through the lobby."
						)
					else
						item.State = "Cancelling"
						item.Due = os.clock() + 5
					end
				end)
			end
		end
		if #retry > 0 then
			task.spawn(function()
				self:_send(batch, retry)
			end)
		end
		if not pending then
			self.batches[batch] = nil
			if batch.Finished then
				task.spawn(batch.Finished)
			end
		end
	end
end

function Travel:Shutdown()
	self.closing = true
	self.connection:Disconnect()
end

return Travel
