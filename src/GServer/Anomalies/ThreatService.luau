-- Methods operate on the owning shift; no module-global gameplay state.
local Methods = {}
local Stations = require(script.Parent.Parent.Repair.RepairStations)
local Director = require(script.Parent.EventDirector)
local OutdoorRisk = require(script.Parent.OutdoorRisk)
local Engagement = require(script.Parent.Parent.Services.EngagementService)
function Methods:_scare(player, kind, announced, impact)
	local member, now = self.players[player], self.d.clock()
	impact = impact
		or {
			Damage = self.c.ScareDamage,
			Reason = kind == "Signal" and "The dead signal struck you" or "Something struck you in the shop",
		}
	if
		self.phase ~= "Night"
		or not member
		or not member.Alive
		or not self.d.present(player)
		or (self.c.Director.Enabled and now - self.nightAt < self.c.Director.CalmSeconds)
		or now < (member.NextScare or 0)
		or (not impact.Applied and kind == "Visitor" and self.event and self.event.Kind == "Visitor" and self.d.near(
			player,
			"Shelter"
		))
		or (not impact.Applied and now + self.c.ScareImpactDelay >= self.nightAt + self.c.NightSeconds)
	then
		return false
	end
	member.NextScare = now + 20
	self.scareSerial = (self.scareSerial or 0) + 1
	local random = self.d.random or math.random
	member.Scare = {
		Id = self.id .. "_scare_" .. self.scareSerial,
		Kind = kind,
		At = now + 0.25,
		Variant = random(1, 3),
		Damage = math.min(impact.Damage, member.HP),
		Fatal = impact.Damage >= member.HP,
	}
	if not impact.Applied then
		member.ScareImpact = {
			Id = member.Scare.Id,
			At = now + self.c.ScareImpactDelay,
			Damage = impact.Damage,
			Reason = impact.Reason,
		}
		member.Focus, member.Fax = nil, nil
		self.d.stand(player)
		Stations.CancelPlayer(self, player)
	end
	if self.d.debug and not announced then
		self.d.debug("COMING kind=" .. kind .. " player=" .. player.Name .. " in=0.25s damage=" .. impact.Damage)
	end
	self:_publish()
	return true
end

function Methods:_tickScareImpacts(now)
	for player, member in pairs(self.players) do
		local impact = member.ScareImpact
		if impact and now >= impact.At then
			-- Clear before Damage: health/death callbacks cannot apply the same hit twice.
			member.ScareImpact = nil
			if member.Alive and self.d.present(player) then
				self:Damage(player, impact.Damage, impact.Reason, true)
				if self.d.debug then
					self.d.debug("HIT player=" .. player.Name .. " damage=" .. impact.Damage .. " hp=" .. member.HP)
				end
			end
		end
	end
end

function Methods:_outsideHunt()
	for _, member in pairs(self.players) do
		if member.Alive and member.Outside and member.Outside.ThreatEndsAt then
			return true
		end
	end
	return false
end

function Methods:_tickOutside(now)
	local config = self.c.OutsideRisk
	if not config.Enabled or not self.d.outside or now < (self.nextOutsideCheck or 0) then
		return
	end
	self.nextOutsideCheck = now + 1
	local elapsed = now - self.nightAt
	local active = elapsed >= self.c.Director.CalmSeconds and (not self.director or self.director.count > 0)
	for player, member in pairs(self.players) do
		if member.Alive and self.d.present(player) and active then
			member.Outside = member.Outside or {}
			local canArm = not self.event
				and not self.resumeAt
				and not self.pendingScare
				and not member.ScareImpact
				and now >= (member.NextScare or 0)
			local transition = OutdoorRisk.Step(
				member.Outside,
				now,
				self.d.outside(player),
				canArm,
				config,
				self.d.random or math.random
			)
			if transition == "Warning" then
				if self.d.debug then
					self.d.debug(
						"COMING kind=Outside player=" .. player.Name .. " escapeWindow=" .. config.WarningSeconds
					)
				end
			elseif transition == "Attack" then
				local damage = elapsed >= self.c.Director.LethalAfter and config.LethalDamage or config.Damage
				self:_scare(
					player,
					"Visitor",
					false,
					{ Damage = damage, Reason = "You stayed outside after the footsteps warning" }
				)
			elseif transition == "Escaped" then
				Engagement.Add(member, "WarningsEscaped")
				Engagement.Unlock(member, "Anomalies", "outdoor_footsteps")
				member.PersonalNotice, member.PersonalNoticeUntil =
					"The footsteps stop at the door. You made it inside.", now + 6
				if self.d.debug then
					self.d.debug("CANCELLED: outdoor target reached shelter player=" .. player.Name)
				end
			end
			if transition then
				self:_publish()
			end
		elseif member.Outside then
			member.Outside = nil
			self:_publish()
		end
	end
