-- Build a mission island from a hand-authored spec (defs/islands.lua).
-- Same stamp machinery as the hub; the post-pass initializes feature
-- INSTANCES (loot, latent found-flags, the beacon/start) and places
-- creatures. Deterministic by construction: no RNG anywhere.
local sub = require("world.substrate")
local prefab = require("world.prefab")

local M = {}

-- A latent char in an authored map marks the REP tile; if the def has a
-- footprint, stamp it around that point (authors place one letter and
-- the splat appears — leave clearance in the map art).
local function stamp_latent_footprint(island, defs, fd, x, y)
  local fp = fd.footprint
  if not fp then return nil, nil end
  local rox, roy
  for fry, frow in ipairs(fp.rows) do
    local fcx = frow:find("@", 1, true)
    if fcx then rox, roy = x - (fcx - 1), y - (fry - 1) end
  end
  assert(sub.in_bounds(island, rox, roy) and
    sub.in_bounds(island, rox + #fp.rows[1] - 1, roy + #fp.rows - 1),
    fd.id .. ": authored footprint runs out of bounds at " .. x .. "," .. y)
  prefab.stamp_masked(island, defs, rox, roy, fp.rows, fp.legend)
  return rox, roy
end

function M.build(defs, spec)
  local h, w = #spec.map, #spec.map[1]
  local island = sub.new_island(w, h)
  island.name = spec.name
  island.seed = 0 -- authored, not rolled
  island.danger = spec.danger or 1
  prefab.stamp(island, defs, 0, 0, spec.map, spec.legend)

  local land, caches = 0, 0
  for ry, row in ipairs(spec.map) do
    for rx = 1, #row do
      local x, y = rx - 1, ry - 1
      local t = defs.terrain[sub.get(island, "terrain", x, y)]
      if not t.is_sky then land = land + 1 end
      local cell = spec.legend[row:sub(rx, rx)]
      if cell.f then
        local f = sub.feature_at(island, x, y)
        if f.def.loot_table then
          f.opened = false
          f.loot = {}
          for _, s in ipairs(cell.loot or {}) do
            f.loot[#f.loot + 1] = { id = s.id, n = s.n }
          end
          caches = caches + 1
        end
        if f.def.id == "trader" then
          -- an authored store counter: cell.loot is its stock
          f.stock = {}
          for _, s in ipairs(cell.loot or {}) do
            f.stock[#f.stock + 1] = { id = s.id, n = s.n }
          end
        end
        if f.def.latent then
          f.found = false
          local rox, roy = stamp_latent_footprint(island, defs, f.def, x, y)
          if rox then
            -- stamping replaced terrain; re-seat the rep entry with its
            -- origin so mask membership works
            f = { def = f.def, found = false, ox = rox, oy = roy }
            sub.set_feature(island, x, y, f)
          end
        end
        if f.def.id == "extract_beacon" then
          island.extract_idx = y * w + x
          island.start_x, island.start_y = x, y
        end
      end
    end
  end
  assert(island.extract_idx, spec.id .. ": no extract_beacon in map")
  island.land_count = land
  island.seen_count = 0 -- surveying it is still the job
  island.cache_count = caches

  island.creatures = {}
  for _, c in ipairs(spec.creatures or {}) do
    local def = defs.creature_by_id[c.def]
    island.creatures[#island.creatures + 1] = {
      def = def, x = c.x, y = c.y, hp = def.max_hp, mp = 0, state = "wander",
    }
  end

  island.npcs = {}
  for _, n in ipairs(spec.npcs or {}) do
    local stock = {}
    for _, s in ipairs(n.stock or {}) do
      stock[#stock + 1] = { id = s.id, n = s.n }
    end
    island.npcs[#island.npcs + 1] = {
      def = defs.npc_by_id[n.def], x = n.x, y = n.y, stock = stock,
    }
  end
  return island
end

return M
