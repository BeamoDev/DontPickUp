local fs = require("@lune/fs")
local Harness = require("./Harness")
local total = 0
local function check(value, label)
	assert(value, label)
	total += 1
end
local h = Harness.Environment()
local Schema = h:load("src/LServer/PlayerData/ProfileSchema.luau")
local Config = h:load("src/LServer/Configuration/ServerConfig.luau")
local Store = h:load("src/LServer/PlayerData/ProfileStore.luau")

check(Schema.Validate(Schema.Default()), "default schema valid")
local invalid = Schema.Default()
invalid.Version = Schema.Version + 1
check(not Schema.Validate(invalid), "future schema rejected")
invalid = Schema.Default()
invalid.Stats.Deaths = 0 / 0
check(not Schema.Validate(invalid), "NaN rejected")
invalid = Schema.Default()
invalid.Progress.Endings.secret = "true"
check(not Schema.Validate(invalid), "malformed unlock rejected")
check(Schema.Decode({}) == nil, "malformed envelope not defaulted")
check(Schema.Decode(nil).Stats.CasesSolved == 0, "new profile allowed")

local records, failures, responseLost, cancelled = {}, 0, false, false
local updateHook
local store = Store.new({
	config = Config,
	schema = Schema,
	now = function()
		return math.floor(h.time)
	end,
	clock = function()
		return h.time
	end,
	wait = function(n)
		h.time += n
	end,
	update = function(userId, transform)
		if failures > 0 then
			failures -= 1
			error("Storage unavailable")
		end
		if updateHook then
			updateHook(userId)
		end
		local result = transform(Schema.Copy(records[userId]))
		if result then
			records[userId] = Schema.Copy(result)
		end
		if responseLost then
			responseLost = false
			error("Committed, response lost")
		end
		return result
	end,
})
local a = store:Acquire(1, "lobby", function()
	return false
end)
check(a ~= nil and records[1].Lease.Token == "lobby", "acquire fresh owner")
local employeeNumber = a.Data.EmployeeNumber
check(
	employeeNumber >= 1000 and employeeNumber <= 9999 and records[1].Data.EmployeeNumber == employeeNumber,
	"employee number is committed on first acquisition, before first save"
)
a.Data.Stats.CasesSolved = 12
check(store:Write(1, a, a.Data, false, "save-1", h.time + 20), "save current owner")
check(records[1].Data.Stats.CasesSolved == 12, "save data persisted")
local before = h.time
local b = store:Acquire(1, "game", function()
	return false
end)
check(b ~= nil and h.time - before >= Config.LeaseSeconds, "new owner waits full lease")
check(b.Data.Stats.CasesSolved == 12, "takeover preserves data")
check(b.Data.EmployeeNumber == employeeNumber, "Lobby to Game acquisition retains the employee number")
local ok, reason = store:Write(1, a, a.Data, true, "stale-release", h.time + 20)
check(not ok and reason == "OwnershipLost" and records[1].Lease.Token == "game", "stale owner cannot save or release")
responseLost = true
check(store:Write(1, b, b.Data, true, "release-game", h.time + 20), "ambiguous release retries idempotently")
check(records[1].Lease == nil, "release clears lease")
records[2] = { Format = 1, Data = { Version = 900 } }
local missing, why = store:Acquire(2, "bad", function()
	return false
end)
check(missing == nil and why == "InvalidData" and records[2].Data.Version == 900, "future data remains untouched")
failures = 2
local retry = store:Acquire(3, "retry", function()
	return false
end)
check(retry ~= nil, "transient load failure recovers")
responseLost = true
local ambiguous = store:Acquire(4, "same-token", function()
	return false
end)
check(ambiguous ~= nil and records[4].Lease.Token == "same-token", "ambiguous acquire reuses token")
cancelled = false
updateHook = function(userId)
	if userId == 5 then
		cancelled = true
	end
end
local cancelResult = store:Acquire(5, "cancelled", function()
	return cancelled
end)
check(cancelResult == nil and records[5] == nil, "departure before acquire does not create profile")
updateHook = nil
records[6] = { Format = 1, Data = Schema.Default(), Lease = { Token = "cancelled-owner", Expires = h.time + 180 } }
records[6].Data.Stats.CasesSolved = 99
check(store:Abandon(6, "cancelled-owner"), "abandon succeeds")
check(records[6].Data.Stats.CasesSolved == 99 and records[6].Lease == nil, "abandon preserves original data")
check(store:Abandon(3, "wrong-owner") and records[3].Lease.Token == "retry", "abandon does not unlock someone else")

