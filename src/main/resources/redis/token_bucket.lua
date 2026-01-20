-- KEYS[1] = rate limit key
-- ARGV[1] = capacity
-- ARGV[2] = refill_rate (tokens per second)
-- ARGV[3] = current_time (epoch millis)

local key = KEYS[1]
local capacity = tonumber(ARGV[1])
local refill_rate = tonumber(ARGV[2])
local now = tonumber(ARGV[3])

local data = redis.call("HMGET", key, "tokens", "timestamp")
local tokens = tonumber(data[1])
local last_time = tonumber(data[2])

if tokens == nil then
    tokens = capacity
    last_time = now
end

local delta = math.max(0, now - last_time)
local refill = (delta / 1000) * refill_rate
tokens = math.min(capacity, tokens + refill)

local allowed = tokens >= 1
if allowed then
    tokens = tokens - 1
end

redis.call("HMSET", key,
    "tokens", tokens,
    "timestamp", now
)

redis.call("EXPIRE", key, math.ceil(capacity / refill_rate * 2))

return { allowed and 1 or 0, tokens }
