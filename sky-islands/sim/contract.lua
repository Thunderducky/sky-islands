-- Company-town settle: contract money = fee + cache bounties + coverage
-- bonus, garnished automatically. Recovered goods are NOT converted —
-- they stay in your pack and skiff hold, to sell at the store. Pure:
-- settle(State) -> report table. Knobs in defs/economy.lua.
local inv = require("sim.inventory")

local M = {}

function M.settle(S)
  local eco, defs = S.defs.economy, S.defs
  local island, run = S.island, S.run

  local bounty = 0
  for _, f in ipairs(run.discovered) do
    bounty = bounty + (f.def.bounty or 0)
  end
  -- latent features: separate list AND separate money, so the report
  -- can itemize honestly (caches_found and cache bounties stay caches)
  local notable, notable_bounty = {}, 0
  for _, f in ipairs(run.notable or {}) do
    notable_bounty = notable_bounty + (f.def.bounty or 0)
    notable[#notable + 1] = f.def.short or f.def.name
  end

  local coverage = island.land_count > 0
      and island.seen_count / island.land_count or 0
  local payout = S.mission.fee + bounty + notable_bounty
  local bonus_mult = 0
  for _, tier in ipairs(eco.coverage_bonus) do
    if coverage >= tier.at then
      bonus_mult = tier.mult
      break
    end
  end
  local bonus = math.floor(payout * bonus_mult + 0.5)
  local total = payout + bonus
  -- garnish never exceeds what's owed: a freed surveyor keeps everything
  local to_debt = math.min(math.floor(total * eco.debt_garnish), S.persist.debt)
  local kept = total - to_debt
  local debt_after = S.persist.debt - to_debt

  -- informational: what the store would pay for everything you're hauling
  local goods = inv.value(S.player.inv, defs.item_by_id)
      + inv.value(S.skiff.hold, defs.item_by_id)
  local goods_est = math.floor(goods * eco.sell_mult)

  return {
    caches_found = #run.discovered,
    caches_total = island.cache_count,
    notable = notable,
    notable_bounty = notable_bounty,
    bounty = bounty,
    coverage = coverage,
    fee = S.mission.fee,
    bonus = bonus,
    total = total,
    to_debt = to_debt,
    kept = kept,
    debt_before = S.persist.debt,
    debt_after = debt_after,
    goods_est = goods_est,
    turns = S.clock.turn,
  }
end

return M
