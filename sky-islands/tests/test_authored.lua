local defs = require("defs").load()
local authored = require("world.authored")
local sub = require("world.substrate")
local flavor = require("flavor")
local rng = require("util.rng")

local function mute_flavor()
  flavor.init({
    pools = require("defs.flavor").events,
    rng = rng.derive(1, "test-flavor"),
    sink = function() end,
  })
end

return {
  specs_validate_at_load = function(t)
    t.ok(#defs.island_list >= 1, "at least one authored island")
    t.ok(defs.island_by_id["proving_grounds"] ~= nil)
  end,

  build_proving_grounds = function(t)
    mute_flavor()
    local spec = defs.island_by_id["proving_grounds"]
    local island = authored.build(defs, spec)
    t.eq(island.name, "Proving Grounds")
    t.ok(island.extract_idx, "beacon placed")
    t.eq(island.start_x + island.start_y * island.w, island.extract_idx,
      "start is the beacon")
    t.eq(island.cache_count, 2, "both caches counted")
    t.ok(island.land_count > 0)
    t.eq(island.seen_count, 0, "authored islands still need surveying")
    t.eq(#island.creatures, 2, "creatures placed")

    -- every latent def is present exactly once, unfound
    local latent = {}
    for _, f in pairs(island.features) do
      if f.def.latent then
        t.eq(f.found, false, f.def.id .. " starts unfound")
        latent[f.def.id] = (latent[f.def.id] or 0) + 1
      end
    end
    for _, id in ipairs({ "old_factory", "ore_deposit",
      "magical_inscription", "freshwater_spring", "grand_ruin" }) do
      t.eq(latent[id], 1, id .. " present once")
    end

    -- creatures stand on walkable ground
    for _, c in ipairs(island.creatures) do
      local terr = defs.terrain[sub.get(island, "terrain", c.x, c.y)]
      t.ok(terr.walkable, c.def.id .. " on walkable ground")
    end

    -- the whole cast is seated for conversation testing
    t.eq(#island.npcs, 5, "all five people on the dev island")
    local npcs = require("sim.npcs")
    for _, n in ipairs(island.npcs) do
      local terr = defs.terrain[sub.get(island, "terrain", n.x, n.y)]
      t.ok(terr.walkable, n.def.id .. " on walkable ground")
      t.eq(npcs.at(island, n.x, n.y), n, n.def.id .. " findable via at()")
      if n.def.trade then
        t.ok(#n.stock > 0, n.def.id .. " has authored stock")
      end
    end

    -- footprint latents got stamped: the ruin's authored char (31,12)
    -- seats a rep with an origin, and a wall tile of its mask maps back
    local ruin = sub.feature_at(island, 31, 12)
    t.eq(ruin.def.id, "grand_ruin")
    t.ok(ruin.ox ~= nil, "authored ruin carries its stamp origin")
    t.eq(sub.feature_covering(island, ruin.ox + 1, ruin.oy), ruin,
      "ruin wall tile maps back to the ruin")
    local wall = defs.terrain[sub.get(island, "terrain", ruin.ox + 1, ruin.oy)]
    t.eq(wall.id, "wall_stone", "masonry actually stamped")
  end,

  build_is_deterministic = function(t)
    local spec = defs.island_by_id["proving_grounds"]
    local a = authored.build(defs, spec)
    local b = authored.build(defs, spec)
    t.deep_eq(a.terrain, b.terrain)
    t.eq(a.cache_count, b.cache_count)
  end,

  loot_lands_in_the_cache = function(t)
    local island = authored.build(defs, defs.island_by_id["proving_grounds"])
    local full, empty = 0, 0
    for _, f in pairs(island.features) do
      if f.def.loot_table then
        if #f.loot > 0 then full = full + 1 else empty = empty + 1 end
      end
    end
    t.eq(full, 1, "one stocked cache")
    t.eq(empty, 1, "one empty cache (tests cache_empty flavor)")
  end,
}
