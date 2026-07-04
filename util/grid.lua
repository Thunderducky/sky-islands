-- util/grid.lua
-- Grid math helpers. Coordinates are 0-based (x, y). idx = y*w + x (0-based).

local M = {}

-- idx(x, y, w) -> 0-based integer index
function M.idx(x, y, w)
  return y * w + x
end

-- xy(idx, w) -> x, y (two return values)
function M.xy(idx, w)
  local y = idx // w
  local x = idx - y * w
  return x, y
end

-- in_bounds(x, y, w, h) -> boolean
function M.in_bounds(x, y, w, h)
  return x >= 0 and x < w and y >= 0 and y < h
end

-- neighbors4(x, y, w, h) -> array of {x=, y=}, order: W E N S, in-bounds only
function M.neighbors4(x, y, w, h)
  local out = {}
  local candidates = {
    { x - 1, y }, -- W
    { x + 1, y }, -- E
    { x, y - 1 }, -- N
    { x, y + 1 }, -- S
  }
  for i = 1, #candidates do
    local cx, cy = candidates[i][1], candidates[i][2]
    if M.in_bounds(cx, cy, w, h) then
      out[#out + 1] = { x = cx, y = cy }
    end
  end
  return out
end

-- neighbors8(x, y, w, h) -> array of {x=, y=}, in-bounds only
-- Order: the 4 cardinal directions (W E N S) followed by the 4 diagonals
-- (NW NE SW SE).
function M.neighbors8(x, y, w, h)
  local out = M.neighbors4(x, y, w, h)
  local diagonals = {
    { x - 1, y - 1 }, -- NW
    { x + 1, y - 1 }, -- NE
    { x - 1, y + 1 }, -- SW
    { x + 1, y + 1 }, -- SE
  }
  for i = 1, #diagonals do
    local cx, cy = diagonals[i][1], diagonals[i][2]
    if M.in_bounds(cx, cy, w, h) then
      out[#out + 1] = { x = cx, y = cy }
    end
  end
  return out
end

-- line(x0, y0, x1, y1) -> array of {x=, y=} including both endpoints
-- Standard integer Bresenham line algorithm.
function M.line(x0, y0, x1, y1)
  local pts = {}
  local dx = math.abs(x1 - x0)
  local dy = -math.abs(y1 - y0)
  local sx = x0 < x1 and 1 or -1
  local sy = y0 < y1 and 1 or -1
  local err = dx + dy

  local x, y = x0, y0
  while true do
    pts[#pts + 1] = { x = x, y = y }
    if x == x1 and y == y1 then break end
    local e2 = 2 * err
    if e2 >= dy then
      err = err + dy
      x = x + sx
    end
    if e2 <= dx then
      err = err + dx
      y = y + sy
    end
  end
  return pts
end

-- flood(w, h, sx, sy, passable) -> (set, count)
-- 4-directional flood fill from (sx, sy). passable(x, y) -> bool callback.
-- set is a table keyed by 0-based idx with value true.
-- Returns an empty set and 0 if the start tile is not passable.
function M.flood(w, h, sx, sy, passable)
  local set = {}
  if not M.in_bounds(sx, sy, w, h) or not passable(sx, sy) then
    return set, 0
  end

  local start_idx = M.idx(sx, sy, w)
  set[start_idx] = true
  local count = 1

  local stack = { { sx, sy } }
  local sp = 1
  while sp > 0 do
    local cur = stack[sp]
    stack[sp] = nil
    sp = sp - 1
    local cx, cy = cur[1], cur[2]
    local nbrs = M.neighbors4(cx, cy, w, h)
    for i = 1, #nbrs do
      local nx, ny = nbrs[i].x, nbrs[i].y
      local nidx = M.idx(nx, ny, w)
      if not set[nidx] and passable(nx, ny) then
        set[nidx] = true
        count = count + 1
        sp = sp + 1
        stack[sp] = { nx, ny }
      end
    end
  end

  return set, count
end

return M
