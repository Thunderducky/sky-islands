-- tests/test_grid.lua
local grid = require("util.grid")

local M = {}

M["idx/xy roundtrip including corners"] = function(t)
  local w, h = 10, 7
  local corners = {
    { 0, 0 },
    { w - 1, 0 },
    { 0, h - 1 },
    { w - 1, h - 1 },
    { 4, 3 },
  }
  for _, c in ipairs(corners) do
    local x, y = c[1], c[2]
    local i = grid.idx(x, y, w)
    local rx, ry = grid.xy(i, w)
    t.eq(rx, x, "x roundtrip at (" .. x .. "," .. y .. ")")
    t.eq(ry, y, "y roundtrip at (" .. x .. "," .. y .. ")")
  end
end

M["idx is 0-based and matches y*w+x"] = function(t)
  t.eq(grid.idx(0, 0, 5), 0)
  t.eq(grid.idx(4, 0, 5), 4)
  t.eq(grid.idx(0, 1, 5), 5)
  t.eq(grid.idx(3, 2, 5), 13)
end

M["in_bounds edges"] = function(t)
  local w, h = 5, 5
  t.eq(grid.in_bounds(0, 0, w, h), true)
  t.eq(grid.in_bounds(4, 4, w, h), true)
  t.eq(grid.in_bounds(-1, 0, w, h), false)
  t.eq(grid.in_bounds(0, -1, w, h), false)
  t.eq(grid.in_bounds(5, 0, w, h), false)
  t.eq(grid.in_bounds(0, 5, w, h), false)
end

M["neighbors4 count at corner, edge, center"] = function(t)
  local w, h = 5, 5
  t.eq(#grid.neighbors4(0, 0, w, h), 2, "corner")
  t.eq(#grid.neighbors4(0, 2, w, h), 3, "edge")
  t.eq(#grid.neighbors4(2, 2, w, h), 4, "center")
end

M["neighbors8 count at corner, edge, center"] = function(t)
  local w, h = 5, 5
  t.eq(#grid.neighbors8(0, 0, w, h), 3, "corner")
  t.eq(#grid.neighbors8(0, 2, w, h), 5, "edge")
  t.eq(#grid.neighbors8(2, 2, w, h), 8, "center")
end

M["neighbors4 only returns in-bounds tiles"] = function(t)
  local w, h = 3, 3
  local nbrs = grid.neighbors4(1, 1, w, h)
  for _, p in ipairs(nbrs) do
    t.ok(grid.in_bounds(p.x, p.y, w, h), "neighbor out of bounds")
  end
end

M["line includes both endpoints"] = function(t)
  local pts = grid.line(1, 1, 4, 4)
  t.eq(pts[1].x, 1)
  t.eq(pts[1].y, 1)
  t.eq(pts[#pts].x, 4)
  t.eq(pts[#pts].y, 4)
end

M["line known diagonal"] = function(t)
  local pts = grid.line(0, 0, 3, 3)
  local expected = {
    { x = 0, y = 0 },
    { x = 1, y = 1 },
    { x = 2, y = 2 },
    { x = 3, y = 3 },
  }
  t.eq(#pts, #expected, "diagonal length")
  for i = 1, #expected do
    t.eq(pts[i].x, expected[i].x, "diagonal x @" .. i)
    t.eq(pts[i].y, expected[i].y, "diagonal y @" .. i)
  end
end

M["line known straight horizontal line"] = function(t)
  local pts = grid.line(2, 5, 6, 5)
  t.eq(#pts, 5)
  for i, p in ipairs(pts) do
    t.eq(p.x, 2 + (i - 1), "x @" .. i)
    t.eq(p.y, 5, "y @" .. i)
  end
end

M["line single point"] = function(t)
  local pts = grid.line(3, 3, 3, 3)
  t.eq(#pts, 1)
  t.eq(pts[1].x, 3)
  t.eq(pts[1].y, 3)
end

-- Hand-built 5x5 map. '#' = wall, '.' = floor. A wall column at x=2
-- separates the left region (x=0..1) from the right region (x=3..4),
-- with no gap, so the two sides are fully disconnected.
--
--   col: 0 1 2 3 4
-- row0:  . . # . .
-- row1:  . . # . .
-- row2:  . . # . .
-- row3:  . . # . .
-- row4:  . . # . .
local function build_wall_map()
  local w, h = 5, 5
  local cells = {}
  for y = 0, h - 1 do
    for x = 0, w - 1 do
      local i = grid.idx(x, y, w)
      cells[i] = (x == 2) and "#" or "."
    end
  end
  return w, h, cells
end

local function passable_from(cells, w)
  return function(x, y)
    return cells[grid.idx(x, y, w)] == "."
  end
end

M["flood reaches correct count in left region"] = function(t)
  local w, h, cells = build_wall_map()
  local passable = passable_from(cells, w)
  local set, count = grid.flood(w, h, 0, 0, passable)
  t.eq(count, 10, "left region should have 2 cols * 5 rows = 10 tiles")
  -- spot check a reachable cell
  t.eq(set[grid.idx(1, 4, w)], true, "expected (1,4) reachable")
end

M["flood does not cross the wall"] = function(t)
  local w, h, cells = build_wall_map()
  local passable = passable_from(cells, w)
  local set = grid.flood(w, h, 0, 0, passable)
  -- (3,0) is in the right region, unreachable from the left start
  t.eq(set[grid.idx(3, 0, w)], nil, "wall should block flood into right region")
  -- the wall cell itself should never be in the set
  t.eq(set[grid.idx(2, 0, w)], nil, "wall cell should not be in flood set")
end

M["flood from right region reaches only right region"] = function(t)
  local w, h, cells = build_wall_map()
  local passable = passable_from(cells, w)
  local set, count = grid.flood(w, h, 4, 0, passable)
  t.eq(count, 10, "right region should have 2 cols * 5 rows = 10 tiles")
  t.eq(set[grid.idx(0, 0, w)], nil, "left region should be unreachable from right start")
end

M["flood start not passable returns empty set and 0"] = function(t)
  local w, h, cells = build_wall_map()
  local passable = passable_from(cells, w)
  local set, count = grid.flood(w, h, 2, 0, passable) -- start on a wall
  t.eq(count, 0)
  t.deep_eq(set, {})
end

return M
