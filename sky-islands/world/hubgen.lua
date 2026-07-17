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
  "      ,,,,#--8n---#,#--1R---#,,,,     ",
  "      ,,T,#-------+,+-------#,*,,     ",
  "       ,,,#########,#########,,,      ",
  "       ,,,,,..................,,      ",
  "      ,,,,,.....,,T,,....,*,,.,,      ",
  "     ,,,####+####,,......\",,..,,,     ",
  "     ,,,#-------#,,.....,....,T,      ",
  "     ,,,#--2M---#,......,,...,,       ",
  "     ,,,#-------#,....,,,....,,       ",
  "      ,,#########,...........,        ",
  "      ,,,v,...................        ",
  "       ,,,,......3----D               ",
  "        ,,T......--bb-                ",
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
  ["n"] = { t = "floor_planks", f = "locker" },
  ["R"] = { t = "floor_planks", f = "trader" },
  ["M"] = { t = "floor_planks", f = "coordinator" },
  ["D"] = { t = "floor_planks", f = "skiff_dock" },
  -- people spots (SI-0005): "1" store runner, "2" quest broker,
  -- "b" visitor berths on the pier. Terrain only; sim/npcs.lua seats
  -- people here via M.spots().
  ["1"] = { t = "floor_planks" },
  ["2"] = { t = "floor_planks" },
  ["b"] = { t = "floor_planks" },
  ["3"] = { t = "floor_planks" },
}

-- Where people stand (from the map art above). Pure function of the
-- MAP constant — no island state, so restored saves re-derive it free.
function M.spots()
  local out = { fixed = {}, berths = {} }
  local roles = { ["1"] = "store_runner", ["2"] = "quest_broker",
    ["3"] = "travel_agent" }
  for ry, row in ipairs(MAP) do
    for rx = 1, #row do
      local ch = row:sub(rx, rx)
      if roles[ch] then
        out.fixed[roles[ch]] = { x = rx - 1, y = ry - 1 }
      elseif ch == "b" then
        out.berths[#out.berths + 1] = { x = rx - 1, y = ry - 1 }
      end
    end
  end
  return out
end

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
        if f.def.id == "locker" then f.stash = {} end
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
