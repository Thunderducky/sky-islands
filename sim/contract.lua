-- The payout math. Pure: settle(S) -> report table for the report screen.
-- Every knob comes from defs/economy.lua.
local M = {}

function M.settle(S)
  local eco, defs = S.defs.economy, S.defs
  local island, run, player = S.island, S.run, S.player

  local items_value = 0
  for _, it in ipairs(player.inv) do
    items_value = items_value + defs.item_by_id[it.id].value * it.n
  end
  local bounty = 0
  for _, f in ipairs(run.discovered) do
    bounty = bounty + (f.def.bounty or 0)
  end
  local findings = items_value + bounty

  local coverage = island.land_count > 0
      and island.seen_count / island.land_count or 0
  local payout = eco.scouting_fee + eco.proceeds_share * findings
  local bonus_mult = 0
  for _, tier in ipairs(eco.coverage_bonus) do
    if coverage >= tier.at then
      bonus_mult = tier.mult
      break
    end
  end
  local bonus = math.floor(payout * bonus_mult + 0.5)
  local total = math.floor(payout + 0.5) + bonus
  local to_debt = math.floor(total * eco.debt_garnish)
  local kept = total - to_debt
  local debt_after = math.max(0, run.debt - to_debt)

  return {
    items_value = items_value,
    caches_found = #run.discovered,
    caches_total = island.cache_count,
    bounty = bounty,
    findings = findings,
    coverage = coverage,
    fee = eco.scouting_fee,
    share = eco.proceeds_share,
    bonus = bonus,
    total = total,
    to_debt = to_debt,
    kept = kept,
    debt_before = run.debt,
    debt_after = debt_after,
    turns = S.clock.turn,
  }
end

return M
