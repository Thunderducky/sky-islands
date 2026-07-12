-- The hunger clock. Hunger counts up per turn; thresholds name the states.
-- v1 is pressure-by-information (warnings, a meter); mechanical penalties
-- arrive with combat/health, when there's something to penalize.
local flavor = require("flavor")
local P = require("palette")

local M = {}

local ORDER = { full = 0, peckish = 1, hungry = 2, starving = 3 }

M.COLORS = {
  full = P.GREEN + 5,
  peckish = P.GOLD + 4,
  hungry = P.RED + 4,
  starving = P.RED + 5,
}

function M.state(hunger, eco)
  local h = eco.hunger
  if hunger >= h.starving then return "starving" end
  if hunger >= h.hungry then return "hungry" end
  if hunger >= h.peckish then return "peckish" end
  return "full"
end

-- Called once per game turn. Emits a flavor line when the state worsens.
-- Returns true when the player collapses (hunger reaches the collapse
-- point) — the caller decides what a collapse means; this module doesn't
-- touch game flow.
function M.tick(S)
  local eco = S.defs.economy
  local clock_off = S.debug and S.debug.no_hunger -- debug: frozen clock
  if not clock_off then
    S.player.hunger = (S.player.hunger or 0) + eco.hunger.per_turn
    local state = M.state(S.player.hunger, eco)
    local prev = S.player.hunger_state or "full"
    if ORDER[state] > ORDER[prev] then
      flavor.emit("hunger_" .. state, {})
    end
    S.player.hunger_state = state
  end

  -- passive regen rides the same tick: slow, and starving stops it
  local pl = eco.player
  if S.player.hp and S.player.hp < pl.max_hp
      and (S.player.hunger_state or "full") ~= "starving"
      and S.clock.turn % eco.regen_turns == 0 then
    S.player.hp = S.player.hp + 1
  end

  return not clock_off and S.player.hunger >= eco.hunger.collapse
end

-- Use one unit of inv[idx]: nutrition eats, heal bandages. Returns true
-- if consumed.
function M.use(S, idx)
  local stack = S.player.inv[idx]
  if not stack then return false end
  local def = S.defs.item_by_id[stack.id]
  if not def.nutrition and not def.heal then
    flavor.emit("not_usable", { item = def.name })
    return false
  end
  if def.heal and not def.nutrition then
    local pl = S.defs.economy.player
    if (S.player.hp or pl.max_hp) >= pl.max_hp then
      flavor.emit("not_hurt", {})
      return false
    end
  end
  if def.nutrition then
    S.player.hunger = math.max(0, (S.player.hunger or 0) - def.nutrition)
    S.player.hunger_state = M.state(S.player.hunger, S.defs.economy)
    flavor.emit("eat", { item = def.name })
  end
  if def.heal and S.player.hp then
    local pl = S.defs.economy.player
    S.player.hp = math.min(pl.max_hp, S.player.hp + def.heal)
    flavor.emit("bandage", { item = def.name })
  end
  stack.n = stack.n - 1
  if stack.n == 0 then table.remove(S.player.inv, idx) end
  return true
end

M.eat = M.use -- back-compat alias

return M
