local defs = require("defs").load()
local islandgen = require("world.islandgen")
local discovery = require("sim.discovery")
local sub = require("world.substrate")
local contract = require("sim.contract")
local flavor = require("flavor")
local rng = require("util.rng")

-- discovery/assay emit flavor; give the engine a mute sink
local function mute_flavor()
  flavor.init({
    pools = require("defs.flavor").events,
    rng = rng.derive(1, "test-flavor"),
    sink = function() end,
  })
end

local function latent_features(island)
  local out = {}
  for idx, f in pairs(island.features) do
    if f.def.latent then out[#out + 1] = { idx = idx, f = f } end
  end
  return out
end

-- a hand-built 5x5 all-grass island with one latent feature at (2,2)
local function tiny_island(feature_id)
  local island = sub.new_island(5, 5)
  for i = 1, 25 do
    island.terrain[i] = defs.tid["grass"]
    island.fog[i] = 0
  end
  island.land_count, island.seen_count, island.cache_count = 25, 0, 0
  sub.set_feature(island, 2, 2,
    { def = defs.feature_by_id[feature_id], found = false })
  return island
end

local function fake_state(island)
  return {
    defs = defs, island = island,
    player = { x = 2, y = 2 },
    run = { discovered = {}, notable = {} },
  }
end

return {
  placement_respects_tier_bounds = function(t)
    for danger = 1, 3 do
      local lt = defs.economy.danger.latent[danger]
      for seed = 1, 12 do
        local island = islandgen.generate(seed * 101, defs, danger)
        local n = #latent_features(island)
        t.ok(n >= 0 and n <= lt.max, string.format(
          "tier %d seed %d: %d latent within [0,%d]", danger, seed, n, lt.max))
      end
    end
  end,

  placement_is_deterministic = function(t)
    local a = latent_features(islandgen.generate(4242, defs, 3))
    local b = latent_features(islandgen.generate(4242, defs, 3))
    t.eq(#a, #b)
    for i = 1, #a do
      t.eq(a[i].idx, b[i].idx)
      t.eq(a[i].f.def.id, b[i].f.def.id)
    end
  end,

  sight_features_found_when_visible = function(t)
    mute_flavor()
    local island = tiny_island("freshwater_spring")
    local S = fake_state(island)
    discovery.scan_sight(S)
    t.eq(#S.run.notable, 0, "unseen: not discovered")
    island.fog[2 * 5 + 2 + 1] = 2 -- make its tile visible
    discovery.scan_sight(S)
    t.eq(#S.run.notable, 1, "visible: discovered")
    t.eq(S.run.notable[1].def.id, "freshwater_spring")
    discovery.scan_sight(S)
    t.eq(#S.run.notable, 1, "found once, not per scan")
  end,

  assay_features_need_the_work = function(t)
    mute_flavor()
    local island = tiny_island("ore_deposit")
    local S = fake_state(island)
    island.fog[2 * 5 + 2 + 1] = 2 -- visible...
    discovery.scan_sight(S)
    t.eq(#S.run.notable, 0, "...but sight is not enough for an assay feature")
    t.ok(discovery.assay(S), "standing on it, the work succeeds")
    t.eq(#S.run.notable, 1)
    t.eq(discovery.assay(S), nil, "second assay is a no-op")
    S.player.x = 0
    t.eq(discovery.assay(S), nil, "assay off-tile does nothing")
  end,

  scan_is_safe_off_mission = function(t)
    mute_flavor()
    local island = tiny_island("old_factory")
    local S = { defs = defs, island = island, player = { x = 2, y = 2 } }
    discovery.scan_sight(S) -- S.run is nil (hub life): must not crash
    t.eq(discovery.assay(S), nil)
  end,

  footprints_stamp_and_cover = function(t)
    mute_flavor()
    -- find a generated island carrying a footprint latent
    local hit
    for seed = 1, 80 do
      local island = islandgen.generate(seed * 7, defs, 3)
      for _, f in pairs(island.features) do
        if f.def.footprint then hit = { island = island, f = f } break end
      end
      if hit then break end
    end
    t.ok(hit, "a footprint latent generated within 80 hostile seeds")
    local island, f = hit.island, hit.f
    t.ok(f.ox ~= nil and f.oy ~= nil, "instance carries its origin")
    local fp = f.def.footprint
    for ry, row in ipairs(fp.rows) do
      for rx = 1, #row do
        local x, y = f.ox + rx - 1, f.oy + ry - 1
        if row:sub(rx, rx) ~= " " then
          t.eq(sub.feature_covering(island, x, y), f,
            "mask covers " .. x .. "," .. y)
          local terr = defs.terrain[sub.get(island, "terrain", x, y)]
          t.ok(terr.built, "stamped terrain at " .. x .. "," .. y)
        end
      end
    end
  end,

  footprint_sight_from_any_member_tile = function(t)
    mute_flavor()
    local island = tiny_island("freshwater_spring") -- rep entry at (2,2)...
    local f = sub.feature_at(island, 2, 2)
    f.ox, f.oy = 2, 2 -- ...whose 2x2 mask spans (2,2)-(3,3); rep is (3,2)
    -- (hand-built: entry sits at (2,2) for the test, mask math still holds)
    local S = fake_state(island)
    discovery.scan_sight(S)
    t.eq(#S.run.notable, 0, "nothing visible yet")
    island.fog[3 * 5 + 3 + 1] = 2 -- corner member tile (3,3), NOT the entry
    discovery.scan_sight(S)
    t.eq(#S.run.notable, 1, "sighted via a member tile")
  end,

  assay_from_inside_the_mask = function(t)
    mute_flavor()
    local island = tiny_island("ore_deposit") -- entry at (2,2)
    local f = sub.feature_at(island, 2, 2)
    f.ox, f.oy = 1, 1 -- 3x3 cross mask centered on (2,2)
    local S = fake_state(island)
    S.player.x, S.player.y = 2, 1 -- north arm of the cross, not the rep
    t.ok(discovery.assay(S), "assay works from inside the mask")
    t.eq(#S.run.notable, 1)
    S.player.x, S.player.y = 1, 1 -- corner: a SPACE cell, outside the mask
    t.eq(discovery.assay(S), nil, "corner outside the mask is not the feature")
  end,

  settle_pays_latent_and_keeps_cache_count_honest = function(t)
    local S = {
      defs = { economy = { debt_garnish = 0.5, sell_mult = 0.5,
        coverage_bonus = {} }, item_by_id = {} },
      island = { land_count = 100, seen_count = 0, cache_count = 3 },
      player = { inv = {} }, skiff = { hold = {} },
      mission = { fee = 100 },
      run = {
        discovered = { { def = { bounty = 15 } } }, -- one cache
        notable = { { def = { name = "ore deposit", bounty = 40 } },
                    { def = { name = "freshwater spring", bounty = 20 } } },
      },
      persist = { debt = 1000 }, clock = { turn = 10 },
    }
    local r = contract.settle(S)
    t.eq(r.caches_found, 1, "latent finds don't inflate cache count")
    t.eq(r.bounty, 15, "cache bounty stays caches-only")
    t.eq(r.notable_bounty, 60, "latent bounty itemized separately")
    t.eq(r.total, 175, "both flow into the contract total")
    t.deep_eq(r.notable, { "ore deposit", "freshwater spring" })
  end,
}