end

function Methods:_planScare(kind, delay)
	local eligible = {}
	for _, player in ipairs(self:_living()) do
		if self.d.clock() >= (self.players[player].NextScare or 0) then
			table.insert(eligible, player)
		end
	end
	if #eligible == 0 then
		return
	end
	local player = eligible[(self.d.random or math.random)(1, #eligible)]
	self.pendingScare = { Player = player, Kind = kind, At = self.d.clock() + delay }
	if self.d.debug then
		self.d.debug(string.format("COMING kind=%s player=%s in=%.2fs", kind, player.Name, delay + 0.25))
	end
end

function Methods:_endDisturbance()
	if self.pendingScare and self.d.debug then
		self.d.debug("CANCELLED: disturbance ended before the scare")
	end
	self.pendingScare = nil
	self.event = nil
	self.resumeAt = self.d.clock() + self.c.AfterDisturbanceSeconds
	self:_publish()
end

function Methods:_tickDisturbance(now)
	local elapsed = now - self.nightAt
	if now >= self.nightAt + self.c.NightSeconds then
		self:Finish("Dawn")
		return
	end
	if self.event and now >= self.event.EndsAt then
		local event = self.event
		self:_endDisturbance()
		for _, player in ipairs(event.Minor and {} or self:_living()) do
			local damage = event.Kind == "Visitor" and (self.d.near(player, "Shelter") and 0 or 100)
				or event.Kind == "Inspection" and (self.suspicion >= 50 and 100 or 35)
				or 30
			self:Damage(
				player,
				damage,
				event.Kind == "Visitor" and "The visitor found you outside shelter" or "Ignored " .. event.Kind
			)
		end
		self:_notice("The disturbance passes. Service resumes shortly.")
	end
	if self.phase ~= "Night" then
		return
	end
	if self.pendingScare and now >= self.pendingScare.At then
		local cue = self.pendingScare
		self.pendingScare = nil
		local fired = self:_scare(cue.Player, cue.Kind, true)
		if self.d.debug then
			self.d.debug(fired and "DISPATCHED: scheduled scare" or "CANCELLED: target unavailable or cooling down")
		end
	end
	if self.resumeAt and now >= self.resumeAt and not self.event then
		for _, lane in pairs(self.stations) do
			local order = lane.order
			if order and order.PausedAt then
				local paused = now - order.PausedAt
				if order.ExpiresAt then
					order.ExpiresAt += paused
				end
				if order.VoteEndsAt then
					order.VoteEndsAt += paused
				end
				if order.Step == "Arriving" then
					order.ArrivesAt = now + self.c.ArrivalSeconds
				end
				if order.Step == "PickupArriving" then
					order.PickupAt = now + self.c.ArrivalSeconds
				end
				order.PausedAt = nil
			end
		end
		self.resumeAt = nil
		self:_publish()
	end
	local scheduled = self.c.Events[self.eventIndex]
	local hunted = self:_outsideHunt()
	if self.director then
		scheduled = self.director:Next(elapsed, self.suspicion, self.event ~= nil or self.resumeAt ~= nil or hunted)
	end
	if not self.event and not self.resumeAt and not hunted and scheduled and elapsed >= scheduled.At then
		self.event = {
			Id = tostring(self.eventIndex),
			Kind = scheduled.Kind,
			Warning = scheduled.Warning,
			EndsAt = now + scheduled.Duration,
			StartedAt = now,
			Minor = scheduled.Minor == true,
		}
		self.eventIndex += 1
		for _, lane in pairs(self.stations) do
			if lane.order then
				lane.order.PausedAt = now
			end
			lane.work = nil
		end
		for player in pairs(self.players) do
			self.d.stand(player)
		end
		self:_notice(scheduled.Warning)
		if scheduled.Scare then
			self:_planScare(scheduled.Scare, scheduled.ScareDelay)
		end
	end
end

return Methods
