-- tests/test_rng.lua
local rng = require("util.rng")

local M = {}

M["same seed produces identical first 20 ints"] = function(t)
  local a = rng.new(12345)
  local b = rng.new(12345)
  for i = 1, 20 do
    t.eq(a:int(1, 1000000), b:int(1, 1000000), "draw #" .. i)
  end
end

M["different seeds produce different streams"] = function(t)
  local a = rng.new(1)
  local b = rng.new(2)
  local same = true
  for _ = 1, 20 do
    if a:int(1, 1000000000) ~= b:int(1, 1000000000) then
      same = false
      break
    end
  end
  t.ok(not same, "expected different seeds to diverge within 20 draws")
end

M["int(lo, hi) stays within bounds"] = function(t)
  local r = rng.new(999)
  for _ = 1, 5000 do
    local v = r:int(5, 9)
    t.ok(v >= 5 and v <= 9, "value out of bounds: " .. tostring(v))
  end
end

M["int(lo, hi) hits both endpoints over many draws"] = function(t)
  local r = rng.new(42)
  local seen_lo, seen_hi = false, false
  for _ = 1, 5000 do
    local v = r:int(1, 3)
    if v == 1 then seen_lo = true end
    if v == 3 then seen_hi = true end
  end
  t.ok(seen_lo, "never drew lo endpoint")
  t.ok(seen_hi, "never drew hi endpoint")
end

M["float() is in [0, 1)"] = function(t)
  local r = rng.new(7)
  for _ = 1, 5000 do
    local f = r:float()
    t.ok(f >= 0 and f < 1, "float out of range: " .. tostring(f))
  end
end

M["chance(0) is always false"] = function(t)
  local r = rng.new(555)
  for _ = 1, 200 do
    t.eq(r:chance(0), false)
  end
end

M["chance(1) is always true"] = function(t)
  local r = rng.new(556)
  for _ = 1, 200 do
    t.eq(r:chance(1), true)
  end
end

M["pick from empty list is nil"] = function(t)
  local r = rng.new(1)
  t.eq(r:pick({}), nil)
end

M["pick returns an element from the list"] = function(t)
  local r = rng.new(2)
  local list = { "a", "b", "c" }
  for _ = 1, 20 do
    local v = r:pick(list)
    t.ok(v == "a" or v == "b" or v == "c", "unexpected pick: " .. tostring(v))
  end
end

M["shuffle preserves multiset"] = function(t)
  local r = rng.new(3)
  local original = { 1, 2, 3, 4, 5, 5, 6, 7 }
  local list = {}
  for i, v in ipairs(original) do list[i] = v end

  r:shuffle(list)

  t.eq(#list, #original, "length changed after shuffle")

  local function counts(arr)
    local c = {}
    for _, v in ipairs(arr) do
      c[v] = (c[v] or 0) + 1
    end
    return c
  end

  t.deep_eq(counts(list), counts(original), "multiset changed after shuffle")
end

M["fork('a') and fork('b') differ"] = function(t)
  local base = rng.new(100)
  local fa = base:fork("a")
  local fb = base:fork("b")
  local diff = false
  for _ = 1, 20 do
    if fa:int(1, 1000000000) ~= fb:int(1, 1000000000) then
      diff = true
      break
    end
  end
  t.ok(diff, "expected fork('a') and fork('b') to diverge")
end

M["forked stream is independent of parent"] = function(t)
  local parent = rng.new(2024)
  local child = parent:fork("child")

  -- Snapshot what the parent WOULD draw next, without forking again.
  local expected_next = {}
  local probe = rng.new(2024) -- identical to parent's initial state
  -- probe has consumed nothing yet, same as parent before fork.
  for i = 1, 5 do
    expected_next[i] = probe:int(1, 1000000)
  end

  -- Now actually draw a bunch from the child; this must not perturb parent.
  for _ = 1, 50 do
    child:int(1, 1000000)
  end

  for i = 1, 5 do
    t.eq(parent:int(1, 1000000), expected_next[i], "parent draw #" .. i .. " after forking/using child")
  end
end

M["fork is deterministic for same tag and parent state"] = function(t)
  local p1 = rng.new(77)
  local p2 = rng.new(77)
  local c1 = p1:fork("tag-x")
  local c2 = p2:fork("tag-x")
  for i = 1, 20 do
    t.eq(c1:int(1, 1000000), c2:int(1, 1000000), "fork draw #" .. i)
  end
end

return M
