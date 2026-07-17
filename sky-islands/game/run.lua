-- Game flow: new game -> hub; coordinator -> mission island; beacon ->
-- report -> hub (autosave). All randomness derives from (State.master,
-- domain tag): offers from "missions:<cycle>", store stock from
-- "market:<cycle>", islands from their own seed. Interacting with one
-- system can never perturb another.
local islandgen = require("world.islandgen")
local hubgen = require("world.hubgen")
local fov = require("world.fov")
local rng = require("util.rng")
local log = require("ui.log")
local flavor = require("flavor")
local save = require("game.save")

local M = {}

local function init_session()
  State.log = log.new(60)
  flavor.init({
    pools = require("defs.flavor").events,
    rng = rng.derive(State.master, "flavor"),
    sink = function(text, color) State.log:push(text, color) end,
  })
end

local function enter_island(island, id, x, y)
  State.world.islands[id] = island
  State.world.current = id
  State.island = island
  State.player.x = x or island.start_x
  State.player.y = y or island.start_y
  if State.debug and State.debug.reveal_fog then
    -- debug: pre-remember every tile, keeping coverage math honest
    for i = 1, island.w * island.h do
      if island.fog[i] == 0
          and not State.defs.terrain[island.terrain[i]].is_sky then
        island.fog[i] = 1
        island.seen_count = island.seen_count + 1
      end
    end
  end
  fov.update(island, State.defs, State.player.x, State.player.y,
    State.defs.economy.island.fov_radius)
  require("sim.discovery").scan_sight(State) -- no-op off-mission
end

local market = require("sim.market")

local function restock_trader()
  local hub = State.world.islands.hub
  for _, f in pairs(hub.features) do
    if f.def.id == "trader" and f.stock then
      f.stock = market.build_stock(State)
    end
  end
end

-- One market tick per cycle increment: advance events, then narrate.
local function turn_market()
  local news = market.advance(State)
  if news.ended then
    flavor.emit("market_settled", { name = news.ended.name })
  end
  if news.started then
    flavor.emit("market_news", { line = news.started.log })
  end
  -- who's around follows what's happening: reseat the Tether's people
  -- for the new cycle (event-tied visitors read the fresh event state)
  require("sim.npcs").populate(State)
end

