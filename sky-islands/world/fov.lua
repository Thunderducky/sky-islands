-- Recursive shadowcasting (Björn Bergström's algorithm), 8 octants.
-- Pure: compute() takes callbacks; update() applies it to an island's fog
-- layer and maintains seen_count for survey coverage.
local sub = require("world.substrate")

local M = {}

-- Octant transforms: map octant-local (col,row) into world offsets.
local OCTANTS = {
  { 1, 0, 0, 1 }, { 0, 1, 1, 0 }, { 0, -1, 1, 0 }, { -1, 0, 0, 1 },
  { -1, 0, 0, -1 }, { 0, -1, -1, 0 }, { 0, 1, -1, 0 }, { 1, 0, 0, -1 },
}

local function cast(ox, oy, radius, row, slope_hi, slope_lo, xf, opaque, mark)
  if slope_hi < slope_lo then return end
  local r2 = radius * radius
  for i = row, radius do
    local blocked = false
    local new_hi = slope_hi
    -- col runs from the high-slope edge down to the low-slope edge
    local col_hi = math.floor(i * slope_hi + 0.5)
    local col_lo = math.ceil(i * slope_lo - 0.5)
    for col = col_hi, col_lo, -1 do
      local x = ox + col * xf[1] + i * xf[2]
      local y = oy + col * xf[3] + i * xf[4]
      local upper = (col + 0.5) / (i - 0.5) -- slope past the tile's outer corner
      local lower = (col - 0.5) / (i + 0.5) -- slope past the tile's inner corner
      if lower > slope_hi then
        -- tile entirely above the visible wedge
      elseif upper < slope_lo then
        break -- below the wedge; rest of the row is too
      else
        if col * col + i * i <= r2 then mark(x, y) end
        if blocked then
          if opaque(x, y) then
            new_hi = lower
          else
            blocked = false
            slope_hi = new_hi
          end
        elseif opaque(x, y) and i < radius then
          blocked = true
          cast(ox, oy, radius, i + 1, slope_hi, upper, xf, opaque, mark)
          new_hi = lower
        end
      end
    end
    if blocked then return end
  end
end

-- opaque(x,y)->bool must handle out-of-bounds (treat as opaque or clear,
-- caller's choice). mark(x,y) is called for each visible tile, origin incl.
function M.compute(ox, oy, radius, opaque, mark)
  mark(ox, oy)
  for _, xf in ipairs(OCTANTS) do
    cast(ox, oy, radius, 1, 1.0, 0.0, xf, opaque, mark)
  end
end

-- Recompute the island's fog around the player. Demotes previously-visible
-- to remembered, marks the new visible set, and keeps seen_count (coverage
-- numerator: land tiles ever seen) incremental.
function M.update(island, defs, ox, oy, radius)
  local fog, w, h = island.fog, island.w, island.h
  for i = 1, w * h do
    if fog[i] == 2 then fog[i] = 1 end
  end
  local function opaque(x, y)
    if x < 0 or y < 0 or x >= w or y >= h then return true end
    return defs.terrain[island.terrain[y * w + x + 1]].opaque
  end
  local function mark(x, y)
    if x < 0 or y < 0 or x >= w or y >= h then return end
    local i = y * w + x + 1
    if fog[i] == 0 and not defs.terrain[island.terrain[i]].is_sky then
      island.seen_count = island.seen_count + 1
    end
    fog[i] = 2
  end
  M.compute(ox, oy, radius, opaque, mark)
end

return M
