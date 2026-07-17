local defs = require("defs").load()
local authored = require("world.authored")
local market = require("sim.market")
local sub = require("world.substrate")

local core_spec = defs.island_by_id["conglomerate_core"]
local out_spec = defs.island_by_id["patrol_outpost"]

return {
  destinations_build = function(t)
    local core = authored.build(defs, core_spec)
    t.ok(core.is_destination, "core is a destination")
    t.ok(core.has_authored_start, "arrival spot authored, not defaulted")
    local st = defs.terrain[core.terrain[core.start_y * core.w + core.start_x + 1]]
    t.ok(st.walkable, "you arrive on planks, not open sky")
    local beacons = 0
    for _, f in pairs(core.features) do
      if f.def.id == "extract_beacon" then beacons = beacons + 1 end
    end
    t.eq(beacons, 0, "no beacon: nothing to survey-submit")
    t.eq(core.lodging_fee, 30)
    t.ok(core.sells_passage, "the ticket out lives here")
    local land_seen = 0
    for i = 1, core.w * core.h do
      if core.fog[i] == 1 then land_seen = land_seen + 1 end
    end
    t.eq(land_seen, core.land_count, "civilized ground arrives remembered")

    local have = {}
    for _, n in ipairs(core.npcs) do have[n.def.id] = true end
    for _, id in ipairs({ "store_runner", "quest_broker", "travel_agent",
      "retired_trader", "core_tourist" }) do
      t.ok(have[id], "core seats " .. id)
    end

    local lodging, locker, counter, dock
    for _, f in pairs(core.features) do
      if f.def.id == "lodging" then lodging = f end
      if f.def.id == "locker" then locker = f end
      if f.def.id == "trader" then counter = f end
      if f.def.id == "skiff_dock" then dock = f end
    end
    t.ok(lodging, "rentable bunk exists")
    t.eq(locker, nil, "no lockers away from home: the hold is your luggage")
    t.ok(dock, "skiff dock: the hold travels with you")
    t.ok(counter and #counter.stock > 0, "the Core store is stocked")
  end,

  price_personalities = function(t)
    local core = authored.build(defs, core_spec)
    local outpost = authored.build(defs, out_spec)
    local Sc = { defs = defs, island = core }
    local So = { defs = defs, island = outpost }
    local lv = defs.economy.demand_levels

    -- the Core pays silly money for frontier goods...
    t.eq(market.pay_mult(Sc, defs.item_by_id.ward_shard), lv.critical.pay)
    t.eq(market.pay_mult(Sc, defs.item_by_id.medicinal_herbs), lv.high.pay)
    -- ...and sells manufactured cheap
    t.eq(market.charge_mult(Sc, defs.item_by_id.ration_pack), lv.glut.charge)
    -- the outpost wants hulls and food
    t.eq(market.pay_mult(So, defs.item_by_id.hull_plate), lv.critical.pay)
    t.eq(market.pay_mult(So, defs.item_by_id.ration_pack), lv.high.pay)
    -- no bias island = flat
    t.eq(market.pay_mult({ defs = defs, island = {} },
      defs.item_by_id.ward_shard), 1)
  end,

  bias_stacks_with_events = function(t)
    local outpost = authored.build(defs, out_spec)
    local S = { defs = defs, island = outpost,
      market = { event = { id = "patrol_repairs", cycles_left = 2 } } }
    local lv = defs.economy.demand_levels
    -- hull plate: event critical AND outpost-bias critical, multiplied
    t.eq(market.pay_mult(S, defs.item_by_id.hull_plate),
      lv.critical.pay * lv.critical.pay, "arbitrage compounds")
  end,

  rehydrate_restores_spec_statics = function(t)
    local core = authored.build(defs, core_spec)
    core.npcs, core.store_bias, core.lodging_fee = nil, nil, nil
    authored.rehydrate(core, defs, core_spec)
    t.ok(#core.npcs == 5, "people re-seated")
    t.ok(core.store_bias, "price personality re-attached")
    t.eq(core.lodging_fee, 30)
  end,
}
