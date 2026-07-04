-- util/rng.lua
-- Deterministic seedable PRNG using SplitMix64, implemented with Lua 5.4
-- 64-bit integer arithmetic (native integers, wraparound is intentional).
-- SplitMix64 is used both as the generator itself and as the mechanism for
-- deriving independent streams in r:fork(tag) (this is the standard way
-- SplitMix64 is used to seed/split other generators).
--
-- Reference algorithm (public domain, Sebastiano Vigna):
--   state += 0x9E3779B97F4A7C15
--   z = state
--   z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9
--   z = (z ^ (z >> 27)) * 0x94D049BB133111EB
--   z = z ^ (z >> 31)
--   return z
--
-- All operations are done on Lua 5.4 native 64-bit integers, so overflow
-- wraps modulo 2^64 exactly like the reference C implementation. This is
-- deterministic and cross-platform as long as Lua integers are 64-bit
-- (the default build).

local M = {}

local GOLDEN_GAMMA = 0x9E3779B97F4A7C15
local MUL1 = 0xBF58476D1CE4E5B9
local MUL2 = 0x94D049BB133111EB

local mt = { __index = {} }
local R = mt.__index

-- Advance the internal state and return the next raw 64-bit integer.
local function next_u64(r)
  r.state = r.state + GOLDEN_GAMMA
  local z = r.state
  z = (z ~ (z >> 30)) * MUL1
  z = (z ~ (z >> 27)) * MUL2
  z = z ~ (z >> 31)
  return z
end

-- new(seed) -> r
-- seed may be any integer (floats are truncated via math.tointeger/floor).
function M.new(seed)
  seed = seed or 0
  if math.type(seed) ~= "integer" then
    seed = math.tointeger(seed) or math.floor(seed)
  end
  local r = setmetatable({ state = seed }, mt)
  return r
end

-- Raw next 64-bit integer (exposed for advanced use / forking).
function R:next_u64()
  return next_u64(self)
end

-- int(lo, hi) -> integer in [lo, hi] inclusive
function R:int(lo, hi)
  if hi == nil then
    hi = lo
    lo = 1
  end
  assert(lo <= hi, "rng:int requires lo <= hi")
  local range = (hi - lo) + 1
  local u = next_u64(self)
  -- Lua's % on integers is floor-mod and always returns a result with the
  -- same sign as the divisor, so this is non-negative for range > 0 even
  -- though u may be a "negative" 64-bit bit pattern.
  local m = u % range
  return lo + m
end

-- float() -> number in [0, 1)
function R:float()
  local u = next_u64(self)
  -- Use the top 53 bits for a well-distributed double in [0,1).
  local bits53 = (u >> 11) & 0x1FFFFFFFFFFFFF -- 53 bits, always >= 0
  return bits53 / 9007199254740992.0 -- 2^53
end

-- pick(list) -> random element, or nil if list empty
function R:pick(list)
  local n = #list
  if n == 0 then return nil end
  return list[self:int(1, n)]
end

-- shuffle(list) -> shuffles list in place (Fisher-Yates), returns list
function R:shuffle(list)
  local n = #list
  for i = n, 2, -1 do
    local j = self:int(1, i)
    list[i], list[j] = list[j], list[i]
  end
  return list
end

-- chance(p) -> boolean, true with probability p (p in 0..1)
function R:chance(p)
  if p <= 0 then return false end
  if p >= 1 then return true end
  return self:float() < p
end

-- fork(tag) -> new independent rng derived deterministically from current
-- state plus a string tag. We hash the tag bytes (FNV-1a 64-bit) combined
-- with the current state into a new seed, then advance this rng once so
-- the parent's subsequent output is unaffected by *how many* forks were
-- taken (forking never consumes from the parent's int/float sequence).
function R:fork(tag)
  tag = tostring(tag or "")
  local h = 0xCBF29CE484222325 -- FNV-1a 64-bit offset basis
  local prime = 0x100000001B3
  for i = 1, #tag do
    h = h ~ tag:byte(i)
    h = h * prime
  end
  -- Mix in the parent's current state so forks are also tied to the
  -- parent's position in its own sequence, not just the tag.
  local seed = h ~ self.state
  seed = seed + GOLDEN_GAMMA -- extra mix, avoids trivial correlation
  seed = (seed ~ (seed >> 30)) * MUL1
  seed = (seed ~ (seed >> 27)) * MUL2
  seed = seed ~ (seed >> 31)
  return M.new(seed)
end

-- Serializable state (SplitMix64 state is a single integer).
function R:get_state()
  return self.state
end

function M.from_state(state)
  return M.new(state)
end

-- derive(master_seed, tag) -> rng derived purely from (master, tag).
-- The determinism workhorse: streams keyed by domain AND entity
-- ("island:7", "missions:3") never perturb each other. Prefer deriving a
-- fresh stream from (master, tag-with-counter) over advancing a long-lived
-- one — derivation needs no saved state at all.
function M.derive(master_seed, tag)
  return M.new(master_seed):fork(tag)
end

return M
