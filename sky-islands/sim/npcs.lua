-- People on the map (SI-0005). Pure Lua. NPCs are SOLID (bump = blocked,
-- never an attack) and static; [T] talks to an adjacent one.
--
-- island.npcs = { { def, x, y, stock? }, ... } — hub-only for now
-- (SI-0026 is characters on mission islands). Fixed cast stands at
-- hubgen's authored spots; visitors roll per cycle onto dock berths,
-- deterministically from (master, "visitors:<cycle>").
local rng = require("util.rng")

local M = {}

function M.at(island, x, y)
  for _, n in ipairs(island.npcs or {}) do
    if n.x == x and n.y == y then return n end
  end
  return nil
end

function M.adjacent_to(island, x, y)
  local out = {}
  for _, n in ipairs(island.npcs or {}) do
    if math.max(math.abs(n.x - x), math.abs(n.y - y)) == 1 then
      out[#out + 1] = n
    end
  end
  return out
end

local function roll_stock(r, defs, def)
  local stock = {}
  for _, e in ipairs(def.stock_table or {}) do
    if r:chance(e.chance or 1) then
      stock[#stock + 1] = { id = e.item, n = r:int(e.min, e.max) }
    end
  end
  return stock
end

-- Rebuild the hub's population for the current cycle: the fixed cast at
-- their spots, plus visitors rolled onto berths. Same (master, cycle)
-- always seats the same people with the same goods.
function M.populate(S)
  local hub = S.world.islands.hub
  if not hub then return end
  local spots = require("world.hubgen").spots()
  local eco = S.defs.economy.npcs
  local r = rng.derive(S.master, "visitors:" .. S.cycle)
  local npcs = {}

  for _, d in ipairs(S.defs.npc_list) do
    if d.fixed and spots.fixed[d.id] then
      local s = spots.fixed[d.id]
      npcs[#npcs + 1] = { def = d, x = s.x, y = s.y }
    end
  end

  local active = S.market and S.market.event and S.market.event.id
  -- presence rolls first, one per visitor def, ALWAYS drawn (fixed draw
  -- count keeps the stream deterministic regardless of outcomes)
  local rolled = {}
  for _, d in ipairs(S.defs.npc_list) do
    if d.visitor then
      local chance = (d.visit_on_event and d.visit_on_event == active)
          and eco.event_visitor_chance or eco.berth_chance
      rolled[d.id] = r:chance(chance)
    end
  end
  -- seating: a debug-forced visitor gets the first berth, then rolled
  -- visitors in def order while berths remain
  local forced_id = S.debug and S.debug.force_visitor
  local queue = {}
  for _, d in ipairs(S.defs.npc_list) do
    if d.visitor and d.id == forced_id then queue[#queue + 1] = d end
  end
  for _, d in ipairs(S.defs.npc_list) do
    if d.visitor and rolled[d.id] and d.id ~= forced_id then
      queue[#queue + 1] = d
    end
  end
  for i, d in ipairs(queue) do
    if i > #spots.berths then break end
    local s = spots.berths[i]
    npcs[#npcs + 1] = { def = d, x = s.x, y = s.y,
      stock = roll_stock(r, S.defs, d) }
  end
  hub.npcs = npcs
end

return M
