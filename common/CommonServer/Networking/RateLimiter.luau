-- Maintained in common/CommonServer/Networking/RateLimiter.luau. Deploy with tools/SyncCommon.ps1.
local Limiter = {}
Limiter.__index = Limiter

function Limiter.new(clock)
	return setmetatable({ clock = clock, buckets = {} }, Limiter)
end

function Limiter:Take(key)
	local now = self.clock()
	local bucket = self.buckets[key] or { Tokens = 8, At = now }
	bucket.Tokens = math.min(8, bucket.Tokens + math.max(0, now - bucket.At) * 2)
	bucket.At = now
	self.buckets[key] = bucket
	if bucket.Tokens < 1 then
		return false
	end
	bucket.Tokens -= 1
	return true
end

function Limiter:Remove(key)
	self.buckets[key] = nil
end

return Limiter
