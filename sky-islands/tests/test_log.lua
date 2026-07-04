-- Tests for ui/log.lua

local log = require("ui.log")

local M = {}

function M.test_capacity_eviction(t)
  local l = log.new(3)
  l:push("a")
  l:push("b")
  l:push("c")
  l:push("d")
  l:push("e")

  local last = l:last(10)
  t.eq(#last, 3, "last(10) should cap at capacity (3)")
  t.eq(last[1].text, "c", "oldest surviving entry should be 'c'")
  t.eq(last[2].text, "d", "middle entry should be 'd'")
  t.eq(last[3].text, "e", "newest entry should be 'e'")
end

function M.test_last_n_less_than_count(t)
  local l = log.new(5)
  l:push("a")
  l:push("b")
  l:push("c")
  l:push("d")

  local last = l:last(2)
  t.eq(#last, 2, "last(2) should return exactly 2 entries")
  t.eq(last[1].text, "c", "should return the second-most-recent entry first")
  t.eq(last[2].text, "d", "should return the most-recent entry last")
end

function M.test_count_counts_all_pushes(t)
  local l = log.new(2)
  t.eq(l:count(), 0, "count() should start at 0")
  l:push("a")
  l:push("b")
  l:push("c")
  l:push("d")
  t.eq(l:count(), 4, "count() should track total pushes, not capped by capacity")
end

function M.test_color_passthrough(t)
  local l = log.new(3)
  l:push("with color", 42)
  l:push("without color")
  l:push("nil explicit", nil)

  local last = l:last(3)
  t.eq(last[1].color, 42, "color should pass through unchanged")
  t.eq(last[2].color, nil, "omitted color should be nil")
  t.eq(last[3].color, nil, "explicit nil color should stay nil")
end

function M.test_last_on_empty_log(t)
  local l = log.new(3)
  local last = l:last(5)
  t.eq(#last, 0, "last(n) on an empty log should return an empty array")
end

function M.test_last_ordering_oldest_to_newest(t)
  local l = log.new(4)
  l:push("1")
  l:push("2")
  l:push("3")

  local last = l:last(3)
  t.deep_eq(
    { last[1].text, last[2].text, last[3].text },
    { "1", "2", "3" },
    "last(n) should be ordered oldest..newest"
  )
end

return M
