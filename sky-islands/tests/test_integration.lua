-- Headless full-loop test: stub the engine globals, load main.lua, and
-- drive hub -> coordinator -> mission -> loot -> report -> home -> shop
-- -> sleep, plus a save/restore round trip. Catches wiring errors no unit
-- test can see.

local function noop() end
local draw_calls = 0
local counting = function() draw_calls = draw_calls + 1 end

local SAVED = nil
gfx = {
  clear = counting, text = counting, text_ex = counting,
  rect = counting, rect_fill = counting, sspr = counting, sspr_ex = counting,
  COLOR_TRUE_WHITE = 0,
}
usagi = {
  quit = noop,
  save = function(t) SAVED = t end,
  load = function() return SAVED end,
  measure_text = function(s) return #s * 6, 12 end,
}
input = { key_pressed = function() return false end }
for i, name in ipairs({ "UP", "DOWN", "LEFT", "RIGHT", "H", "J", "K", "L",
  "Y", "U", "B", "N", "G", "O", "I", "X", "R", "Q", "C", "D",
  "PERIOD", "SPACE", "ENTER", "ESCAPE", "TAB", "BACKSPACE" }) do
  input["KEY_" .. name] = i
end

-- hermetic: never load the dev's real debugflags.lua into tests
package.preload["debugflags"] = function() return {} end

require("main")

local rng = require("util.rng")
local G = require("util.grid")
local sub = require("world.substrate")

local function feature_pos(island, id)
  for idx, f in pairs(island.features) do
    if f.def.id == id then return G.xy(idx, island.w) end
  end
end

local function total_n(items)
  local n = 0
  for _, s in ipairs(items) do n = n + s.n end
  return n
end

