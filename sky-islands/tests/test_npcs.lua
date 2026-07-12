local defs = require("defs").load()
local npcs = require("sim.npcs")
local hubgen = require("world.hubgen")
local market = require("sim.market")
local flavor = require("flavor")
local rng = require("util.rng")

local function mute_flavor()
  flavor.init({
    pools = require("defs.flavor").events,
    rng = rng.derive(1, "test-flavor"),
    sink = function() end,
  })
end

local function fake_state(master, cycle)
  mute_flavor()
  local S = {
    master = master or 99, cycle = cycle or 1,
    defs = defs,
    market = market.init(),
    world = { islands = {} },
  }
  S.world.islands.hub = hubgen.build(defs)
  return S
end

local function by_id(hub)
  local out = {}
  for _, n in ipairs(hub.npcs or {}) do out[n.def.id] = n end
  return out
end

return {
  hub_map_has_the_spots = function(t)
    local spots = hubgen.spots()
    t.ok(spots.fixed.store_runner, "store runner spot authored")
    t.ok(spots.fixed.quest_broker, "quest broker spot authored")
    t.ok(#spots.berths >= 2, "at least two visitor berths")
  end,

  fixed_cast_always_seated = function(t)
    for seed = 1, 10 do
      local S = fake_state(seed, 1)
      npcs.populate(S)
      local have = by_id(S.world.islands.hub)
      t.ok(have.store_runner, "store runner present (seed " .. seed .. ")")
      t.ok(have.quest_broker, "quest broker present")
    end
  end,

  population_is_deterministic = function(t)
    local a = fake_state(42, 3)
    local b = fake_state(42, 3)
    npcs.populate(a)
    npcs.populate(b)
    local an, bn = a.world.islands.hub.npcs, b.world.islands.hub.npcs
    t.eq(#an, #bn)
    for i = 1, #an do
      t.eq(an[i].def.id, bn[i].def.id)
      t.eq(an[i].x, bn[i].x)
      t.deep_eq(an[i].stock or {}, bn[i].stock or {})
    end
  end,

  event_ties_pull_their_visitor = function(t)
    -- with patrol_repairs active the quartermaster shows up in nearly
    -- every cycle; count over many cycles at 0.9 vs base 0.35
    local with, without = 0, 0
    for cycle = 1, 30 do
      local S = fake_state(7, cycle)
      S.market.event = { id = "patrol_repairs", cycles_left = 2 }
      npcs.populate(S)
      if by_id(S.world.islands.hub).quartermaster then with = with + 1 end

      local S2 = fake_state(7, cycle)
      npcs.populate(S2)
      if by_id(S2.world.islands.hub).quartermaster then without = without + 1 end
    end
    t.ok(with > without, "event presence beats base rate (" ..
      with .. " vs " .. without .. ")")
    t.ok(with >= 24, "0.9 chance lands most cycles (got " .. with .. ")")
  end,

  force_visitor_flag = function(t)
    local S = fake_state(5, 1)
    S.debug = { force_visitor = "wildlife_researcher" }
    npcs.populate(S)
    t.ok(by_id(S.world.islands.hub).wildlife_researcher,
      "forced visitor is seated")
  end,

  at_and_adjacent = function(t)
    local S = fake_state(11, 1)
    npcs.populate(S)
    local hub = S.world.islands.hub
    local runner = by_id(hub).store_runner
    t.eq(npcs.at(hub, runner.x, runner.y), runner)
    t.eq(npcs.at(hub, runner.x + 3, runner.y), nil)
    local near = npcs.adjacent_to(hub, runner.x + 1, runner.y)
    local found = false
    for _, n in ipairs(near) do if n == runner then found = true end end
    t.ok(found, "runner adjacent from one tile east")
    t.eq(#npcs.adjacent_to(hub, runner.x, runner.y), 0,
      "standing ON someone is not adjacency (and cannot happen anyway)")
  end,

  traders_carry_small_stock = function(t)
    -- roll many cycles; whenever a trading visitor shows, their stock
    -- fits their slots and every item id is real
    for cycle = 1, 20 do
      local S = fake_state(13, cycle)
      npcs.populate(S)
      for _, n in ipairs(S.world.islands.hub.npcs) do
        if n.def.visitor and n.def.trade then
          t.ok(#(n.stock or {}) <= n.def.slots, n.def.id .. " stock fits slots")
          for _, s in ipairs(n.stock or {}) do
            t.ok(defs.item_by_id[s.id], "real item: " .. tostring(s.id))
          end
        end
      end
    end
  end,
}
