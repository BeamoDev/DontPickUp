local Limiter = require(script.Parent.RateLimiter)
local Network = {}
Network.__index = Network

local function owned(parent, class, name)
	local existing = parent:FindFirstChild(name)
	assert(not existing, "Duplicate DontPickUp server/network startup: " .. name)
	local instance = Instance.new(class)
	instance.Name = name
	instance.Parent = parent
	return instance
end

function Network.new(services, environment)
	local root = owned(services.ReplicatedStorage, "Folder", "DontPickUp" .. environment .. "Net")
	local self = setmetatable(
		{
			root = root,
			request = owned(root, "RemoteFunction", "Request"),
			changed = owned(root, "RemoteEvent", "StateChanged"),
			busy = {},
			limiter = Limiter.new(os.clock),
			cooldowns = {},
			closing = false,
		},
		Network
	)
	return self
end

function Network:Bind(handler)
	self.request.OnServerInvoke = function(player, action, payload)
		if self.closing or not self.limiter:Take(player) then
			return { Ok = false, Code = "RateLimited" }
		end
		if self.busy[player] then
			return { Ok = false, Code = "RequestPending" }
		end
		if type(action) ~= "string" or #action > 24 then
			return { Ok = false, Code = "InvalidRequest" }
		end
		if payload == nil then
			payload = {}
		end
		if type(payload) ~= "table" then
			return { Ok = false, Code = "InvalidRequest" }
		end
		local fields = 0
		for key, value in pairs(payload) do
			fields += 1
			if
				fields > 4
				or type(key) ~= "string"
				or #key > 24
				or (type(value) ~= "string" and type(value) ~= "number" and type(value) ~= "boolean")
				or (type(value) == "string" and #value > 80)
				or (type(value) == "number" and (value ~= value or math.abs(value) == math.huge))
			then
				return { Ok = false, Code = "InvalidRequest" }
			end
		end
		if action == "Create" or action == "Start" or action == "ReturnLobby" then
			local cooldown = self.cooldowns[player] or {}
			self.cooldowns[player] = cooldown
			if os.clock() < (cooldown[action] or 0) then
				return { Ok = false, Code = "PleaseWait" }
			end
			cooldown[action] = os.clock() + (action == "Create" and 3 or 10)
		end
		self.busy[player] = true
		local ok, result = pcall(handler, player, action, payload)
		self.busy[player] = nil
		if not ok then
			warn("[DPU] Request handler failed:", action)
			return { Ok = false, Code = "ServerError" }
		end
		return result
	end
end

function Network:Push(player, snapshot)
	if player.Parent then
		self.changed:FireClient(player, snapshot or { InParty = false })
	end
end

function Network:Remove(player)
	self.limiter:Remove(player)
	self.cooldowns[player] = nil
	self.busy[player] = nil
end

return Network
