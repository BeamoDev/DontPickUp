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
				or (name == "GuiButton" and (class == "TextButton" or class == "ImageButton"))
				or (name == "GuiObject" and table.find(
					{ "Frame", "ScrollingFrame", "TextLabel", "TextButton", "ImageLabel", "ImageButton" },
					class
				) ~= nil)
				or (name == "BasePart" and class == "Part")
		end
		function methods:FindFirstChild(name, recursive)
			for _, child in ipairs(properties.children) do
				if child.Name == name then
					return child
				end
			end
			if recursive then
				for _, child in ipairs(properties.children) do
					local found = child:FindFirstChild(name, true)
					if found then
						return found
					end
				end
			end
			return nil
		end
		function methods:GetChildren()
			return table.clone(properties.children)
		end
		function methods:GetDescendants()
			local descendants = {}
			for _, child in ipairs(properties.children) do
				table.insert(descendants, child)
				for _, descendant in ipairs(child:GetDescendants()) do
					table.insert(descendants, descendant)
				end
			end
			return descendants
		end
		function methods:PivotTo(frame)
			if properties.PivotTo then
				return properties.PivotTo(self, frame)
			end
			local previous = properties.WorldPivot or h.env.CFrame.new()
			for _, descendant in ipairs(self:GetDescendants()) do
				if descendant:IsA("BasePart") then
					descendant.CFrame = frame * previous:ToObjectSpace(descendant.CFrame)
					descendant.Position = descendant.CFrame.Position
				end
			end
			properties.WorldPivot = frame
		end
		function methods:GetPlayers()
			local players = {}
			for _, child in ipairs(properties.children) do
				if child:IsA("Player") then
					table.insert(players, child)
				end
			end
			return players
		end
		function methods:FindFirstChildWhichIsA(name, recursive)
			for _, child in ipairs(properties.children) do
				if child:IsA(name) then
					return child
				end
			end
			if recursive then
				for _, child in ipairs(properties.children) do
					local found = child:FindFirstChildWhichIsA(name, true)
					if found then
						return found
					end
				end
			end
			return nil
		end
		function methods:FindFirstChildOfClass(name)
			return self:FindFirstChildWhichIsA(name)
		end
		function methods:IsDescendantOf(parent)
			local current = properties.Parent
			while current do
				if current == parent then
					return true
				end
				current = current.Parent
			end
			return false
		end
		function methods:GetFullName()
			return properties.Parent and properties.Parent:GetFullName() .. "." .. properties.Name or properties.Name
		end
		function methods:Clone()
			local copy = newInstance(class)
			for key, value in pairs(properties) do
				if key ~= "Parent" and key ~= "children" and key ~= "attributes" and key ~= "Activated" then
					copy[key] = value
				end
			end
			for key, value in pairs(properties.attributes) do
				copy:SetAttribute(key, value)
			end
			for _, child in ipairs(properties.children) do
				local clone = child:Clone()
				clone.Parent = copy
			end
			return copy
		end
		function methods:Destroy()
			for _, child in ipairs(table.clone(properties.children)) do
				child:Destroy()
			end
			self.Parent = nil
		end
		if class == "TextButton" or class == "ImageButton" then
			local connections = {}
			properties.Activated = {
				Connect = function(_, callback)
					local connection = { Connected = true, callback = callback }
					function connection:Disconnect()
						self.Connected = false
					end
					table.insert(connections, connection)
					return connection
				end,
				Fire = function()
					for _, connection in ipairs(connections) do
						if connection.Connected then
							connection.callback()
						end
					end
				end,
			}
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
		local function node(location)
			return setmetatable({ Path = location }, {
				__index = function(_, key)
					if key == "WaitForChild" then
						return function(_, name)
							local child = location .. "/" .. name
							return (fs.isDir(child) or fs.isFile(child .. ".luau")) and node(child) or nil
						end
					end
					return node(key == "Parent" and location:match("^(.*)/[^/]+$") or location .. "/" .. key)
				end,
			})
		end
		local env = table.clone(self.env)
		-- Keep live place/job fields shared with fixtures while resolving per-place modules.
		env.game = setmetatable({}, { __index = self.env.game })
		function env.game:GetService(name)
			if name == "ReplicatedStorage" then
				return {
					WaitForChild = function(_, child)
						local rootName = assert(path:match("^src/([LG])")) .. "Shared"
						assert(child == rootName, "Expected ReplicatedStorage." .. rootName .. ", got " .. child)
						return node("src/" .. rootName)
					end,
				}
			end
			error("Unsupported test service: " .. name)
		end
		env.script = node(path:gsub("%.luau$", ""))
		env.require = function(module)
			module = type(module) == "table" and module.Path .. ".luau" or module
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
