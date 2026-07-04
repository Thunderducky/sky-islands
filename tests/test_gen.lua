local defs = require("defs").load()
local islandgen = require("world.islandgen")
local sub = require("world.substrate")
local G = require("util.grid")

local function walkable(island)
  return function(x, y)
    local t = defs.terrain[sub.get(island, "terrain", x, y)]
    return t.walkable or (t.door ~= nil)
  end
end

return {
  determinism = function(t)
    local a = islandgen.generate(42, defs)
    local b = islandgen.generate(42, defs)
    t.deep_eq(a.terrain, b.terrain, "same seed, same terrain")
    t.eq(a.cache_count, b.cache_count)
    t.eq(a.start_x, b.start_x)
    t.eq(a.start_y, b.start_y)
  end,

  many_seeds_valid = function(t)
    local eco = defs.economy.island
    for seed = 1, 40 do
      local isl = islandgen.generate(seed, defs)
      local area = isl.w * isl.h
      t.ok(isl.land_count >= area * eco.land_min_frac * 0.9,
        "seed " .. seed .. ": enough land")
      t.ok(isl.cache_count >= eco.caches_min,
        "seed " .. seed .. ": enough caches")
      t.ok(isl.extract_idx >= 0, "seed " .. seed .. ": beacon placed")

      -- start tile is walkable, beacon feature exists at start
      local f = sub.feature_at(isl, isl.start_x, isl.start_y)
      t.ok(f and f.def.id == "extract_beacon", "seed " .. seed .. ": start at beacon")

      -- every cache reachable from start
      local reach = G.flood(isl.w, isl.h, isl.start_x, isl.start_y, walkable(isl))
      local caches = 0
      for idx, feat in pairs(isl.features) do
        if feat.def.loot_table then
          caches = caches + 1
          t.ok(reach[idx], "seed " .. seed .. ": cache reachable")
          local x, y = G.xy(idx, isl.w)
          local terr = defs.terrain[sub.get(isl, "terrain", x, y)]
          t.ok(not terr.is_sky, "seed " .. seed .. ": no cache in the sky")
        end
      end
      t.eq(caches, isl.cache_count, "seed " .. seed .. ": cache_count honest")
    end
  end,

  coverage_denominator_positive = function(t)
    local isl = islandgen.generate(7, defs)
    t.ok(isl.land_count > 0)
    t.eq(isl.seen_count, 0, "nothing seen at gen time")
  end,
}
