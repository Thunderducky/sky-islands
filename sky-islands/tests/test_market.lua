local market = require("sim.market")
local defs = require("defs").load()

-- Minimal state around the real defs: market logic reads S.master,
-- S.cycle, S.market, S.defs and nothing else.
local function fake_state(master, cycle)
  return {
    master = master or 777,
    cycle = cycle or 1,
    market = market.init(),
    defs = defs,
  }
end

-- Drive N cycles; returns the sequence of started event ids.
local function run_cycles(S, n)
  local seq = {}
  for _ = 1, n do
    S.cycle = S.cycle + 1
    local news = market.advance(S)
    seq[#seq + 1] = news.started and news.started.id or "-"
  end
  return seq
end

return {
  defs_load_and_crossref = function(t)
    t.ok(#defs.econ_event_list >= 4, "event defs present")
    t.ok(defs.econ_event_by_id["patrol_repairs"] ~= nil, "by_id works")
    t.ok(defs.economy.demand_levels.critical.pay > 1, "demand levels wired")
  end,

  advance_is_deterministic = function(t)
    local a = run_cycles(fake_state(42, 1), 20)
    local b = run_cycles(fake_state(42, 1), 20)
    t.deep_eq(a, b)
  end,

  events_actually_fire = function(t)
    local S = fake_state(42, 1)
    local fired = {}
    for _ = 1, 40 do
      S.cycle = S.cycle + 1
      local news = market.advance(S)
      if news.started then fired[news.started.id] = true end
    end
    local n = 0
    for _ in pairs(fired) do n = n + 1 end
    t.ok(n >= 2, "several distinct events fire over 40 cycles (got " .. n .. ")")
  end,

  min_cycle_respected = function(t)
    for seed = 1, 30 do
      local S = fake_state(seed, 1)
      S.cycle = 2
      market.advance(S) -- earliest possible roll is cycle 2
      if S.market.event then
        local d = defs.econ_event_by_id[S.market.event.id]
        t.ok((d.min_cycle or 1) <= 2, d.id .. " fired before its min_cycle")
      end
    end
  end,

  duration_and_quiet_cycle = function(t)
    local S = fake_state(1, 1)
    -- force a known event with 1 cycle left; next advance must end it
    -- and start nothing (an ending cycle is always quiet)
    S.market.event = { id = "food_shortfall", cycles_left = 1 }
    S.cycle = 5
    local news = market.advance(S)
    t.eq(news.ended.id, "food_shortfall")
    t.eq(news.started, nil)
    t.eq(S.market.event, nil)
    t.eq(S.market.cooldowns.food_shortfall,
      defs.econ_event_by_id.food_shortfall.cooldown)
    t.eq(S.market.last_event, "food_shortfall")
  end,

  cooldown_blocks_reselection = function(t)
    -- while a cooldown is live the event must never start, whatever the seed
    for seed = 1, 30 do
      local S = fake_state(seed, 9)
      S.market.cooldowns = {
        patrol_repairs = 99, food_shortfall = 99,
        herb_overgrowth = 99, pirate_crash = 99,
      }
      local news = market.advance(S)
      t.eq(news.started, nil)
    end
  end,

  effect_matching_by_id_and_field = function(t)
    local S = fake_state(1, 5)
    S.market.event = { id = "patrol_repairs", cycles_left = 2 }
    t.eq(market.demand_of(S, defs.item_by_id.hull_plate), "critical")
    t.eq(market.demand_of(S, defs.item_by_id.bandage), "high", "has=heal matches bandage")
    t.eq(market.demand_of(S, defs.item_by_id.medicinal_herbs), "high", "has=heal matches herbs")
    t.eq(market.demand_of(S, defs.item_by_id.ration_pack), nil, "unmatched item untouched")
    t.eq(market.pay_mult(S, defs.item_by_id.hull_plate),
      defs.economy.demand_levels.critical.pay)
    t.eq(market.charge_mult(S, defs.item_by_id.ration_pack), 1)
  end,

  no_event_means_flat_mults = function(t)
    local S = fake_state(1, 5)
    t.eq(market.pay_mult(S, defs.item_by_id.hull_plate), 1)
    t.eq(market.charge_mult(S, defs.item_by_id.hull_plate), 1)
  end,

  build_stock_staples_present = function(t)
    local S = fake_state(11, 3)
    local stock = market.build_stock(S)
    local by_id = {}
    for _, s in ipairs(stock) do by_id[s.id] = (by_id[s.id] or 0) + s.n end
    for _, e in ipairs(defs.economy.store.staples) do
      t.ok((by_id[e.item] or 0) >= e.min, "staple present: " .. e.item)
    end
  end,

  build_stock_deterministic = function(t)
    t.deep_eq(market.build_stock(fake_state(11, 3)),
      market.build_stock(fake_state(11, 3)))
  end,

  restock_mult_zero_removes = function(t)
    -- an event zeroing a staple must remove it from stock entirely
    local S = fake_state(11, 3)
    local base = market.build_stock(S)
    local had = false
    for _, s in ipairs(base) do if s.id == "bandage" then had = true end end
    t.ok(had, "bandage stocked in quiet market")

    -- patch a synthetic event def in: total shortage of bandages
    local ev_def = {
      id = "test_shortage", name = "test", duration = { 1, 1 },
      effects = { { match = { id = "bandage" }, demand = "critical",
        restock_mult = 0 } },
      gossip = { "x" }, log = "x",
    }
    defs.econ_event_by_id.test_shortage = ev_def
    S.market.event = { id = "test_shortage", cycles_left = 1 }
    local shorted = market.build_stock(S)
    for _, s in ipairs(shorted) do
      t.ok(s.id ~= "bandage", "bandage absent under restock_mult 0")
    end
    defs.econ_event_by_id.test_shortage = nil
  end,

  restock_mult_does_not_shift_other_rolls = function(t)
    -- the rest of the stock must be identical with and without the event
    local base = market.build_stock(fake_state(11, 3))
    local S = fake_state(11, 3)
    defs.econ_event_by_id.test_shortage = {
      id = "test_shortage", name = "test", duration = { 1, 1 },
      effects = { { match = { id = "bandage" }, demand = "critical",
        restock_mult = 0 } },
      gossip = { "x" }, log = "x",
    }
    S.market.event = { id = "test_shortage", cycles_left = 1 }
    local shorted = market.build_stock(S)
    defs.econ_event_by_id.test_shortage = nil

    local function drop_bandage(stock)
      local out = {}
      for _, s in ipairs(stock) do
        if s.id ~= "bandage" then out[#out + 1] = s end
      end
      return out
    end
    t.deep_eq(drop_bandage(base), drop_bandage(shorted))
  end,

  add_stock_appends = function(t)
    local S = fake_state(11, 3)
    S.market.event = { id = "pirate_crash", cycles_left = 1 }
    local stock = market.build_stock(S)
    local cable = 0
    for _, s in ipairs(stock) do
      if s.id == "salvage_cable" then cable = cable + s.n end
    end
    -- pirate_crash add_stock guarantees 2-4 cable on top of any grab bag
    t.ok(cable >= 2, "crash loot cable present")
  end,
}
