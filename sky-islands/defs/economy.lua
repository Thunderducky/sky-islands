-- Every tunable number in the game loop lives here, not in code.
-- Company-town model: contract money = fee + bounties + coverage bonus
-- (garnished automatically); recovered GOODS stay yours, to sell at the
-- company store at company prices. The margin is the real garnish.
return {
  player_slots = 8, -- deliberately tight: the ferry loop IS the game
  skiff_slots = 20,
  ground_slots = 99, -- the ground is generous, not infinite
  stash_slots = 12,  -- lockbox under the bunk
  trader_slots = 60, -- deep reserves: the store absorbs what the sky coughs up

  fee_min = 100, fee_max = 160, -- mission offers roll in this range
  debt_start = 2000,
  debt_garnish = 0.60,   -- company's cut of every payout, applied to debt
  debt_payment_step = 100, -- voluntary payment per press at the store

  buy_mult = 1.5,  -- store sells at value x this
  sell_mult = 0.6, -- store buys at value x this

  -- Market events (defs/econ_events.lua) shift prices by DEMAND LEVEL,
  -- never raw multipliers — retuning the whole economy is this table.
  -- pay scales what the store gives you; charge scales what it asks.
  demand_levels = {
    glut     = { pay = 0.5, charge = 0.8 },
    low      = { pay = 0.8, charge = 0.9 },
    high     = { pay = 1.4, charge = 1.3 },
    critical = { pay = 1.9, charge = 1.6 },
  },
  econ_events = {
    -- rolled per quiet cycle; the cycle an event ends is always quiet
    -- (normal prices between stories are what make shortages legible)
    start_chance = 0.5,
  },

  -- People at the Tether (SI-0005): visitor rolls per cycle + how much
  -- worse trading with a person is than trading with the store.
  npcs = {
    berth_chance = 0.35,         -- per visitor, per cycle
    event_visitor_chance = 0.9,  -- when their tied econ event is active
    prices = { buy = 1.8, sell = 0.45 }, -- small wallets, steep spread
  },
  -- Veteran charters appear on the board once the indenture is cleared.
  veteran = { premium = 120 },

  -- Store restock, rebuilt every cycle from (master, "market:<cycle>").
  -- staples always appear; grab_bag entries are loot-table-shaped rolls.
  store = {
    staples = {
      { item = "ration_pack", min = 4, max = 8 },
      { item = "bandage", min = 2, max = 4 },
      { item = "preserves_jar", min = 2, max = 5 },
    },
    grab_bag = {
      { item = "salvage_cable", min = 1, max = 3, chance = 0.5 },
      { item = "tools_surveyor", min = 1, max = 1, chance = 0.3 },
      { item = "hull_plate", min = 1, max = 3, chance = 0.5 },
      { item = "sealant_tin", min = 1, max = 3, chance = 0.5 },
      { item = "insulated_wiring", min = 2, max = 5, chance = 0.5 },
      { item = "medicinal_herbs", min = 1, max = 4, chance = 0.4 },
      { item = "salvage_copper", min = 2, max = 6, chance = 0.4 },
      { item = "game_meat", min = 1, max = 3, chance = 0.3 },
      { item = "berries", min = 2, max = 6, chance = 0.3 },
    },
  },

  -- coverage -> bonus multiplier on the payout (thresholds, descending)
  coverage_bonus = {
    { at = 0.90, mult = 0.20 },
    { at = 0.75, mult = 0.10 },
    { at = 0.50, mult = 0.05 },
  },

  hunger = {
    per_turn = 1,
    peckish = 150, hungry = 300, starving = 500, -- thresholds
    collapse = 700, -- you drop; the company retrieves you, for a fee
  },
  rescue_fee = 250,  -- retrieval, billed straight onto the indenture
  medical_fee = 150, -- surcharge when they scrape you up injured

  player = { max_hp = 20, damage = { 2, 4 }, acc = 0.8 },
  regen_turns = 10, -- +1 hp per this many turns, unless starving
  sleep = { turns = 60, heal_every = 5 }, -- bed rest: 2x the natural rate

  danger = { -- contract danger tiers
    premium = { 0, 35, 80 }, -- added to the fee roll per tier
    misreport = 0.2,         -- chance the coordinator's report is off by one
    spawns = {
      { docile = { 2, 4 }, aggressive = { 0, 1 }, roaming_warden = false },
      { docile = { 2, 3 }, aggressive = { 2, 3 }, roaming_warden = false },
      { docile = { 1, 2 }, aggressive = { 3, 5 }, roaming_warden = true },
    },
    -- latent features per tier: hostile islands have better bones
    latent = {
      { min = 0, max = 1 },
      { min = 1, max = 1 },
      { min = 1, max = 2 },
    },
  },

  island = {
    w = 48, h = 48,
    land_min_frac = 0.35, land_max_frac = 0.65,
    buildings_min = 2, buildings_max = 4,
    caches_min = 3, caches_max = 5,
    ruin_cache_chance = 0.25, -- a cache upgrades to pre-Fracture strongbox
    fov_radius = 12,
  },
}
