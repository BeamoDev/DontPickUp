local Harness = require("./Harness")
local total = 0
local function check(value, label)
	assert(value, label)
	total += 1
end

local function fixture()
	local h = Harness.Environment()
	local queue = {}
	local sequence = 0
	local function schedule(thread, at)
		sequence += 1
		table.insert(queue, { Thread = thread, At = at, Order = sequence })
	end
	h.env.task = {
		spawn = function(fn, ...)
			local args = table.pack(...)
			schedule(
				coroutine.create(function()
					fn(table.unpack(args, 1, args.n))
				end),
				h.time
			)
		end,
		wait = function(n)
			coroutine.yield(n or 0.01)
		end,
	}
	function h:run()
		local steps = 0
		while #queue > 0 do
			steps += 1
			assert(steps < 20000, "Scheduler runaway")
			table.sort(queue, function(a, b)
				if a.At == b.At then
					return a.Order < b.Order
				end
				return a.At < b.At
			end)
			local job = table.remove(queue, 1)
			self.time = math.max(self.time, job.At)
			local ok, delay = coroutine.resume(job.Thread)
			assert(ok, tostring(delay))
			if coroutine.status(job.Thread) ~= "dead" then
				schedule(job.Thread, self.time + math.max(0.01, delay or 0.01))
			end
		end
	end
	function h:after(delay, fn)
		self.env.task.spawn(function()
			self.env.task.wait(delay)
			fn()
		end)
	end
	local schema = h:load("src/LServer/PlayerData/ProfileSchema.luau")
	local records = {}
	local f = { delay = 0, records = records, operations = 0 }
	local backend = {
		UpdateAsync = function(_, key, transform)
			f.operations += 1
			if f.delay > 0 then
				h.env.task.wait(f.delay)
			end
			local result = transform(schema.Copy(records[key]), {
				GetMetadata = function()
					return {}
				end,
			})
			if result then
				records[key] = schema.Copy(result)
			end
			if f.afterCommit then
				f.afterCommit(key, result)
			end
			return result
		end,
	}
	local services = {
		Players = h.players,
		RunService = {
			IsStudio = function()
				return false
			end,
		},
		HttpService = {
			GenerateGUID = function()
				h.serial += 1
				return "operation-" .. h.serial
			end,
		},
		DataStoreService = {
			GetDataStore = function()
				return backend
			end,
		},
	}
	local data = h:load("src/LServer/PlayerData/DataService.luau")
		.new(services, h:load("src/LServer/Configuration/ServerConfig.luau"))
	return h, data, f
end

do
	local h, data, f = fixture()
	local player = h:player(1)
	h.env.task.spawn(function()
		check(data:Load(player), "concurrent fixture loads")
	end)
	h:run()
	check(
		player:GetAttribute("DPU_EmployeeNumber") == f.records.player_1.Data.EmployeeNumber
			and player:GetAttribute("DPU_EmployeeNumber") >= 1000,
		"published employee number matches already committed server profile"
	)
	f.delay = 5
	h.env.task.spawn(function()
		check(data:Save(player, false), "in-flight autosave completes")
	end)
	h:after(1, function()
		check(
			data:RecordOutcome(player, { Id = "new-outcome", Survived = true, Shift = 1, CasesSolved = 7 }),
			"mutation while snapshot saving"
		)
	end)
	h:after(2, function()
		data:Remove(player)
	end)
	h:run()
	check(f.records.player_1.Data.Stats.CasesSolved == 7, "final save includes mutation after earlier snapshot")
	check(
		f.records.player_1.Lease == nil and data.entries[player] == nil,
		"departure waits for in-flight save before release"
	)
end

do
	local h, data, f = fixture()
	local player = h:player(1)
	f.delay = 3
	h.env.task.spawn(function()
		check(not data:Load(player), "shutdown cancels yielding load")
	end)
	h:after(1, function()
		data:Shutdown()
		check(data.activeLoads == 0, "shutdown waits for cancelled acquisition cleanup")
	end)
	h:run()
	check(
		f.records.player_1 == nil and data.entries[player] == nil,
		"shutdown cannot turn cancelled load into saved defaults"
	)
end

do
	local h, data, f = fixture()
	local player = h:player(1)
	local once = false
	f.afterCommit = function(_, result)
		if result and not once then
			once = true
			player.Parent = nil
			h.env.task.spawn(function()
				data:Remove(player)
			end)
			error("Acquire committed but response was lost")
		end
	end
	h.env.task.spawn(function()
		check(not data:Load(player), "ambiguous acquisition notices departed player")
	end)
	h:run()
	check(
		f.records.player_1 ~= nil and f.records.player_1.Lease == nil,
		"ambiguous cancelled load releases original lease"
	)
	check(data.activeLoads == 0 and data.entries[player] == nil, "cancelled player has no live profile")
end

do
	local h, data, f = fixture()
	local player = h:player(1)
	h.env.task.spawn(function()
		data:Load(player)
	end)
	h:run()
	f.delay = 1
	h.env.task.spawn(function()
		data:Shutdown()
	end)
	h:run()
	check(f.records.player_1.Lease == nil and data.entries[player] == nil, "parallel shutdown confirms final release")
end

print(string.format("PASS: %d concurrent save/load lifecycle checks.", total))
