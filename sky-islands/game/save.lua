-- Save/load. v1 is full snapshots: islands are small and snapshot code
-- can't have replay bugs. snapshot()/restore() are pure State<->table
-- (headless-testable); write()/read() are thin usagi.save/load wrappers.
--
-- Two invariants:
-- - version field from day one (migrations are inevitable)
-- - terrain ints are load-order-dependent, so the save carries its own
--   id->int map and load remaps (adding a def must not scramble old saves)
-- Sparse int-keyed tables (features, piles) serialize as arrays of
-- records — JSON-side encoders dislike sparse integer keys.
local M = {}

-- Snapshots must own their data: sharing references with live state means
-- later mutations silently edit the "snapshot" (fine for immediate disk
-- writes, fatal for in-memory restore).
local function copy_array(a, n)
  local out = {}
  for i = 1, n do out[i] = a[i] end
  return out
end

local function copy_stacks(list)
  local out = {}
  for i, s in ipairs(list) do out[i] = { id = s.id, n = s.n } end
  return out
end

local function ser_island(island)
  local out = {
    w = island.w, h = island.h, seed = island.seed, name = island.name,
    is_hub = island.is_hub or false,
    start_x = island.start_x, start_y = island.start_y,
    extract_idx = island.extract_idx,
    land_count = island.land_count, seen_count = island.seen_count,
    cache_count = island.cache_count, danger = island.danger,
    terrain = copy_array(island.terrain, island.w * island.h),
    fog = copy_array(island.fog, island.w * island.h),
    features = {}, piles = {}, creatures = {},
  }
  for _, c in ipairs(island.creatures or {}) do
    out.creatures[#out.creatures + 1] = {
      def = c.def.id, x = c.x, y = c.y, hp = c.hp, mp = c.mp,
      state = c.state, last_x = c.last_x, last_y = c.last_y,
    }
  end
  for idx, f in pairs(island.features) do
    local rec = { idx = idx, def = f.def.id }
    for k, v in pairs(f) do
      if k ~= "def" then
        -- feature tables are stack lists (loot/stash/stock); scalars pass through
        rec[k] = type(v) == "table" and copy_stacks(v) or v
      end
    end
    out.features[#out.features + 1] = rec
  end
  for idx, pile in pairs(island.item_piles) do
    if #pile > 0 then
      out.piles[#out.piles + 1] = { idx = idx, items = copy_stacks(pile) }
    end
  end
  return out
end

local function deser_island(rec, defs, remap)
  local sub = require("world.substrate")
  local island = sub.new_island(rec.w, rec.h)
  island.seed, island.name, island.is_hub = rec.seed, rec.name, rec.is_hub
  island.start_x, island.start_y = rec.start_x, rec.start_y
  island.extract_idx = rec.extract_idx
  island.land_count, island.seen_count = rec.land_count, rec.seen_count
  island.cache_count = rec.cache_count
  for i = 1, rec.w * rec.h do
    island.terrain[i] = remap[rec.terrain[i]]
    island.fog[i] = rec.fog[i]
  end
  for _, frec in ipairs(rec.features) do
    local f = { def = assert(defs.feature_by_id[frec.def],
      "save: unknown feature def " .. tostring(frec.def)) }
    for k, v in pairs(frec) do
      if k ~= "idx" and k ~= "def" then
        f[k] = type(v) == "table" and copy_stacks(v) or v
      end
    end
    island.features[frec.idx] = f
  end
  for _, prec in ipairs(rec.piles) do
    island.item_piles[prec.idx] = copy_stacks(prec.items)
  end
  island.danger = rec.danger
  island.creatures = {}
  for _, crec in ipairs(rec.creatures or {}) do
    island.creatures[#island.creatures + 1] = {
      def = assert(defs.creature_by_id[crec.def],
        "save: unknown creature def " .. tostring(crec.def)),
      x = crec.x, y = crec.y, hp = crec.hp, mp = crec.mp or 0,
      state = crec.state or "wander", last_x = crec.last_x, last_y = crec.last_y,
    }
  end
  return island
end

function M.snapshot()
  local islands = {}
  for id, island in pairs(State.world.islands) do
    islands[id] = ser_island(island)
  end
  local tid = {}
  for id, int in pairs(State.defs.tid) do tid[id] = int end
  local mkt = State.market or { cooldowns = {} }
  local cooldowns = {}
  for id, n in pairs(mkt.cooldowns) do cooldowns[id] = n end
  local lodging = {}
  for k in pairs(State.lodging or {}) do lodging[#lodging + 1] = k end
  return {
    version = 1,
    master = State.master,
    cycle = State.cycle,
    base = State.base or "hub",
    lodging = lodging,
    market = {
      event = mkt.event and { id = mkt.event.id,
        cycles_left = mkt.event.cycles_left,
        gossip_seen = mkt.event.gossip_seen or false } or nil,
      last_event = mkt.last_event,
      cooldowns = cooldowns,
    },
    persist = { debt = State.persist.debt, credits = State.persist.credits },
    skiff = { hold = copy_stacks(State.skiff.hold) },
    clock = { turn = State.clock.turn },
    player = { x = State.player.x, y = State.player.y,
      inv = copy_stacks(State.player.inv),
      hunger = State.player.hunger or 0,
      hp = State.player.hp },
    world = { current = State.world.current, islands = islands },
    tid = tid, -- id->int map as saved; load remaps
  }
end

function M.restore(snap)
  assert(snap.version == 1, "save version " .. tostring(snap.version) .. " unsupported")
  local defs = State.defs
  -- old int -> current int, via the saved id map
  local remap = {}
  for id, old_int in pairs(snap.tid) do
    remap[old_int] = assert(defs.tid[id], "save: unknown terrain def " .. id)
  end

  State.master = snap.master
  State.cycle = snap.cycle
  -- market state: older saves lack it -> quiet market (rule: new fields
  -- default on load). An event whose def no longer exists is dropped.
  local mk = snap.market or {}
  State.market = { event = nil, last_event = mk.last_event, cooldowns = {} }
  for id, n in pairs(mk.cooldowns or {}) do
    if defs.econ_event_by_id[id] then State.market.cooldowns[id] = n end
  end
  if mk.event and defs.econ_event_by_id[mk.event.id] then
    State.market.event = { id = mk.event.id,
      cycles_left = mk.event.cycles_left,
      gossip_seen = mk.event.gossip_seen or false }
  end
  State.persist = { debt = snap.persist.debt, credits = snap.persist.credits }
  State.skiff = { hold = copy_stacks(snap.skiff.hold) }
  State.clock = { turn = snap.clock.turn }
  State.player = { x = snap.player.x, y = snap.player.y,
    inv = copy_stacks(snap.player.inv),
    hunger = snap.player.hunger or 0, -- older saves lack it: default sated
    hp = snap.player.hp or defs.economy.player.max_hp }
  State.player.hunger_state =
      require("sim.needs").state(State.player.hunger, State.defs.economy)
  State.world = { current = snap.world.current, islands = {} }
  for id, rec in pairs(snap.world.islands) do
    State.world.islands[id] = deser_island(rec, defs, remap)
  end
  State.island = assert(State.world.islands[State.world.current])
  State.mission = nil -- saves only happen at the hub
  State.run = nil
  State.base = snap.base or "hub"
  State.lodging = {}
  for _, k in ipairs(snap.lodging or {}) do State.lodging[k] = true end
  -- persistent authored islands: re-attach spec statics (npcs, price
  -- bias, lodging fees) that deliberately don't serialize
  local authored = require("world.authored")
  for id, island in pairs(State.world.islands) do
    local spec_id = id:match("^isle:authored:(.+)$")
    local spec = spec_id and defs.island_by_id[spec_id]
    if spec then authored.rehydrate(island, defs, spec) end
  end

  -- hub migration: the Tether's map evolves between versions (lockers,
  -- people spots, piers). Rebuild it fresh and transplant the mutable
  -- bits — trader stock, and the stash wherever an old save kept it.
  local old_hub = State.world.islands.hub
  if old_hub then
    local fresh = require("world.hubgen").build(defs)
    local old_stash, old_stock
    for _, f in pairs(old_hub.features) do
      if f.stash and #f.stash > 0 then old_stash = f.stash end
      if f.def.id == "trader" and f.stock then old_stock = f.stock end
    end
    for _, f in pairs(fresh.features) do
      if f.def.id == "locker" and old_stash then f.stash = old_stash end
      if f.def.id == "trader" and old_stock then f.stock = old_stock end
    end
    State.world.islands.hub = fresh
    if State.world.current == "hub" then State.island = fresh end
  end
end

function M.write()
  assert(State.world.current == "hub", "saving is a hub-only affair")
  if usagi and usagi.save then usagi.save(M.snapshot()) end
end

function M.read()
  if usagi and usagi.load then
    local snap = usagi.load()
    if snap and snap.version then return snap end
  end
  return nil
end

return M
