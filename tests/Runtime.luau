local Harness = require("./Harness")
local total = 0
local function check(value, label)
	assert(value, label)
	total += 1
end
local core = "src/LServer/Core/"

local function travelFixture()
	local h = Harness.Environment()
	h.prints = {}
	h.env.print = function(...)
		table.insert(h.prints, table.pack(...))
	end
	local config = h:load(core .. "Config.luau")
	local frozen, failSave, packets = {}, {}, {}
	local reservations, revocations = 0, 0
	local event
	local source = {
		Players = h.players,
		RunService = {
			IsStudio = function()
				return false
			end,
		},
		HttpService = {
			GenerateGUID = function()
				h.serial += 1
				return string.format("00000000-0000-0000-0000-%012d", h.serial)
			end,
		},
		TeleportService = {
			TeleportInitFailed = {
				Connect = function(_, fn)
					event = fn
					return { Disconnect = function() end }
				end,
			},
			ReserveServerAsync = function()
				reservations += 1
				return "secret-code", "private-id"
			end,
			TeleportAsync = function(_, id, players, options)
				table.insert(packets, { PlaceId = id, Players = players, Options = options })
			end,
		},
	}
	local data = {
		IsReady = function(_, player)
			return not frozen[player]
		end,
		Freeze = function(_, player)
			if failSave[player] then
				return false
			end
			frozen[player] = true
			return true
		end,
		Thaw = function(_, player)
			frozen[player] = nil
		end,
	}
	local revokeAllowed = true
	local tickets = {
		Create = function(_, _, _, players, mode)
			return {
				Expires = h.time + 300,
				GameData = { Version = 1, Mode = mode, StartNight = 1, PartySize = #players },
			}
		end,
		Revoke = function()
			revocations += 1
			return revokeAllowed
		end,
	}
	local travel = h:load(core .. "TravelService.luau").new(source, config, data, tickets)
	return h,
		travel,
		{
			config = config,
			source = source,
			data = data,
			tickets = tickets,
			frozen = frozen,
			failSave = failSave,
			packets = packets,
			reservations = function()
				return reservations
			end,
			revocations = function()
				return revocations
			end,
			allowRevoke = function(value)
				revokeAllowed = value
			end,
			fail = function(player, result, options)
				event(player, result, "failure", config.GamePlaceId, options)
			end,
		}
end

do
	local h, travel, f = travelFixture()
	local a, b = h:player(1), h:player(2)
	local finished = 0
	check(
		travel:Begin({ a, b }, "Game", function()
			return false
		end, function()
			finished += 1
		end),
		"group preparation accepted"
	)
	travel:Tick()
	h:drain()
	check(
		#f.packets == 1 and #f.packets[1].Players == 2 and f.reservations() == 1,
		"one reservation and initial group call"
	)
	check(f.frozen[a] and f.frozen[b], "both profiles frozen before teleport")
	local first = f.packets[1].Options
	check(
		first.ReservedServerAccessCode == "secret-code" and first:GetTeleportData().AccessCode == nil,
		"private code not in payload"
	)
	travel:Remove(a)
	a.Parent = nil
	f.fail(b, "Failure", first)
	h.time += 5
	travel:Tick()
	h:drain()
	check(
		#f.packets == 2 and #f.packets[2].Players == 1 and f.packets[2].Players[1] == b,
		"only failed remaining member retried"
	)
	check(
		f.packets[2].Options.ReservedServerAccessCode == "secret-code" and f.reservations() == 1,
		"retry reuses original reserved server"
	)
	f.fail(b, "Unauthorized", first)
	check(travel.byPlayer[b].State == "InFlight", "stale failure cannot cancel newer attempt")
	f.allowRevoke(false)
	f.fail(b, "Unauthorized", f.packets[2].Options)
	travel:Tick()
	h:drain()
	check(f.frozen[b] and travel.byPlayer[b].State == "Cancelling", "revocation outage keeps profile frozen")
	f.allowRevoke(true)
	h.time += 6
	travel:Tick()
	h:drain()
	travel:Tick()
	h:drain()
	check(not f.frozen[b] and travel.byPlayer[b] == nil, "confirmed revocation allows safe queue recovery")
	check(f.revocations() == 2 and finished == 1, "transfer settles once after partial failure")
end

do
	local h, travel, f = travelFixture()
	local a, b = h:player(1), h:player(2)
	f.failSave[b] = true
	local ok = travel:Begin({ a, b }, "Game", function()
		return false
	end)
	h:drain()
	check(
		not ok and #f.packets == 0 and not f.frozen[a],
		"one failed save cancels all departures and thaws saved member"
	)
	f.failSave[b] = nil
	f.tickets.Create = function()
		b.Parent = nil
		return { Expires = h.time + 300 }
	end
	check(not travel:Begin({ a, b }, "Game", function()
		return false
	end), "roster rechecked after ticket storage yields")
	check(not f.frozen[a] and #f.packets == 0, "post-ticket cancellation cannot teleport remaining roster")
end

do
	local h, travel, f = travelFixture()
	local a = h:player(1)
	check(
		travel:Begin({ a }, "Game", function()
			return false
		end),
		"watchdog fixture starts"
	)
	h:drain()
	h.time += f.config.TeleportWatchdogSeconds + 1
	travel:Tick()
	h:drain()
	check(
		#f.packets == 1 and f.revocations() == 1 and not f.frozen[a],
		"missing callback revokes instead of overlapping another teleport"
	)
end

do
	local h, travel, f = travelFixture()
	local a = h:player(1)
	f.source.TeleportService.TeleportAsync = function()
		error("transport unavailable")
	end
	check(
		travel:Begin({ a }, "Game", function()
			return false
		end),
		"transport retry fixture starts"
	)
	h:drain()
	for _ = 1, 5 do
		h.time += 20
		travel:Tick()
		h:drain()
	end
	check(
		not f.frozen[a] and travel.byPlayer[a] == nil and f.reservations() == 1,
		"thrown transport errors have bounded retries and recover"
	)
	f.source.RunService.IsStudio = function()
		return true
	end
	check(not travel:Begin({ a }, "Game", function()
		return false
	end), "Studio does not pretend to teleport")
end

do
	local h, travel, f = travelFixture()
	h.env.game.PlaceId = f.config.GamePlaceId
	local a = h:player(1)
	check(
		travel:Begin({ a }, "Lobby", function()
			return false
		end),
		"return to lobby prepares save"
	)
	h:drain()
	check(
		f.packets[1].PlaceId == f.config.LobbyPlaceId
			and f.packets[1].Options.ReservedServerAccessCode == nil
			and f.reservations() == 0,
		"return goes to public Lobby without reservation"
	)
end

do
	local h = Harness.Environment()
	local Config = h:load(core .. "Config.luau")
	local persistentCalls = 0
	local s = {
		Players = h.players,
		RunService = {
			IsStudio = function()
				return true
			end,
		},
		HttpService = {
			GenerateGUID = function()
				h.serial += 1
				return "op-" .. h.serial
			end,
		},
		DataStoreService = {
			GetDataStore = function()
				persistentCalls += 1
				error("practice must not access persistent data")
			end,
		},
	}
	local data = h:load(core .. "DataService.luau").new(s, Config)
	local a = h:player(1)
	check(data:Load(a) and data:IsReady(a), "practice profile loads")
	check(persistentCalls == 0 and a.Session.Persistent.Value == false, "Studio practice makes no storage calls")
	check(
		a.leaderstats["Best Night"].Value == 0 and a.PlayerData.Progression.HighestShift.Value == 1,
		"authored player folder defaults"
	)
	check(a.Session.DataLoaded.Value and a.Session.DataStatus.Value == "Ready", "player loading status visible")
	a.PlayerData.Statistics.CasesSolved.Value = 999
	a.leaderstats.Credits.Value = 999999
	check(data:Get(a).Stats.Credits == 0, "replicated credits cannot mutate the wallet")
	check(data:Get(a).Stats.CasesSolved == 0, "replicated ValueObjects cannot grant persistent progress")
	check(
		data:SetSetting(a, "Subtitles", false) and not data:SetSetting(a, "MasterVolume", 0 / 0),
		"setting allowlist and numeric validation"
	)
	check(not data:SetSetting(a, "Admin", true), "unknown setting rejected")
	local outcome = { Id = "run-1", Survived = true, Shift = 1, CasesSolved = 4, Ending = "escape" }
	check(data:RecordOutcome(a, outcome), "server records completed run")
	check(
		data:RecordOutcome(a, outcome) and data:Get(a).Stats.CasesSolved == 4,
		"duplicate run outcome not granted twice"
	)
	check(data:Get(a).Stats.Credits == 90 and a.leaderstats.Credits.Value == 90, "four repairs plus survival pay once")
	check(a.leaderstats["Best Night"].Value == 1, "leaderstat is highest completed night, not lifetime total")
	check(data:UnlockEvidence(a, "phone-note") and data:CompleteTutorial(a), "server evidence and tutorial API")
	check(
		data:Get(a).Progress.HighestShift == 2 and a.PlayerData.Progression.EndingsFound.Value == 1,
		"progress and ending count updated"
	)
	h.time += 65
	check(data:Freeze(a) and not data:IsReady(a), "transfer freeze saves and blocks mutations")
	check(
		not data:SetSetting(a, "Subtitles", true) and not data:RecordOutcome(a, outcome),
		"frozen profile rejects writes"
	)
	check(data.memory["1"].Data.Stats.PlaytimeSeconds == 65, "playtime accumulated on save")
	data:Thaw(a)
	check(data:IsReady(a), "failed travel can thaw safe profile")
	data:Remove(a)
	check(data.entries[a] == nil and data.memory["1"].Lease == nil, "departure saves and releases")
	check(data:Load(a) and data:Get(a).Stats.CasesSolved == 4, "same practice server reloads saved progress")
	data.memory["1"].Lease.Token = "another-owner"
	check(not data:Freeze(a), "lost ownership rejects transfer save")
	data:Thaw(a)
	check(
		not data:IsReady(a) and a.Session.DataStatus.Value == "SessionLost",
		"rollback cannot reactivate an ownership-lost profile"
	)
	data.entries[a].session.Expires = h.time + 20
	check(not data:IsReady(a), "mutations stop before lease expiration")
	data:Tick()
	h:drain()
	data:Shutdown()
	h:drain()
	check(data.closing and data.entries[a] == nil, "shutdown closes profiles")
end

do
	local h = Harness.Environment()
	local Config = h:load(core .. "Config.luau")
	local stored = {}
	local calls = 0
	local map = {
		UpdateAsync = function(_, id, fn)
			calls += 1
			local nextValue = fn(stored[id])
			if nextValue then
				stored[id] = nextValue
			end
			return nextValue
		end,
		GetAsync = function(_, id)
			return stored[id]
		end,
	}
	local tickets = h:load(core .. "TicketStore.luau").new({
		MemoryStoreService = {
			GetHashMap = function()
				return map
			end,
		},
		RunService = {
			IsStudio = function()
				return false
			end,
		},
	}, Config)
	local a, b = h:player(1), h:player(2)
	local id = "00000000-0000-0000-0000-000000000001"
	check(tickets:Create(id, "private-id", { a, b }, "Endless") ~= nil, "admission roster stored")
	check(stored[id].Mode == "Endless", "mode is stored in server-side admission")
	check(
		stored[id].GameData.Mode == "Endless"
			and stored[id].GameData.StartNight == 1
			and stored[id].GameData.PartySize == 2,
		"server ticket binds mode, starting night and full roster size"
	)
	check(
		tickets:Create("duplicate", "private-id", { a, a }, "Story") == nil,
		"ticket creation rejects duplicate members"
	)
	h.env.game.PlaceId = Config.GamePlaceId
	h.env.game.PrivateServerId = "private-id"
	h.env.game.JobId = "destination"
	a.JoinData = {
		SourcePlaceId = Config.LobbyPlaceId,
		SourceGameId = 99,
		TeleportData = { TicketId = id, GameData = { Mode = "Story", StartNight = 900 } },
	}
	b.JoinData = a.JoinData
	check(tickets:Claim(a) ~= nil, "destination claims admission atomically")
	check(
		tickets:Claim(a).Ticket.GameData.Mode == "Endless" and tickets:Claim(a).Ticket.GameData.StartNight == 1,
		"forged teleport presentation data cannot change authoritative mode or starting night"
	)
	check(tickets:Claim(a) ~= nil, "duplicate destination claim succeeds idempotently")
	check(not tickets:Revoke(id, 1, h.time + 300), "source cannot revoke already arrived member")
	check(tickets:Revoke(id, 2, h.time + 300), "source revokes failed member")
	check(tickets:Claim(b) == nil, "late revoked teleport is rejected")
	local outsider = h:player(3)
	outsider.JoinData = a.JoinData
	check(tickets:Claim(outsider) == nil, "copied ticket does not authorize outsider")
	local bad = h:player(4)
	bad.JoinData = { TeleportData = { TicketId = string.rep("x", 1000) } }
	local count = calls
	check(tickets:Claim(bad) == nil and calls == count, "malformed ticket rejected before storage lookup")
end

do
	local h = Harness.Environment()
	local Config = h:load(core .. "Config.luau")
	local a, b = h:player(1), h:player(2)
	local roster = { Members = { ["1"] = {}, ["2"] = {} } }
	local tickets = {
		Claim = function()
			return { Id = "party", Ticket = roster }
		end,
		Read = function()
			return true, roster
		end,
	}
	local s = {
		Players = h.players,
		RunService = {
			IsStudio = function()
				return false
			end,
		},
		ReplicatedStorage = h.instance("ReplicatedStorage"),
	}
	local session = h:load("src/GServer/Services/GameSession.luau").new(s, Config, {
		IsReady = function()
			return true
		end,
	}, tickets)
	check(session:Admit(a), "first arrival admitted")
	session:Loaded(a)
	session:Tick()
	h:drain()
	check(not session:IsReady(), "partial arrival blocks start")
	check(session:Admit(b), "second arrival admitted")
	session:Loaded(b)
	session:Tick()
	check(session:IsReady(), "whole loaded party can start")
	session:Remove(b)
	check(
		session:IsReady() and session.state == "Ready" and session.expected["2"] == nil,
		"departure after admission preserves the remaining party's run"
	)
	check(not session:Admit(b), "departed players cannot rejoin a running admission")
	local second = h:load("src/GServer/Services/GameSession.luau").new(
		{
			Players = h.players,
			RunService = s.RunService,
			ReplicatedStorage = h.instance("ReplicatedStorage"),
		},
		Config,
		{
			IsReady = function()
				return true
			end,
		},
		tickets
	)
	second:Admit(a)
	second:Loaded(a)
	h.time += Config.ArrivalSeconds + 1
	second:Tick()
	check(
		second.state == "Incomplete" and not second:IsReady(),
		"missing arrival times out without starting partial run"
	)
end

do
	local h = Harness.Environment()
	local s = { ReplicatedStorage = h.instance("ReplicatedStorage") }
	local net = h:load(core .. "Network.luau").new(s, "Lobby")
	local calls = 0
	net:Bind(function()
		calls += 1
		return { Ok = true }
	end)
	local player = h:player(1)
	check(net.request.OnServerInvoke(player, "Create", { Capacity = 4 }).Ok, "valid request reaches handler")
	check(
		not net.request.OnServerInvoke(player, "Create", { Capacity = 4 }).Ok and calls == 1,
		"creation cooldown limits churn"
	)
	check(not net.request.OnServerInvoke(player, "Join", { PartyId = {} }).Ok, "nested payload rejected")
	check(
		not net.request.OnServerInvoke(player, "Join", { PartyId = string.rep("x", 81) }).Ok,
		"oversized payload rejected"
	)
	check(not net.request.OnServerInvoke(player, "Kick", { UserId = math.huge }).Ok, "nonfinite payload rejected")
	net.busy[player] = true
	check(not net.request.OnServerInvoke(player, "GetState").Ok, "overlapping yielding requests blocked")
	local worker = h:player(42)
	local input = {
		RunId = "run",
		Action = "PuzzleInput",
		OrderId = "phone",
		WorkId = "task",
		Move = 1,
		PuzzleRevision = 0,
	}
	check(
		net.request.OnServerInvoke(worker, "PrototypeAction", input).Ok,
		"six-field puzzle intent reaches gameplay handler"
	)
	input.Extra = true
	check(
		not net.request.OnServerInvoke(worker, "PrototypeAction", input).Ok,
		"puzzle payload still rejects excessive fields"
	)
	input.Extra = nil
	check(not net.request.OnServerInvoke(worker, "Join", input).Ok, "ordinary requests retain four-field bound")
end

do
	local h, travel, f = travelFixture()
	local a, b = h:player(1), h:player(2)
	f.source.RunService.IsStudio = function()
		return true
	end
	f.source.TeleportService.ReserveServerAsync = function()
		error("Studio must not reserve")
	end
	f.tickets.Create = function()
		error("Studio must not write admission")
	end
	local ok, reason = travel:Begin({ a, b }, "Game", function()
		return false
	end, nil, { Mode = "Endless" })
	check(
		not ok and reason == "StudioPreviewComplete",
		"Studio completes validated preview without claiming a teleport"
	)
	check(
		#f.packets == 0 and not f.frozen[a] and not f.frozen[b],
		"preview thaws every saved member and never teleports"
	)
	check(
		#h.prints == 3
			and string.find(h.prints[1][1], "Mode=Endless", 1, true) ~= nil
			and string.find(h.prints[2][1], "User2 (2)", 1, true) ~= nil,
		"Studio prints selected mode, validated roster, and destination"
	)
	check(a:GetAttribute("DPU_TravelStatus") == "StudioPreviewComplete", "preview publishes explicit diagnostic status")
	h.prints = {}
	f.failSave[b] = true
	ok, reason = travel:Begin({ a, b }, "Game", function()
		return false
	end, nil, { Mode = "Story" })
	check(
		not ok and reason == "SaveOrRosterChanged" and #h.prints == 0 and not f.frozen[a],
		"failed save cannot print false Studio success"
	)
end

for count = 1, 4 do
	for _, mode in ipairs({ "Story", "Endless" }) do
		local h, travel, f = travelFixture()
		local players = {}
		for i = 1, count do
			players[i] = h:player(i)
		end
		check(
			travel:Begin(players, "Game", function()
				return false
			end, nil, { Mode = mode }),
			"1-4 member party can prepare a mode-specific teleport"
		)
		travel:Tick()
		h:drain()
		check(
			#f.packets == 1 and #f.packets[1].Players == count and f.reservations() == 1,
			"whole party shares one private reservation"
		)
		local payload = f.packets[1].Options:GetTeleportData()
		check(
			payload.GameData.Mode == mode
				and payload.GameData.PartySize == count
				and payload.GameData.StartNight == 1
				and payload.Profile == nil,
			"public handoff carries only run metadata"
		)
		for _, player in ipairs(players) do
			check(f.frozen[player], "each profile was frozen and saved before dispatch")
		end
		local members = {}
		for _, player in ipairs(players) do
			members[tostring(player.UserId)] = {}
		end
		local session = h:load("src/GServer/Services/GameSession.luau").new(
			{
				Players = h.players,
				RunService = f.source.RunService,
				ReplicatedStorage = h.instance("ReplicatedStorage"),
			},
			f.config,
			{
				IsReady = function()
					return true
				end,
			},
			{
				Claim = function()
					return {
						Id = "run",
						Ticket = { Mode = mode, GameData = payload.GameData, Members = members },
					}
				end,
			}
		)
		for i, player in ipairs(players) do
			check(session:Admit(player), "destination admits expected member")
			session:Loaded(player)
			if i == count then
				session:Tick()
			end
			if i < count then
				check(not session:IsReady(), "partial arrival cannot start")
			end
		end
		check(
			session:IsReady() and session:Snapshot().GameData.Mode == mode,
			"loaded destination uses authoritative mode and game data"
		)
	end
end

print(string.format("PASS: %d runtime fault and integration checks.", total))
