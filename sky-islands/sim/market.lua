-- Market events at the company store. Pure Lua, no engine calls.
--
-- State shape (S.market):
--   event     nil, or { id, cycles_left, gossip_seen }
--   cooldowns { [event_id] = cycles until eligible again }
--   last_event most recently ENDED event id (never picked back-to-back)
--
-- All randomness derives from (S.master, tag): selection from
-- "econ-event:<cycle>", restock from "market:<cycle>". Same save, same
-- cycle -> same market, no matter what the player did in between.
--
-- advance() is deliberately the ONE place events are chosen — it is the
-- future "director" seam (see IDEAS.md): a tension-balancing or
-- personality director replaces this picker without touching event defs.
local rng = require("util.rng")

local M = {}

function M.init()
  return { event = nil, cooldowns = {}, last_event = nil }
end

function M.active_def(S)
  local ev = S.market and S.market.event
  return ev and S.defs.econ_event_by_id[ev.id] or nil
end

local function matches(eff, item_def)
  if eff.match.id then return item_def.id == eff.match.id end
  return item_def[eff.match.has] ~= nil
end

-- First matching effect of the active event, or nil.
function M.effect_for(S, item_def)
  local def = M.active_def(S)
  if not def then return nil end
  for _, eff in ipairs(def.effects or {}) do
    if matches(eff, item_def) then return eff end
  end
  return nil
end

-- Demand level name for an item under the active event ("high"...), or nil.
function M.demand_of(S, item_def)
  local eff = M.effect_for(S, item_def)
  return eff and eff.demand or nil
end

local function level_of(S, item_def)
  local d = M.demand_of(S, item_def)
  return d and S.defs.economy.demand_levels[d] or nil
end

-- Static per-island price personality (SI-0006a): island.store_bias is
-- a list of { match, demand } attached by world/authored.lua from the
-- island spec. Same matching rules as event effects; stacks
-- MULTIPLICATIVELY with the active event (arbitrage compounds).
local function bias_level(S, item_def)
  local bias = S.island and S.island.store_bias
  if not bias then return nil end
  for _, eff in ipairs(bias) do
    if matches(eff, item_def) then
      return S.defs.economy.demand_levels[eff.demand]
    end
  end
  return nil
end

-- Static bias demand name for an item on this island (UI markers).
function M.bias_of(S, item_def)
  local bias = S.island and S.island.store_bias
  if not bias then return nil end
  for _, eff in ipairs(bias) do
    if matches(eff, item_def) then return eff.demand end
  end
  return nil
end

-- Multiplier on what the store PAYS the player for item_def.
function M.pay_mult(S, item_def)
  local lvl, b = level_of(S, item_def), bias_level(S, item_def)
  return (lvl and lvl.pay or 1) * (b and b.pay or 1)
end

-- Multiplier on what the store CHARGES the player for item_def.
function M.charge_mult(S, item_def)
  local lvl, b = level_of(S, item_def), bias_level(S, item_def)
  return (lvl and lvl.charge or 1) * (b and b.charge or 1)
end

-- Advance the market one cycle. Call exactly once per cycle increment,
-- AFTER S.cycle has been bumped. Returns { started = def|nil,
-- ended = def|nil } so the caller can narrate; this module never logs.
function M.advance(S)
  local mkt, defs, eco = S.market, S.defs, S.defs.economy
  local out = {}

  -- tick cooldowns (decrement is order-independent; pairs is safe here)
  for id, n in pairs(mkt.cooldowns) do
    mkt.cooldowns[id] = n > 1 and n - 1 or nil
  end

  if mkt.event then
    mkt.event.cycles_left = mkt.event.cycles_left - 1
    if mkt.event.cycles_left <= 0 then
      local def = defs.econ_event_by_id[mkt.event.id]
      if def then mkt.cooldowns[def.id] = def.cooldown or 3 end
      mkt.last_event = mkt.event.id
      mkt.event = nil
      out.ended = def
      return out -- the cycle an event ends is always quiet
    end
    return out -- still running
  end

  local r = rng.derive(S.master, "econ-event:" .. S.cycle)
  if not r:chance(eco.econ_events.start_chance) then return out end

  -- eligible pool: indexed iteration over the def list (determinism)
  local pool, total = {}, 0
  for _, d in ipairs(defs.econ_event_list) do
    if not mkt.cooldowns[d.id]
        and (not d.min_cycle or S.cycle >= d.min_cycle)
        and d.id ~= mkt.last_event then
      pool[#pool + 1] = d
      total = total + (d.weight or 1)
    end
  end
  if total == 0 then return out end

  local roll = r:int(1, total)
  local chosen
  for _, d in ipairs(pool) do
    roll = roll - (d.weight or 1)
    if roll <= 0 then chosen = d break end
  end
  mkt.event = {
    id = chosen.id,
    cycles_left = r:int(chosen.duration[1], chosen.duration[2]),
    gossip_seen = false,
  }
  out.started = chosen
  return out
end

-- Build the store's stock for the current cycle: staples + grab bag,
-- scaled by the active event's restock_mult, plus its add_stock. Pure
-- function of (S.master, S.cycle, S.market.event).
function M.build_stock(S)
  local eco, defs = S.defs.economy, S.defs
  local r = rng.derive(S.master, "market:" .. S.cycle)
  local stock = {}

  local function scaled(item_id, n)
    local eff = M.effect_for(S, defs.item_by_id[item_id])
    if eff and eff.restock_mult then n = math.floor(n * eff.restock_mult) end
    if n > 0 then stock[#stock + 1] = { id = item_id, n = n } end
  end

  for _, e in ipairs(eco.store.staples) do
    scaled(e.item, r:int(e.min, e.max))
  end
  for _, e in ipairs(eco.store.grab_bag) do
    -- chance and count are rolled unconditionally so the draw sequence
    -- (and thus later entries) never depends on the active event
    local hit = r:chance(e.chance or 1)
    local n = r:int(e.min, e.max)
    if hit then scaled(e.item, n) end
  end

  local ev = M.active_def(S)
  if ev and ev.add_stock then
    for _, e in ipairs(ev.add_stock) do
      if r:chance(e.chance or 1) then
        local n = r:int(e.min, e.max)
        if n > 0 then stock[#stock + 1] = { id = e.item, n = n } end
      end
    end
  end
  return stock
end

return M
