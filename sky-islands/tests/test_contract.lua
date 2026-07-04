local contract = require("sim.contract")

-- Company-town settle: money = fee + bounty + coverage bonus; goods are
-- never converted, only estimated.
local function fake_state(opts)
  return {
    defs = {
      economy = {
        debt_garnish = 0.5, sell_mult = 0.5,
        coverage_bonus = {
          { at = 0.90, mult = 0.20 },
          { at = 0.50, mult = 0.10 },
        },
      },
      item_by_id = { scrap = { value = 10 } },
    },
    island = { land_count = 100, seen_count = opts.seen, cache_count = 3 },
    player = { inv = opts.inv or {} },
    skiff = { hold = opts.hold or {} },
    mission = { fee = 100 },
    run = { discovered = opts.discovered or {} },
    persist = { debt = opts.debt or 1000 },
    clock = { turn = 55 },
  }
end

return {
  zero_everything = function(t)
    local S = fake_state({ seen = 0 })
    local r = contract.settle(S)
    t.eq(r.bounty, 0)
    t.eq(r.bonus, 0)
    t.eq(r.total, 100)
    t.eq(r.to_debt, 50)
    t.eq(r.kept, 50)
    t.eq(r.debt_after, 950)
    t.eq(r.goods_est, 0)
  end,

  full_run_hand_computed = function(t)
    local S = fake_state({
      seen = 95, -- 95% coverage -> 20% bonus tier
      discovered = { { def = { bounty = 15 } }, { def = { bounty = 30 } } },
      inv = { { id = "scrap", n = 4 } },  -- 40c of goods on your back
      hold = { { id = "scrap", n = 2 } }, -- 20c on the skiff
    })
    local r = contract.settle(S)
    -- payout = 100 + 45 = 145; bonus = round(145*0.2) = 29; total = 174
    -- to_debt = floor(174*0.5) = 87; kept = 87; debt 1000 -> 913
    -- goods_est = floor(60 * 0.5) = 30 (informational, NOT in the payout)
    t.eq(r.bounty, 45)
    t.eq(r.bonus, 29)
    t.eq(r.total, 174)
    t.eq(r.to_debt, 87)
    t.eq(r.kept, 87)
    t.eq(r.debt_after, 913)
    t.eq(r.goods_est, 30)
  end,

  goods_do_not_inflate_contract_money = function(t)
    local rich = fake_state({ seen = 0, inv = { { id = "scrap", n = 90 } } })
    local poor = fake_state({ seen = 0 })
    t.eq(contract.settle(rich).total, contract.settle(poor).total,
      "hauled goods must not change the contract payout")
  end,

  mid_coverage_tier = function(t)
    local S = fake_state({ seen = 60 })
    local r = contract.settle(S)
    t.eq(r.bonus, 10, "50% tier applies at 60% coverage")
  end,

  garnish_clamps_to_what_is_owed = function(t)
    -- total 100, garnish would be 50, but only 10 is owed:
    -- the surveyor keeps the other 90, not the void
    local S = fake_state({ seen = 0, debt = 10 })
    local r = contract.settle(S)
    t.eq(r.to_debt, 10)
    t.eq(r.kept, 90)
    t.eq(r.debt_after, 0)
  end,

  freed_surveyor_keeps_everything = function(t)
    local S = fake_state({ seen = 0, debt = 0 })
    local r = contract.settle(S)
    t.eq(r.to_debt, 0, "no garnish on a closed account")
    t.eq(r.kept, r.total)
    t.eq(r.debt_after, 0)
  end,
}