-- Migration commits atomically with lease acquisition, retaining existing progression.
for _, version in ipairs({ 1, 2, 3 }) do
	local old = Schema.Default()
	old.Version, old.EmployeeNumber = version, nil
	old.Stats.Credits, old.Progress.HighestShift = version == 1 and nil or 64, 5
	old.Progress.Evidence.saved_clue = true
	old.RecentOutcomes = { "paid_once" }
	if version < 3 then
		old.Settings.MusicEnabled, old.Settings.SFXEnabled, old.Settings.CameraShake = nil, nil, nil
	end
	records[20 + version] = { Format = 1, Data = old }
	local migrated = store:Acquire(20 + version, "migration", function()
		return false
	end)
	check(
		migrated and migrated.Data.Version == Schema.Version and Schema.Validate(migrated.Data),
		"all historical schemas acquire as current validated profiles"
	)
	check(
		migrated.Data.EmployeeNumber >= 1000
			and records[20 + version].Data.EmployeeNumber == migrated.Data.EmployeeNumber,
		"existing player receives a durably assigned employee number"
	)
	check(
		migrated.Data.Progress.HighestShift == 5
			and migrated.Data.Progress.Evidence.saved_clue
			and migrated.Data.RecentOutcomes[1] == "paid_once"
			and migrated.Data.Stats.Credits == (version == 1 and 0 or 64),
		"identity migration preserves progress, evidence, receipts and credits"
	)
end
for _, value in ipairs({ -1, 999, 10000, 1234.5, "1234", 0 / 0 }) do
	local malformed = Schema.Default()
	malformed.EmployeeNumber = value
	check(not Schema.Validate(malformed), "malformed employee identity fails closed")
end
local stableAfterLostReply
local actualUpdate = store.d.update
store.d.update = function(userId, transform)
	local result = transform(Schema.Copy(records[userId]))
	if result then
		records[userId] = Schema.Copy(result)
	end
	if not stableAfterLostReply then
		stableAfterLostReply = result.Data.EmployeeNumber
		error("employee assignment committed, reply lost")
	end
	return result
end
local recovered = store:Acquire(30, "lost-reply", function()
	return false
end)
check(recovered.Data.EmployeeNumber == stableAfterLostReply, "lost acquire reply cannot reroll committed identity")
store.d.update = actualUpdate

local Party = h:load("src/LServer/Matchmaking/PartyService.luau")
local host, friend, stranger = h:player(10), h:player(11), h:player(12)
local ready, friendship = {}, true
local friendshipHook
local travelCount = 0
local deps = {
	config = Config,
	clock = function()
		return h.time
	end,
	spawn = h.env.task.spawn,
	ready = function(player)
		return ready[player] ~= false
	end,
	present = function(player)
		return player.Parent == h.players
	end,
	changed = function() end,
	friends = function()
		if friendshipHook then
			friendshipHook()
		end
		return friendship
	end,
	canTravel = function()
		return true
	end,
	travel = function()
		travelCount += 1
		return true
	end,
}
local party = Party.new(deps)
check(not party:Create(host, 0 / 0, "Friends"), "NaN capacity rejected")
check(party:Create(host, 2, "Friends"), "host creates friends party")
check(not party:Create(host, 2, "Public"), "one party per player")
local id = party:Get(host).Id
friendship = false
check(not party:Join(stranger, id), "nonfriend rejected")
friendship = true
check(party:Join(friend, id), "friend joins")
check(not party:Join(stranger, id), "capacity enforced")
check(not party:Start(friend), "only host starts")
check(not party:Start(host), "all members must be ready")
check(party:Ready(friend, true) and party:Start(host), "ready party starts countdown")
check(not party:Start(host), "duplicate start rejected")
check(party:Ready(friend, false) and party:Get(host).State == "Open", "unready cancels countdown")
check(party:Ready(friend, true) and party:Start(host), "countdown restarts")
h.time += Config.CountdownSeconds
party:Tick()
party:Tick()
h:drain()
check(travelCount == 1 and party:Get(host).State == "Teleporting", "countdown dispatches exactly once")
check(not party:Remove(friend, false), "cannot voluntarily change dispatched roster")
check(party:Remove(host, true) and party:Get(friend).HostUserId == friend.UserId, "departed host transfers leadership")
party:Remove(friend, true)
check(next(party.parties) == nil, "empty party cleaned up")
party = Party.new(deps)
party:Create(host, 3, "Friends")
id = party:Get(host).Id
friendshipHook = function()
	party:Remove(host, true)
end
check(not party:Join(friend, id) and party:Get(friend) == nil, "yielding friendship rechecks deleted party")
friendshipHook = nil
party:Create(host, 3, "Friends")
id = party:Get(host).Id
party:Join(friend, id)
check(party:Kick(host, friend.UserId) and not party:Join(friend, id), "kick blocks rejoin to same party")
h.time += Config.PartyIdleSeconds + 1
party:Tick()
check(next(party.parties) == nil, "idle parties expire")

