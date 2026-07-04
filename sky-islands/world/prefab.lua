-- Stamp hand-authored ASCII maps into the substrate. A prefab is an array
-- of equal-length strings plus a legend mapping each char to
-- { t = terrain_id, f = feature_id? }. Chars absent from the legend error
-- at stamp time (typo safety); the map is authorship, keep it strict.
local sub = require("world.substrate")

local M = {}

function M.stamp(island, defs, ox, oy, rows, legend)
  for ry, row in ipairs(rows) do
    for rx = 1, #row do
      local ch = row:sub(rx, rx)
      local cell = legend[ch]
      assert(cell, ("prefab: char %q at row %d col %d not in legend")
        :format(ch, ry, rx))
      local x, y = ox + rx - 1, oy + ry - 1
      sub.set(island, "terrain", x, y, defs.tid[cell.t])
      if cell.f then
        sub.set_feature(island, x, y, { def = defs.feature_by_id[cell.f] })
      end
    end
  end
end

return M
