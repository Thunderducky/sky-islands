-- Every tunable number in the game loop lives here, not in code.
-- Company-town model: contract money = fee + bounties + coverage bonus
-- (garnished automatically); recovered GOODS stay yours, to sell at the
-- company store at company prices. The margin is the real garnish.
return {
  player_slots = 8, -- deliberately tight: the ferry loop IS the game
  skiff_slots = 20,
  ground_slots = 99, -- the ground is generous, not infinite
  stash_slots = 12,  -- lockbox under the bunk
  trader_slots = 14,

  fee_min = 100, fee_max = 160, -- mission offers roll in this range
  debt_start = 2000,
  debt_garnish = 0.60,   -- company's cut of every payout, applied to debt
  debt_payment_step = 100, -- voluntary payment per press at the store

  buy_mult = 1.5,  -- store sells at value x this
  sell_mult = 0.6, -- store buys at value x this

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