local Rules = h:load("src/LServer/Travel/AdmissionRules.luau")
local ticket = {
	Version = 1,
	Expires = h.time + 60,
	LobbyPlaceId = 100,
	GamePlaceId = 200,
	PrivateServerId = "reserved",
	Members = { ["10"] = {} },
}
local context = {
	Now = h.time,
	SourcePlaceId = 100,
	SourceGameId = 99,
	GameId = 99,
	PlaceId = 200,
	PrivateServerId = "reserved",
	PrivateServerOwnerId = 0,
	JobId = "job",
	UserId = 10,
}
check(Rules.CanClaim(ticket, context), "authorized member admitted")
for key, value in pairs({
	SourcePlaceId = 101,
	SourceGameId = 100,
	PlaceId = 201,
	PrivateServerId = "public",
	PrivateServerOwnerId = 10,
	UserId = 11,
	Now = h.time + 61,
}) do
	local wrong = table.clone(context)
	wrong[key] = value
	check(not Rules.CanClaim(ticket, wrong), "reject invalid admission " .. key)
end
ticket.Members["10"].Revoked = true
check(not Rules.CanClaim(ticket, context), "revoked admission rejected")
ticket.Members["10"].Revoked = nil
ticket.JobId = "other-job"
check(not Rules.CanClaim(ticket, context), "cross-instance party split rejected")
ticket.JobId = "job"
ticket.Members["10"].ClaimedJob = "job"
check(Rules.CanClaim(ticket, context), "same destination claim is idempotent")

local limiter = h:load("src/LServer/Networking/RateLimiter.luau").new(function()
	return h.time
end)
for _ = 1, 8 do
	check(limiter:Take(host), "initial request budget")
end
check(not limiter:Take(host), "request flood rejected")
h.time += 0.5
check(limiter:Take(host) and not limiter:Take(host), "request budget replenishes at bounded rate")

local serde = require("@lune/serde")
local deployment = serde.decode("json", fs.readFile("project.sources.json"))
for _, entry in ipairs(deployment.CommonModules) do
	for _, target in ipairs(entry.Targets) do
		check(fs.readFile(entry.Source) == fs.readFile(target), "canonical common deployment " .. target)
	end
end
-- Every static Roblox require must resolve after moving modules, including bootstraps.
local function references(folder)
	for _, name in ipairs(fs.readDir(folder)) do
		local path = folder .. "/" .. name
		if fs.isDir(path) then
			references(path)
		elseif name:match("%.luau$") then
			check(path:match("^src/[LG]%a+/%w+/[^/]+%.luau$") ~= nil, "exact Root/System/Script layout: " .. path)
			local source = fs.readFile(path)
			if source:find("local Shared =", 1, true) then
				local rootName = path:match("^src/([LG])") .. "Shared"
				check(
					source:find(':WaitForChild("' .. rootName .. '", 30)', 1, true),
					path .. " must use ReplicatedStorage." .. rootName
				)
			end
			source = source:gsub(':WaitForChild%("([%w_]+)"%s*,%s*%d+%)', ".%1")
			for expression in source:gmatch("require%(([%w_%.]+)%)") do
				local base, rest = expression:match("^(%w+)%.(.+)$")
				if base == "script" or base == "root" or base == "Shared" then
					local target = base == "script" and path:gsub("%.luau$", "")
						or base == "Shared" and ("src/" .. path:match("^src/([LG])") .. "Shared")
						or (
							source:find("local root = script.Parent.Parent", 1, true)
								and folder:match("^(.*)/[^/]+$")
							or folder
						)
					for segment in rest:gmatch("[^%.]+") do
						target = segment == "Parent" and target:match("^(.*)/[^/]+$") or target .. "/" .. segment
					end
					check(fs.isFile(target .. ".luau"), path .. " unresolved import " .. expression)
					local sharedRoot = path:match("^(src/[LG]Shared)/")
					if sharedRoot then
						check(
							target:sub(1, #sharedRoot + 1) == sharedRoot .. "/",
							path .. " imports outside its public Shared root"
						)
					end
				end
			end
		end
	end
end
references("src")
for _, environment in ipairs({ "L", "G" }) do
	local function publicModules(folder)
		for _, name in ipairs(fs.readDir(folder)) do
			local path = folder .. "/" .. name
			if fs.isDir(path) then
				publicModules(path)
			else
				check(
					not name:match("%.server%.luau$") and not name:match("%.local%.luau$"),
					"Shared contains only ModuleScripts: " .. path
				)
			end
		end
	end
	publicModules("src/" .. environment .. "Shared")
end
local compiled = Harness.Compile("src") + Harness.Compile("common") + Harness.Compile("tests")
print(string.format("PASS: %d regression checks; %d Luau files compiled.", total, compiled))
