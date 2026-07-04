-- The Tether: the company town. Hand-authored prefab — home should feel
-- placed, not rolled. Legend chars are authoring symbols, unrelated to
-- display glyphs.
local sub = require("world.substrate")
local prefab = require("world.prefab")

local M = {}

-- 38 wide x 21 tall, every row exactly 38 chars.
local MAP = {
  "                                      ",
  "            ,,T,,,,,*,,,,             ",
  "         ,,T,,,,,,,,,,,,T,,,          ",
  "       ,,,#########,#########,,       ",
  "       ,*,#-------#,#-------#,T,      ",
  "      ,,,,#--8----#,#---R---#,,,,     ",
  "      ,,T,#-------+,+-------#,*,,     ",
  "       ,,,#########,#########,,,      ",
  "       ,,,,,..................,,      ",
  "      ,,,,,.....,,T,,....,*,,.,,      ",
  "     ,,,####+####,,......\",,..,,,     ",
  "     ,,,#-------#,,.....,....,T,      ",
  "     ,,,#---M---#,......,,...,,       ",
  "     ,,,#-------#,....,,,....,,       ",
  "      ,,#########,...........,        ",
  "      ,,,v,...................        ",
  "       ,,,,......-----D               ",
  "        ,,T......-----                ",
  "         ,,,,....*,,,                 ",
  "           ,,,,,,,,,                  ",
  "                                      ",
}

local LEGEND = {
  [" "] = { t = "sky" },
  [","] = { t = "grass" },
  ["\""] = { t = "grass_tall" },
  ["T"] = { t = "tree" },
  ["*"] = { t = "bush" },
  ["v"] = { t = "bush", f = "forage_berries" },
  ["."] = { t = "dirt" },
  ["#"] = { t = "wall_plank" },
  ["-"] = { t = "floor_planks" },
  ["+"] = { t = "door_closed" },
  ["8"] = { t = "floor_planks", f = "bunk" },
  ["R"] = { t = "floor_planks", f = "trader" },
  ["M"] = { t = "floor_planks", f = "coordinator" },
  ["D"] = { t = "floor_planks", f = "skiff_dock" },
}

function M.build(defs)
  local h, w = #MAP, #MAP[1]
  local island = sub.new_island(w, h)
  island.name = "The Tether"
  island.is_hub = true
  prefab.stamp(island, defs, 0, 0, MAP, LEGEND)

  local land = 0
  for y = 0, h - 1 do
    for x = 0, w - 1 do
      local t = defs.terrain[sub.get(island, "terrain", x, y)]
      if not t.is_sky then
        land = land + 1
        sub.set(island, "fog", x, y, 1) -- home is known ground
      end
      local f = sub.feature_at(island, x, y)
      if f then
        if f.def.id == "bunk" then f.stash = {} end
        if f.def.id == "trader" then f.stock = {} end
        if f.def.id == "forage_berries" then
          f.loot = { { id = "berries", n = 3 } }
        end
        if f.def.id == "skiff_dock" then
          island.start_x, island.start_y = x, y
        end
      end
    end
  end
  island.land_count = land
  island.seen_count = land
  island.cache_count = 0
  return island
end

return M
