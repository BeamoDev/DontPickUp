local fs = require("@lune/fs")
local luau = require("@lune/luau")
local Harness = {}

function Harness.Environment()
	local h = { time = 1000, jobs = {}, calls = {}, serial = 0 }
	local function newInstance(class)
		local properties = { ClassName = class, Name = class, attributes = {}, children = {} }
		local methods = {}
		local object
		function methods:IsA(name)
			return class == name
		end
		function methods:FindFirstChild(name)
			for _, child in ipairs(properties.children) do
				if child.Name == name then
					return child
				end
			end
			return nil
		end
		function methods:SetAttribute(name, value)
			properties.attributes[name] = value
		end
		function methods:GetAttribute(name)
			return properties.attributes[name]
		end
		function methods:SetTeleportData(value)
			properties.payload = value
		end
		function methods:GetTeleportData()
			return properties.payload
		end
		function methods:Kick(reason)
			properties.Kicked = reason
		end
		function methods:GetJoinData()
			return properties.JoinData or {}
		end
		object = setmetatable({}, {
			__index = function(_, key)
				if methods[key] ~= nil then
					return methods[key]
				end
				if properties[key] ~= nil then
					return properties[key]
				end
				return methods.FindFirstChild(object, key)
			end,
			__newindex = function(_, key, value)
				if key == "Parent" then
					if properties.Parent then
						local children = properties.Parent.children
						local index = table.find(children, object)
						if index then
							table.remove(children, index)
						end
					end
					if value and value.children then
						table.insert(value.children, object)
					end
				end
				properties[key] = value
			end,
		})
		return object
	end
	h.instance = newInstance
	h.players = newInstance("Players")
	h.env = {
		Instance = { new = newInstance },
		os = {
			clock = function()
				return h.time
			end,
			time = function()
				return math.floor(h.time)
			end,
		},
		task = {
			spawn = function(fn, ...)
				table.insert(h.jobs, { fn, table.pack(...) })
			end,
			wait = function(seconds)
				h.time += seconds or 0
			end,
		},
		game = {
			PlaceId = 110554757455252,
			GameId = 99,
			JobId = "source",
			PrivateServerId = "",
			PrivateServerOwnerId = 0,
		},
		Enum = {
			TeleportResult = { Failure = "Failure", Flooded = "Flooded", Unauthorized = "Unauthorized" },
		},
		warn = function(...)
			table.insert(h.calls, table.pack(...))
		end,
	}
	function h:drain()
		local steps = 0
		while #self.jobs > 0 do
			steps += 1
			assert(steps < 1000, "Runaway test scheduler")
			local job = table.remove(self.jobs, 1)
			job[1](table.unpack(job[2], 1, job[2].n))
		end
	end
	function h:player(id)
		local player = newInstance("Player")
		player.UserId, player.Name, player.DisplayName = id, "User" .. id, "Player" .. id
		player.Parent = self.players
		return player
	end
	function h:load(path, overrides)
		local parentPath = path:match("^(.*)/[^/]+$")
		local parent = setmetatable({}, {
			__index = function(_, key)
				return parentPath .. "/" .. key .. ".luau"
			end,
		})
		local env = table.clone(self.env)
		env.script = { Parent = parent }
		env.require = function(module)
			if overrides and overrides[module] then
				return overrides[module]
			end
			return self:load(module, overrides)
		end
		return luau.load(fs.readFile(path), { debugName = path, environment = env, injectGlobals = true })()
	end
	return h
end

function Harness.Compile(path)
	local count = 0
	for _, name in ipairs(fs.readDir(path)) do
		local child = path .. "/" .. name
		if fs.isDir(child) then
			count += Harness.Compile(child)
		elseif name:match("%.luau$") then
			luau.compile(fs.readFile(child))
			count += 1
		end
	end
	return count
end

return Harness
