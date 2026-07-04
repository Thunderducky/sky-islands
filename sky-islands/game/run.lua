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
  fov.update(island, State.defs, State.player.x, State.player.y,
    State.defs.economy.island.fov_radius)
end

local function restock_trader()
  local hub = State.world.islands.hub
  for _, f in pairs(hub.features) do
    if f.def.id == "trader" and f.stock then
      local r = rng.derive(State.master, "market:" .. State.cycle)
      f.stock = {}
      local stock = f.stock
      stock[#stock + 1] = { id = "ration_pack", n = r:int(4, 8) }
      stock[#stock + 1] = { id = "bandage", n = r:int(2, 4) }
      stock[#stock + 1] = { id = "preserves_jar", n = r:int(2, 5) }
      if r:chance(0.5) then
        stock[#stock + 1] = { id = "salvage_cable", n = r:int(1, 3) }
      end
      if r:chance(0.3) then
        stock[#stock + 1] = { id = "tools_surveyor", n = 1 }
      end
    end
  end
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
  init_session()
  enter_island(hubgen.build(State.defs), "hub")
  restock_trader()
  flavor.emit("hub_arrive", {})
  State.stack:switch(require("game.states.play"))
end

function M.continue_game(snap)
  save.restore(snap)
  init_session()
  restock_trader()
  fov.update(State.island, State.defs, State.player.x, State.player.y,
    State.defs.economy.island.fov_radius)
  flavor.emit("hub_arrive", {})
  State.stack:switch(require("game.states.play"))
end

-- Three contracts per cycle, pure function of (master, cycle): browsing
-- costs nothing and re-browsing shows the same board.
function M.offers()
  local r = rng.derive(State.master, "missions:" .. State.cycle)
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
  return list
end

function M.start_mission(offer)
  State.mission = offer
  State.run = { discovered = {} }
  local island = islandgen.generate(offer.seed, State.defs, offer.danger)
  enter_island(island, "isle:" .. offer.seed)
  flavor.emit("game_start", { island = island.name })
  State.stack:switch(require("game.states.play"))
end

-- Sleep: time (and hunger) pass, wounds knit at double the natural
-- rate, and the game saves. Hunger clamps below collapse — you can wake
-- starving, but nobody gets billed for a rescue from their own bed.
function M.sleep()
  local eco = State.defs.economy
  local turns = eco.sleep.turns
  State.clock.turn = State.clock.turn + turns
  State.player.hunger = math.min(eco.hunger.collapse - 1,
    State.player.hunger + eco.hunger.per_turn * turns)
  State.player.hunger_state = require("sim.needs").state(State.player.hunger, eco)
  State.player.hp = math.min(eco.player.max_hp,
    State.player.hp + turns // eco.sleep.heal_every)
  flavor.emit("sleep", {})
  save.write()
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
  State.cycle = State.cycle + 1
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

function M.return_to_hub()
  State.mission = nil
  State.run = nil
  State.cycle = State.cycle + 1
  local hub = State.world.islands.hub
  enter_island(hub, "hub")
  restock_trader()
  flavor.emit("hub_arrive", {})
  save.write() -- autosave every homecoming
  State.stack:switch(require("game.states.play"))
end

return M
