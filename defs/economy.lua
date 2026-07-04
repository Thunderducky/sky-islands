-- Every tunable number in the contract loop lives here, not in code.
return {
  scouting_fee = 120,
  proceeds_share = 0.25, -- your cut of findings value
  debt_start = 2000,     -- the indenture
  debt_garnish = 0.60,   -- company's cut of every payout, applied to debt

  -- coverage -> bonus multiplier on the payout (thresholds, descending)
  coverage_bonus = {
    { at = 0.90, mult = 0.20 },
    { at = 0.75, mult = 0.10 },
    { at = 0.50, mult = 0.05 },
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
