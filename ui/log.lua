-- Message ring buffer. Pure Lua, no engine calls.
-- Keeps only the `capacity` most recent pushed entries, but tracks the
-- total number of pushes ever seen via count().

local Log = {}
Log.__index = Log

local M = {}

--- Create a new log with the given ring capacity.
-- @param capacity number of entries to retain
-- @return log instance
function M.new(capacity)
  local l = setmetatable({}, Log)
  l.capacity = capacity
  l.entries = {}
  l.head = 1 -- index in `entries` where the next push will be written
  l.size = 0 -- number of live entries currently stored (<= capacity)
  l.total = 0 -- total pushes ever, uncapped
  return l
end

--- Push a new message onto the ring, evicting the oldest if full.
-- @param text string
-- @param color optional palette color; nil ok
function Log:push(text, color)
  self.entries[self.head] = { text = text, color = color }
  self.head = (self.head % self.capacity) + 1
  if self.size < self.capacity then
    self.size = self.size + 1
  end
  self.total = self.total + 1
end

--- Return the most recent `n` entries, oldest..newest, at most n entries.
-- @param n number
-- @return array of {text=..., color=...}
function Log:last(n)
  local count = math.min(n, self.size)
  local result = {}
  if count <= 0 then
    return result
  end
  -- The most recently written slot is at index (head - 1), wrapping.
  -- Walk backwards `count` entries from there, then reverse into
  -- oldest..newest order.
  for i = count, 1, -1 do
    local offset = i - 1
    local idx = self.head - 1 - offset
    idx = ((idx - 1) % self.capacity) + 1
    result[count - i + 1] = self.entries[idx]
  end
  return result
end

--- Total number of pushes ever made, not capped by capacity.
-- @return number
function Log:count()
  return self.total
end

return M
