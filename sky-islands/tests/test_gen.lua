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

  vegetation_traversable_but_blinding = function(t)
    for _, id in ipairs({ "tree", "bush" }) do
      local d = defs.terrain_by_id[id]
      t.ok(d.walkable, id .. " is traversable")
      t.ok(d.opaque, id .. " blocks FOV")
    end
    -- beacon never spawns inside vegetation
    for seed = 1, 40 do
      local isl = islandgen.generate(seed, defs)
      local terr = defs.terrain[sub.get(isl, "terrain", isl.start_x, isl.start_y)]
      t.ok(not terr.opaque, "seed " .. seed .. ": start tile has clear sightlines")
    end
  end,

  forage_exists_and_sits_on_bushes = function(t)
    local total = 0
    for seed = 1, 40 do
      local isl = islandgen.generate(seed, defs)
      for idx, f in pairs(isl.features) do
        if f.def.take_only then
          total = total + 1
          local x, y = G.xy(idx, isl.w)
          local terr = defs.terrain[sub.get(isl, "terrain", x, y)]
          t.eq(terr.id, "bush", "forage grows on bushes, not walls")
          t.ok(#f.loot > 0, "forage feature carries food")
        end
      end
    end
    t.ok(total > 20, "berries are actually findable (got " .. total .. ")")
  end,

  creatures_spawn_sanely = function(t)
    local wardens_needed, wardens_found = 0, 0
    for seed = 1, 40 do
      local danger = (seed % 3) + 1
      local isl = islandgen.generate(seed, defs, danger)
      t.ok(#isl.creatures > 0, "seed " .. seed .. ": something lives here")
      for _, c in ipairs(isl.creatures) do
        local terr = defs.terrain[sub.get(isl, "terrain", c.x, c.y)]
        t.ok(terr.walkable, "seed " .. seed .. ": creature on walkable ground")
        t.eq(c.hp, c.def.max_hp)
      end
      -- every ruin cache should have a warden within 2 tiles
      for idx, f in pairs(isl.features) do
        if f.def.id == "cache_ruin" then
          wardens_needed = wardens_needed + 1
          local fx, fy = G.xy(idx, isl.w)
          for _, c in ipairs(isl.creatures) do
            if c.def.id == "shard_warden"
                and math.max(math.abs(c.x - fx), math.abs(c.y - fy)) <= 2 then
              wardens_found = wardens_found + 1
              break
            end
          end
        end
      end
    end
    t.eq(wardens_found, wardens_needed, "every strongbox has its warden")
  end,

  danger_is_part_of_the_seed = function(t)
    local a = islandgen.generate(77, defs, 3)
    local b = islandgen.generate(77, defs, 3)
    t.deep_eq(a.terrain, b.terrain)
    t.eq(#a.creatures, #b.creatures)
    for i, c in ipairs(a.creatures) do
      t.eq(c.def.id, b.creatures[i].def.id)
      t.ok(c.x == b.creatures[i].x and c.y == b.creatures[i].y)
    end
  end,

  coverage_denominator_positive = function(t)
    local isl = islandgen.generate(7, defs)
    t.ok(isl.land_count > 0)
    t.eq(isl.seen_count, 0, "nothing seen at gen time")
  end,
}