return {
  full_loop = function(t)
    _config()
    _init()

    -- titlescreen -> intro, driven for real (exercises the actual draw
    -- and key code, not just that the files parse). new_game() itself
    -- is still called directly with a pinned seed below rather than via
    -- intro's own [Space]/[N] handler, which seeds off os.time() and
    -- would make the rest of this test non-deterministic.
    t.ok(State.stack:top() ~= nil, "titlescreen is the first state")
    State.stack:draw(0.016) -- exercises sspr_ex/dither/text_ex/measure_text
    local title = State.stack:top()
    State.stack:key("space")
    t.ok(State.stack:top() ~= title, "space advances past the title screen")
    State.stack:draw(0.016) -- exercises the (now header-less) intro draw

    require("game.run").new_game(12345) -- pinned seed: test must be deterministic
    local hub = State.island
    t.ok(hub.is_hub, "game starts at the hub")
    t.ok(State.persist.debt > 0, "born in debt")
    State.stack:draw(0.016)

    -- coordinator -> accept an offer -> mission island
    local cx, cy = feature_pos(hub, "coordinator")
    t.ok(cx, "hub has a coordinator")
    State.player.x, State.player.y = cx, cy
    local play = State.stack:top()
    State.stack:key("space")
    t.ok(State.stack:top() ~= play, "coordinator opens the offer board")
    State.stack:draw(0.016)
    State.stack:key("j")
    State.stack:key("space") -- take contract
    t.ok(State.mission, "mission accepted")
    t.ok(not State.island.is_hub, "shipped out to a survey island")
    t.ok(State.world.islands.hub, "hub persists in the world registry")
    State.stack:draw(0.016)

    -- wander; every action must be error-free. Shield hp so a random
    -- creature can't end the walk (restored right after).
    local max_hp = State.defs.economy.player.max_hp
    State.player.hp = 100000
    local r = rng.new(99)
    local moves = { "h", "j", "k", "l", "y", "u", "b", "n" }
    for _ = 1, 120 do State.stack:key(r:pick(moves)) end
    State.player.hp = max_hp
    State.stack:key("o")
    State.stack:key("period")
    t.ok(State.island.seen_count > 0, "fog revealed by wandering")
    t.ok(State.player.hunger > 0, "the hunger clock ticks with turns")

    -- eating works end to end
    local needs = require("sim.needs")
    State.player.hunger = 400
    State.player.hunger_state = needs.state(400, State.defs.economy)
    table.insert(State.player.inv, { id = "ration_pack", n = 1 })
    t.ok(needs.eat(State, #State.player.inv), "ration is edible")
    t.eq(State.player.hunger, 150, "nutrition applied")
    -- inventory overlay opens, eat key doesn't crash on any selection
    State.stack:key("i")
    State.stack:draw(0.016)
    State.stack:key("space")
    State.stack:key("backspace")

    -- SI-0012: using an item keeps the cursor where it is
    State.player.hunger = 600
    State.player.hunger_state = needs.state(600, State.defs.economy)
    table.insert(State.player.inv, { id = "berries", n = 2 })
    State.stack:key("i")
    local inv_state = State.stack:top()
    local bottom = inv_state.menu:count()
    for _ = 1, bottom do State.stack:key("j") end
    t.eq(inv_state.menu.index, bottom, "cursor at the berries")
    State.stack:key("space") -- eat one berry: the stack survives
    t.eq(inv_state.menu.index, bottom, "cursor stays on the slot after use")
    State.stack:key("space") -- eat the last berry: the slot vanishes
    t.eq(inv_state.menu.index, math.max(1, inv_state.menu:count()),
      "cursor clamps when the slot is gone (or rests in an empty pack)")
    State.stack:key("backspace")

    -- forage a berry bush: one-way container, disappears when stripped
    local forage_idx
    for idx, f in pairs(State.island.features) do
      if f.def.take_only then forage_idx = idx break end
    end
    t.ok(forage_idx, "mission island has a berry bush")
    local fx, fy = G.xy(forage_idx, State.island.w)
    -- bushes carry berries or medicinal herbs; assert on what's in THIS one
    local forage_id = State.island.features[forage_idx].loot[1].id
    State.player.x, State.player.y = fx, fy
    State.stack:key("g")
    State.stack:key("tab")   -- try to stow INTO the bush
    State.stack:key("space")
    t.ok(sub.feature_at(State.island, fx, fy) ~= nil,
      "one-way: stowing into a bush does nothing")
    State.stack:key("tab")
    State.stack:key("space") -- take the forage
    local has_forage = false
    for _, s in ipairs(State.player.inv) do
      if s.id == forage_id then has_forage = true end
    end
    t.ok(has_forage, "forage goods in the pack")
    t.eq(sub.feature_at(State.island, fx, fy), nil,
      "stripped bush loses its forage feature")
    State.stack:key("backspace")

    -- loot a cache, stow in the skiff hold at the beacon
    local island = State.island
    local cache_idx
    for idx, f in pairs(island.features) do
      if f.def.loot_table and #f.loot > 0 then cache_idx = idx break end
    end
    t.ok(cache_idx, "island has a stocked cache")
    State.player.x, State.player.y = G.xy(cache_idx, island.w)
    State.stack:key("g")
    State.stack:key("space") -- take a stack
    t.ok(#State.player.inv > 0, "loot in the pack")
    State.stack:key("backspace")

    State.player.x, State.player.y = island.start_x, island.start_y
    State.stack:key("g")     -- skiff hold via beacon
    State.stack:key("g")     -- stow ONE unit
    t.eq(total_n(State.skiff.hold), 1, "g moves exactly one unit")
    State.stack:key("backspace")

    -- combat: plant a dust-hen next to us and bump it to death
    local hen_def = State.defs.creature_by_id["dust_hen"]
    State.island.creatures = State.island.creatures or {}
    local hen = { def = hen_def, x = State.player.x + 1, y = State.player.y,
      hp = hen_def.max_hp, mp = 0, state = "wander" }
    sub.set(State.island, "terrain", hen.x, hen.y, State.defs.tid["grass"])
    table.insert(State.island.creatures, hen)
    State.player.hp = 100000 -- retaliation shield for the duel
    for _ = 1, 40 do
      if hen.hp <= 0 then break end
      State.player.x, State.player.y = hen.x - 1, hen.y -- stay on its west
      State.stack:key("l") -- bump east = attack
    end
    t.ok(hen.hp <= 0, "the dust-hen fell")
    local gone = true
    for _, c in ipairs(State.island.creatures) do
      if c == hen then gone = false end
    end
    t.ok(gone, "removed from the island")
    State.player.hp = max_hp
    State.stack:draw(0.016)

    -- submit -> confirm -> report -> fly home
    local debt_before = State.persist.debt
    local confirm = require("game.states.confirm")
    State.stack:key("space")
    t.ok(State.stack:top() == confirm, "leaving asks first")
    State.stack:draw(0.016)
    State.stack:key("n") -- second thoughts
    t.eq(State.persist.debt, debt_before, "declining leaves the contract open")
    t.ok(not State.island.is_hub, "still on the island after declining")
    State.stack:key("space")
    State.stack:key("g") -- detour: check the hold before deciding
    t.ok(State.stack:top() == require("game.states.transfer"),
      "g from the confirm opens the skiff hold")
    State.stack:key("backspace")
    State.stack:key("space")
    State.stack:key("y") -- commit
    State.stack:draw(0.016)
    t.ok(State.persist.debt < debt_before, "garnish chipped the debt")
    local hold_before_home = total_n(State.skiff.hold)
    State.stack:key("r")
    t.ok(State.island.is_hub, "back home at The Tether")
    t.eq(total_n(State.skiff.hold), hold_before_home, "skiff cargo survived the flight")
    t.ok(SAVED ~= nil, "homecoming autosaved")
    State.stack:draw(0.016)

    -- company store: sell something, buy a ration, pay debt
    local tx, ty = feature_pos(State.island, "trader")
    State.player.x, State.player.y = tx, ty
    State.stack:key("space")
    -- a market event may be news, in which case the keeper talks first
    if State.stack:top() == require("game.states.gossip") then
      State.stack:draw(0.016) -- exercise the gossip overlay draw
      State.stack:key("space") -- wave him off
    end
    State.stack:draw(0.016)
    local cash0 = State.persist.credits
    State.stack:key("g")     -- buy ONE (focus starts on stocked store)
    t.ok(State.persist.credits < cash0, "buying costs")
    State.stack:key("tab")   -- focus own pack
    local cash1 = State.persist.credits
    State.stack:key("space") -- sell a stack (at least the bought item exists)
    t.ok(State.persist.credits > cash1, "selling pays out")
    local debt0 = State.persist.debt
    State.stack:key("d")     -- voluntary debt payment
    t.ok(State.persist.debt <= debt0, "debt payment applied (or broke)")
    State.stack:key("backspace")

    -- stash at the bunk, then sleep (saves)
    local bx, by = feature_pos(State.island, "bunk")
    State.player.x, State.player.y = bx, by
    if #State.player.inv > 0 then
      State.stack:key("g")
      State.stack:key("tab")
      State.stack:key("space")
      State.stack:key("backspace")
    end
    SAVED = nil
    State.stack:key("space") -- bunk asks first
    t.ok(State.stack:top() == require("game.states.confirm"),
      "sleeping asks first")
    State.stack:key("y")
    local wipe = require("game.states.sleepwipe")
    t.ok(State.stack:top() == wipe, "the night rolls in")
    State.stack:update(0.2)
    State.stack:draw(0.016) -- mid-wipe frame draws
    t.eq(SAVED, nil, "no save until the screen is dark")
    for _ = 1, 20 do State.stack:update(0.05) end -- full dark: night passes
    State.stack:draw(0.016)
    t.ok(SAVED ~= nil, "sleeping saves")
    t.ok(State.stack:top() == wipe, "the dark holds until you rise")
    State.stack:key("space") -- rise
    for _ = 1, 20 do State.stack:update(0.05) end
    t.ok(State.stack:top() ~= wipe, "morning: the wipe cleared itself")

    -- save/restore round trip: mutate, restore, verify
    local save = require("game.save")
    local snap = save.snapshot()
    local debt_snap = State.persist.debt
    local terrain_snap_50 = State.island.terrain[50]
    State.persist.debt = 1
    State.island.terrain[50] = 999
    save.restore(snap)
    t.eq(State.persist.debt, debt_snap, "restore rewinds debt")
    t.eq(State.island.terrain[50], terrain_snap_50, "restore rewinds terrain")
    t.ok(State.island.is_hub, "restored at the hub")
    local kept_mission_island = false
    for id in pairs(State.world.islands) do
      if id ~= "hub" then kept_mission_island = true end
    end
    t.ok(kept_mission_island, "visited islands persist across restore")
    State.stack:draw(0.016)

    -- continue-from-save path drives the same restore through the intro
    _init()
    State.stack:key("space") -- past the title screen
    State.stack:key("c")
    t.ok(State.island and State.island.is_hub, "continue lands at the hub")
    t.eq(State.persist.debt, debt_snap, "continue restores the debt")

    -- sleep heals at double the natural rate (and still saves)
    local eco = State.defs.economy
    local bx1, by1 = feature_pos(State.island, "bunk")
    State.player.x, State.player.y = bx1, by1
    State.player.hp = 5
    State.player.hunger = 0
    SAVED = nil
    State.stack:key("space") -- bunk asks first
    State.stack:key("y")
    for _ = 1, 20 do State.stack:update(0.05) end -- full dark: night passes
    State.stack:key("space") -- rise
    for _ = 1, 20 do State.stack:update(0.05) end
    t.eq(State.player.hp, 5 + eco.sleep.turns // eco.sleep.heal_every,
      "bed rest heals 1 per " .. eco.sleep.heal_every .. " turns")
    t.eq(State.player.hunger, eco.sleep.turns, "sleeping costs hunger")
    t.ok(SAVED ~= nil, "sleep saved")
    State.player.hp = State.defs.economy.player.max_hp

    -- collapse by HUNGER -> rescue: take a contract, starve, wake billed
    local cx2, cy2 = feature_pos(State.island, "coordinator")
    State.player.x, State.player.y = cx2, cy2
    State.stack:key("space") -- offer board
    local board = require("game.run").offers()
    for _, o in ipairs(board) do
      t.ok(o.danger >= 1 and o.danger <= 3, "danger tier in range")
      t.ok(o.reported >= 1 and o.reported <= 3, "reported tier in range")
      t.ok(o.fee >= eco.fee_min, "fee includes at least the base roll")
    end
    State.stack:key("space") -- take first contract
    t.ok(State.mission, "second mission accepted")
    local debt_pre = State.persist.debt
    SAVED = nil
    State.player.hunger = eco.hunger.collapse - 1
    State.player.hunger_state = "starving"
    State.stack:key("period") -- one turn: the floor comes up
    State.stack:draw(0.016)   -- retrieval notice renders
    t.ok(State.island.is_hub, "rescued back to the hub")
    t.eq(State.persist.debt, debt_pre + eco.rescue_fee, "retrieval billed, no medical")
    t.eq(State.mission, nil, "mission forfeit")
    t.eq(State.player.hunger, 0, "stabilized (fed)")
    t.ok(SAVED ~= nil, "rescue autosaved")
    local bx2, by2 = feature_pos(State.island, "bunk")
    t.ok(State.player.x == bx2 and State.player.y == by2, "woke at the bunk")
    State.stack:key("space") -- wake up, poorer
    t.ok(State.stack:top() ~= nil, "back in play after the invoice")

    -- collapse by INJURY -> rescue with the medical surcharge
    State.player.x, State.player.y = cx2, cy2
    State.stack:key("space") -- offer board
    State.stack:key("space") -- take a contract
    t.ok(State.mission, "third mission accepted")
    local shrike_def = State.defs.creature_by_id["rim_shrike"]
    State.island.creatures = State.island.creatures or {}
    table.insert(State.island.creatures,
      { def = shrike_def, x = State.player.x + 1, y = State.player.y,
        hp = shrike_def.max_hp, mp = 0, state = "wander" })
    State.player.hp = 1
    debt_pre = State.persist.debt
    local rescued = false
    for _ = 1, 60 do
      State.stack:key("period") -- wait; the shrike does shrike things
      if State.island.is_hub then rescued = true break end
    end
    t.ok(rescued, "the shrike eventually connects")
    t.eq(State.persist.debt, debt_pre + eco.rescue_fee + eco.medical_fee,
      "injury rescue bills retrieval + medical")
    t.eq(State.player.hp, eco.player.max_hp, "stabilized (patched)")
    State.stack:draw(0.016) -- injured retrieval notice renders
    State.stack:key("space")

    -- manumission: pay the debt down to zero at the store counter
    local tx2, ty2 = feature_pos(State.island, "trader")
    State.player.x, State.player.y = tx2, ty2
    State.persist.debt = 80
    State.persist.credits = 500
    State.stack:key("space") -- shop
    local shop = State.stack:top()
    State.stack:key("d")     -- pays min(step=100, 500, 80) = 80 -> ZERO
    t.eq(State.persist.debt, 0, "account closed")
    t.eq(State.persist.credits, 420, "paid exactly what was owed")
    t.ok(State.stack:top() ~= shop, "the coldest letter arrives")
    State.stack:draw(0.016)  -- manumission screen renders
    State.stack:key("space") -- free agent walks away
    State.stack:draw(0.016)
    -- freed: a settle with debt 0 garnishes nothing (unit-tested; here we
    -- just confirm the store shows no [d] path anymore)
    State.stack:key("space") -- shop again
    State.stack:key("d")
    t.eq(State.persist.debt, 0, "no debt appears from paying nothing")
    State.stack:key("backspace")

    -- ...and a rescue re-indentures a free agent
    State.player.x, State.player.y = cx2, cy2
    State.stack:key("space")
    State.stack:key("space") -- take a contract, free this time
    State.player.hunger = eco.hunger.collapse - 1
    State.player.hunger_state = "starving"
    State.stack:key("period")
    t.eq(State.persist.debt, eco.rescue_fee, "freedom, briefly: back on the books")
    State.stack:key("space")

    t.ok(draw_calls > 100, "drawing actually happened")
  end,

  market_gossip_shows_once = function(t)
    _config()
    _init()
    SAVED = nil
    require("game.run").new_game(4242)
    -- force a fresh event so the flow is deterministic regardless of seed
    State.market.event = { id = "patrol_repairs", cycles_left = 3,
      gossip_seen = false }
    local gossip = require("game.states.gossip")
    local tx, ty = feature_pos(State.island, "trader")
    State.player.x, State.player.y = tx, ty
    State.stack:key("space")
    t.ok(State.stack:top() == gossip, "keeper gossips while the event is news")
    State.stack:draw(0.016)
    State.stack:key("space")     -- wave him off -> transfer beneath
    State.stack:key("backspace") -- close the store
    State.stack:key("space")     -- revisit
    t.ok(State.stack:top() ~= gossip, "gossip fires once per event, not per visit")
    State.stack:key("backspace")
  end,

  assay_via_space_on_the_tile = function(t)
    _config()
    _init()
    SAVED = nil
    require("game.run").new_game(31337)
    -- manufacture a mission context on the hub: a run + an ore deposit
    -- on the tile under the player
    State.run = { discovered = {}, notable = {} }
    local px, py = State.player.x, State.player.y
    sub.set_feature(State.island, px, py,
      { def = State.defs.feature_by_id["ore_deposit"], found = false })
    local turn0 = State.clock.turn
    State.stack:key("space")
    t.eq(#State.run.notable, 1, "space on the deposit assays it")
    t.eq(State.run.notable[1].def.id, "ore_deposit")
    t.eq(State.clock.turn, turn0 + 1, "assay cost a turn")
    State.stack:key("space")
    t.eq(#State.run.notable, 1, "second space: already confirmed, no dupe")
    t.eq(State.clock.turn, turn0 + 1, "and no extra turn")
    sub.set_feature(State.island, px, py, nil)
  end,

  debug_flags_apply_at_new_game = function(t)
    _config()
    _init()
    SAVED = nil
    t.eq(State.debug, nil, "no debugflags.lua in tests: State.debug is nil")
    -- simulate a flags file (set after _init, read by new_game)
    State.debug = {
      master_seed = 999, credits = 500, debt = 100,
      force_event = { id = "patrol_repairs", cycles = 2 },
      reveal_fog = true,
    }
    require("game.run").new_game(12345)
    t.eq(State.master, 999, "master_seed overrides the intro's seed")
    t.eq(State.persist.credits, 500, "credits override")
    t.eq(State.persist.debt, 100, "debt override")
    t.eq(State.market.event.id, "patrol_repairs", "event forced live")
    t.eq(State.market.event.cycles_left, 2, "forced duration honored")
    local unseen = 0
    for i = 1, State.island.w * State.island.h do
      local sky = State.defs.terrain[State.island.terrain[i]].is_sky
      if State.island.fog[i] == 0 and not sky then unseen = unseen + 1 end
    end
    t.eq(unseen, 0, "reveal_fog: no unseen land tiles")

    -- unknown event ids are ignored, not fatal
    State.debug = { force_event = { id = "no_such_event" } }
    require("game.run").new_game(777)
    t.eq(State.market.event, nil, "unknown force_event id is dropped")

    -- force_latent stamps every latent def onto a mission island
    State.debug = { force_latent = true }
    require("game.run").start_mission({ seed = 555, fee = 100,
      danger = 1, reported = 1 })
    local have = {}
    for _, f in pairs(State.island.features) do
      if f.def.latent then have[f.def.id] = true end
    end
    for _, fd in ipairs(State.defs.feature_list) do
      if fd.latent then
        t.ok(have[fd.id], "forced onto the island: " .. fd.id)
      end
    end

    -- force_level: new games start ON the authored island directly...
    State.debug = { force_level = "proving_grounds" }
    require("game.run").new_game(888)
    t.eq(State.island.name, "Proving Grounds", "spawned straight onto it")
    t.ok(State.island.extract_idx, "with a beacon to leave by")
    t.ok(State.world.islands.hub ~= nil, "the hub still exists underneath")
    -- ...and it stays pinned to the board for re-entry
    local offers = require("game.run").offers()
    t.eq(offers[#offers].authored, "proving_grounds", "still on the board")
    State.debug = nil
  end,

  determinism_same_seed_same_offers = function(t)
    _config()
    _init()
    SAVED = nil
    State.stack:key("space")
    State.master = 777
    State.cycle = 3
    local run = require("game.run")
    local a, b = run.offers(), run.offers()
    t.deep_eq(a, b, "browsing the board twice is identical")
    -- and offers never perturb island generation
    local defs = State.defs
    local gen = require("world.islandgen")
    local isl1 = gen.generate(4242, defs)
    run.offers()
    local isl2 = gen.generate(4242, defs)
    t.deep_eq(isl1.terrain, isl2.terrain, "offers don't perturb islands")
  end,
}
