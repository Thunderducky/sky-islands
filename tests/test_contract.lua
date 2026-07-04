local contract = require("sim.contract")

-- Minimal fake State exercising the math against hand-computed numbers.
local function fake_state(opts)
  return {
    defs = {
      economy = {
        scouting_fee = 100, proceeds_share = 0.25, debt_garnish = 0.5,
        coverage_bonus = {
          { at = 0.90, mult = 0.20 },
          { at = 0.50, mult = 0.10 },
        },
      },
      item_by_id = { scrap = { value = 10 } },
    },
    island = { land_count = 100, seen_count = opts.seen, cache_count = 3 },
    player = { inv = opts.inv or {} },
    run = { debt = opts.debt or 1000, discovered = opts.discovered or {} },
    clock = { turn = 55 },
  }
end

return {
  zero_everything = function(t)
    local S = fake_state({ seen = 0 })
    local r = contract.settle(S)
    -- payout = fee 100 + 0.25*0 = 100; no bonus; garnish 50
    t.eq(r.findings, 0)
    t.eq(r.bonus, 0)
    t.eq(r.total, 100)
    t.eq(r.to_debt, 50)
    t.eq(r.kept, 50)
    t.eq(r.debt_after, 950)
  end,

  full_run_hand_computed = function(t)
    local S = fake_state({
      seen = 95, -- 95% coverage -> 20% bonus tier
      inv = { { id = "scrap", n = 4 } }, -- 40c items
      discovered = { { def = { bounty = 15 } }, { def = { bounty = 30 } } }, -- 45c
    })
    local r = contract.settle(S)
    -- findings = 40+45 = 85; payout = 100 + 21.25 = 121.25
    -- bonus = round(121.25*0.2) = 24; total = round(121.25)+24 = 121+24 = 145
    -- to_debt = floor(145*0.5) = 72; kept = 73; debt 1000->928
    t.eq(r.findings, 85)
    t.eq(r.bonus, 24)
    t.eq(r.total, 145)
    t.eq(r.to_debt, 72)
    t.eq(r.kept, 73)
    t.eq(r.debt_after, 928)
  end,

  mid_coverage_tier = function(t)
    local S = fake_state({ seen = 60 })
    local r = contract.settle(S)
    t.eq(r.bonus, 10, "50% tier applies at 60% coverage")
  end,

  debt_never_negative = function(t)
    local S = fake_state({ seen = 0, debt = 10 })
    local r = contract.settle(S)
    t.eq(r.debt_after, 0)
  end,
}