-- Lodging rent, charged per cycle per active reservation. Sorted keys:
-- if you're broke, WHICH reservation lapses first must be deterministic.
local function charge_lodging()
  local keys = {}
  for k in pairs(State.lodging or {}) do keys[#keys + 1] = k end
  table.sort(keys)
  for _, key in ipairs(keys) do
    local island = State.world.islands[key]
    local fee = island and island.lodging_fee or 0
    if State.persist.credits >= fee then
      State.persist.credits = State.persist.credits - fee
    else
      State.lodging[key] = nil
      flavor.emit("lodging_lapsed", { place = island and island.name or key })
    end
  end
end

-- THE clock: every cycle that passes, passes through here. Travel
-- distance, mission returns, rescues — one path, so markets, people,
-- and rent always move together.
local function advance_cycles(n)
  for _ = 1, n do
    State.cycle = State.cycle + 1
    turn_market()
    charge_lodging()
  end
end

-- Debug flags (State.debug, see CLAUDE.md) apply here only: new games
-- absorb them at birth, saves and continues never carry debug state.
local function apply_debug_flags(master_seed)
  local dbg = State.debug
  if not dbg then return master_seed end
  if dbg.master_seed then master_seed = dbg.master_seed end
  if dbg.debt then State.persist.debt = dbg.debt end
  if dbg.credits then State.persist.credits = dbg.credits end
  if dbg.force_event then
    local def = State.defs.econ_event_by_id[dbg.force_event.id]
    if def then
      State.market.event = { id = def.id,
        cycles_left = dbg.force_event.cycles or 3, gossip_seen = false }
    else
      print("[sky-islands] debug: unknown force_event id " ..
        tostring(dbg.force_event.id))
    end
  end
  return master_seed
end

function M.new_game(master_seed)
  State.master = master_seed
  State.cycle = 1
  State.persist = { debt = State.defs.economy.debt_start, credits = 0 }
  State.skiff = { hold = {} }
  State.player = { x = 0, y = 0, inv = {}, hunger = 0, hunger_state = "full",
    hp = State.defs.economy.player.max_hp }
  State.clock = { turn = 0 }
  State.world = { islands = {}, current = nil }
  State.mission = nil
  State.base = "hub"
  State.lodging = {}
  State.market = market.init()
  State.master = apply_debug_flags(State.master)
  init_session()
  if State.debug then
    State.log:push("[debug flags active]", require("palette").RED + 5)
  end
  enter_island(hubgen.build(State.defs), "hub")
  restock_trader()
  require("sim.npcs").populate(State)
  -- debug force_level: skip the Tether, drop straight onto the authored
  -- island (the hub still exists underneath for returns/rescues, and the
  -- level stays pinned to the board for re-entry)
  local dbg = State.debug
  local spec = dbg and dbg.force_level
      and State.defs.island_by_id[dbg.force_level]
  if spec then
    return M.start_mission({ authored = spec.id, name = spec.name, seed = 0,
      fee = 100, danger = spec.danger or 1, reported = spec.danger or 1 })
  end
  flavor.emit("hub_arrive", {})
  State.stack:switch(require("game.states.play"))
end

function M.continue_game(snap)
  save.restore(snap)
  init_session()
  restock_trader()
  -- old saves lack people; same-cycle repopulation is deterministic so
  -- current saves get the same faces back (visitor stock resets with
  -- them — acceptable wart, noted in the task)
  require("sim.npcs").populate(State)
  fov.update(State.island, State.defs, State.player.x, State.player.y,
    State.defs.economy.island.fov_radius)
  flavor.emit("hub_arrive", {})
  State.stack:switch(require("game.states.play"))
end

-- Three contracts per cycle, pure function of (master, cycle): browsing
-- costs nothing and re-browsing shows the same board.
function M.offers()
  -- each base posts its own board: the derivation tag carries WHERE
  local where = (State.world and State.world.current) or "hub"
  local r = rng.derive(State.master, "missions:" .. where .. ":" .. State.cycle)
  local eco = State.defs.economy
  local list = {}
  for i = 1, 3 do
    local danger = r:int(1, 3)
    local reported = danger
    if r:chance(eco.danger.misreport) then
      reported = math.max(1, math.min(3, danger + (r:chance(0.5) and 1 or -1)))
    end
    list[i] = {
      seed = r:int(1, 899999),
      fee = r:int(eco.fee_min, eco.fee_max) + eco.danger.premium[danger],
      danger = danger,     -- the truth (drives generation)
      reported = reported, -- what the board says; sometimes it lies
    }
  end
  -- veteran charter: freedom opens the deep-sky board (the quest
  -- broker's promise). Rolled after the standard three so clearing the
  -- debt never changes what the indentured board would have shown.
  if State.persist and State.persist.debt == 0 then
    list[#list + 1] = {
      seed = r:int(1, 899999),
      fee = r:int(eco.fee_min, eco.fee_max) + eco.danger.premium[3]
          + eco.veteran.premium,
      danger = 3, reported = 3, veteran = true,
      distance = eco.veteran.distance, -- deep sky: the flight costs cycles
    }
  end
  -- debug: pin an authored level to the board (appended AFTER the rolls,
  -- so the flag never perturbs the real offers)
  local dbg = State.debug
  if dbg and dbg.force_level then
    local spec = State.defs.island_by_id[dbg.force_level]
    if spec then
      list[#list + 1] = { authored = spec.id, name = spec.name, seed = 0,
        fee = 100, danger = spec.danger or 1, reported = spec.danger or 1 }
    else
      print("[sky-islands] debug: unknown force_level " ..
        tostring(dbg.force_level))
    end
  end
  return list
end

-- debug: stamp latent features onto a fresh mission island, placement
-- elegance not guaranteed. force_latent = true -> one of each latent
-- def; or a list of feature ids. QA tool, applies to every mission
-- while the flag is set.
local function debug_force_latent(island)
  local dbg = State.debug
  if not (dbg and dbg.force_latent) then return end
  local sub = require("world.substrate")
  local G = require("util.grid")
  local defs = State.defs
  local ids = {}
  if dbg.force_latent == true then
    for _, fd in ipairs(defs.feature_list) do
      if fd.latent then ids[#ids + 1] = fd.id end
    end
  else
    for _, id in ipairs(dbg.force_latent) do ids[#ids + 1] = id end
  end
  local reach = G.flood(island.w, island.h, island.start_x, island.start_y,
    function(x, y)
      return defs.terrain[sub.get(island, "terrain", x, y)].walkable
    end)
  local cand = {}
  for idx = 0, island.w * island.h - 1 do
    if reach[idx] and not island.features[idx] then
      local x, y = G.xy(idx, island.w)
      local t = defs.terrain[sub.get(island, "terrain", x, y)]
      if t.walkable and not t.door then cand[#cand + 1] = { x = x, y = y } end
    end
  end
  -- crude footprint fit: in-bounds, no sky, nothing built, not covered
  local function fits(fd, ox, oy)
    local rows = fd.footprint and fd.footprint.rows or { "@" }
    for ry, row in ipairs(rows) do
      for rx = 1, #row do
        if row:sub(rx, rx) ~= " " then
          local x, y = ox + rx - 1, oy + ry - 1
          if x < 0 or y < 0 or x >= island.w or y >= island.h then return false end
          local t = defs.terrain[sub.get(island, "terrain", x, y)]
          if t.is_sky or t.built or sub.feature_covering(island, x, y) then
            return false
          end
        end
      end
    end
    return true
  end
  local prefab = require("world.prefab")
  for i, id in ipairs(ids) do
    local fd = defs.feature_by_id[id]
    if fd and fd.latent then
      local ci = math.max(1, (#cand * i) // (#ids + 1))
      for j = ci, #cand do
        local s = cand[j]
        if fits(fd, s.x, s.y) then
          if fd.footprint then
            prefab.stamp_masked(island, defs, s.x, s.y,
              fd.footprint.rows, fd.footprint.legend)
            for ry, row in ipairs(fd.footprint.rows) do
              local cx = row:find("@", 1, true)
              if cx then
                sub.set_feature(island, s.x + cx - 1, s.y + ry - 1,
                  { def = fd, found = false, ox = s.x, oy = s.y })
                break
              end
            end
          else
            sub.set_feature(island, s.x, s.y, { def = fd, found = false })
          end
          break
        end
      end
    else
      print("[sky-islands] debug: force_latent unknown/non-latent id " .. tostring(id))
    end
  end
end

function M.start_mission(offer)
  State.mission = offer
  State.base = State.world.current -- fly back to where you signed on
  State.run = { discovered = {}, notable = {} }
  local island, id
  if offer.authored then
    -- authored levels are exact: no force_latent stamping on top
    island = require("world.authored").build(State.defs,
      State.defs.island_by_id[offer.authored])
    id = "isle:authored:" .. offer.authored
  else
    island = islandgen.generate(offer.seed, State.defs, offer.danger)
    debug_force_latent(island)
    id = "isle:" .. offer.seed
  end
  enter_island(island, id)
  flavor.emit("game_start", { island = island.name })
  State.stack:switch(require("game.states.play"))
end

-- Sleep: time (and hunger) pass, wounds knit at double the natural
-- rate. Saving is a HOME thing — the ledger only writes at the Tether;
-- a rented room heals you and nothing more.
function M.sleep()
  local eco = State.defs.economy
  local turns = eco.sleep.turns
  State.clock.turn = State.clock.turn + turns
  if not (State.debug and State.debug.no_hunger) then
    State.player.hunger = math.min(eco.hunger.collapse - 1,
      State.player.hunger + eco.hunger.per_turn * turns)
    State.player.hunger_state = require("sim.needs").state(State.player.hunger, eco)
  end
  State.player.hp = math.min(eco.player.max_hp,
    State.player.hp + turns // eco.sleep.heal_every)
  flavor.emit("sleep", {})
  if State.world.current == "hub" then save.write() end
end

-- Collapse: the company retrieves you (and its skiff, and incidentally
-- your goods), bills the retrieval, and you wake at your bunk. The
-- mission is forfeit — no fee, no bounties, and the cycle turns.
-- Injury collapse (hp <= 0) adds the medical surcharge.
function M.rescue()
  local eco = State.defs.economy
  local injured = State.player.hp <= 0
  local was_free = State.persist.debt == 0
  local fee = eco.rescue_fee + (injured and eco.medical_fee or 0)
  State.mission = nil
  State.run = nil
  State.base = "hub" -- the company retrieves you HOME, wherever you fell
  advance_cycles(1)
  State.persist.debt = State.persist.debt + fee
  State.player.hunger = 0
  State.player.hunger_state = "full"
  State.player.hp = eco.player.max_hp -- stabilized; itemized, no doubt

  local hub = State.world.islands.hub
  local G = require("util.grid")
  local bx, by = hub.start_x, hub.start_y
  for idx, f in pairs(hub.features) do
    if f.def.id == "bunk" then bx, by = G.xy(idx, hub.w) end
  end
  enter_island(hub, "hub", bx, by)
  restock_trader()
  flavor.emit("rescued", { fee = fee, debt = State.persist.debt })
  if was_free then
    flavor.emit("reindentured", {}) -- freedom, briefly. The door swings both ways.
  end
  save.write()
  State.stack:switch(require("game.states.rescued"), { injured = injured })
end

-- Fly back to wherever the contract was signed. Distance costs cycles;
-- the autosave only happens when home is the Tether.
function M.return_to_hub()
  local distance = (State.mission and State.mission.distance) or 1
  State.mission = nil
  State.run = nil
  advance_cycles(distance)
  local key = State.base or "hub"
  local base = State.world.islands[key] or State.world.islands.hub
  enter_island(base, key)
  if key == "hub" then
    restock_trader()
    flavor.emit("hub_arrive", {})
    save.write() -- autosave every TRUE homecoming
  else
    flavor.emit("travel_arrive", { place = base.name })
  end
  State.stack:switch(require("game.states.play"))
end

-- Travel between bases (SI-0006a): fee paid, distance in cycles served.
-- Gating (freedom, fare) is the travel agent's job in talk.lua; this
-- just flies. dest_id "hub" comes home; anything else is an authored
-- destination spec id.
function M.travel(dest_id)
  local eco = State.defs.economy
  local entry
  if dest_id == "hub" then
    entry = eco.travel.hub
  else
    for _, d in ipairs(eco.travel.destinations) do
      if d.id == dest_id then entry = d break end
    end
  end
  State.persist.credits = State.persist.credits - entry.fee
  advance_cycles(entry.distance)
  local key, island
  if dest_id == "hub" then
    key, island = "hub", State.world.islands.hub
  else
    key = "isle:authored:" .. dest_id
    island = State.world.islands[key]
    if not island then
      island = require("world.authored").build(State.defs,
        State.defs.island_by_id[dest_id])
    end
  end
  State.base = key
  enter_island(island, key)
  if key == "hub" then
    restock_trader()
    flavor.emit("hub_arrive", {})
    save.write()
  else
    flavor.emit("travel_arrive", { place = island.name })
  end
  State.stack:switch(require("game.states.play"))
end

return M
