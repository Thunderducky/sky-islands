local draw = require("ui.draw")
local turn = require("sim.turn")
local sub = require("world.substrate")
local flavor = require("flavor")

local S = {}

local DIRS = {
  up = { 0, -1 }, down = { 0, 1 }, left = { -1, 0 }, right = { 1, 0 },
  k = { 0, -1 }, j = { 0, 1 }, h = { -1, 0 }, l = { 1, 0 },
  y = { -1, -1 }, u = { 1, -1 }, b = { -1, 1 }, n = { 1, 1 },
}

-- What's lootable where the player stands. Anything with an .items list
-- is a container; .prices makes it a shop (company store).
local function container_here(S_)
  local island, eco = S_.island, S_.defs.economy
  local x, y = S_.player.x, S_.player.y
  local f = sub.feature_at(island, x, y)
  if f then
    local id = f.def.id
    if id == "skiff_dock" or id == "extract_beacon" then
      return { name = "skiff hold", items = S_.skiff.hold, cap = eco.skiff_slots }
    elseif id == "bunk" then
      return { name = "your lockbox", items = f.stash, cap = eco.stash_slots }
    elseif id == "trader" then
      return { name = "company store", items = f.stock, cap = eco.trader_slots,
        prices = { buy = eco.buy_mult, sell = eco.sell_mult, market = true } }
    elseif f.loot then
      local cont = { name = f.def.name, items = f.loot, cap = f.def.slots or 10 }
      if f.def.take_only then
        cont.take_only = true
        -- an emptied forage feature disappears, leaving plain terrain
        cont.on_empty = function()
          sub.set_feature(S_.island, x, y, nil)
        end
      end
      return cont
    end
  end
  local pile = sub.pile_at(island, x, y)
  if pile and #pile > 0 then
    return { name = "the ground", items = pile, cap = eco.ground_slots }
  end
  return nil
end

-- Space = interact with the feature underfoot.
local function interact(S_)
  local f = sub.feature_at(S_.island, S_.player.x, S_.player.y)
  local id = f and f.def.id
  if id == "extract_beacon" then
    -- leaving is a one-way step (settle, cycle++): confirm first
    S_.stack:push(require("game.states.confirm"), {
      text = "Submit the survey and call the skiff home?",
      extra_hint = "[G] check the skiff hold first",
      extra_keys = {
        g = function()
          S_.stack:push(require("game.states.transfer"), container_here(S_))
        end,
      },
      on_yes = function()
        if turn.take(S_, "submit") == "submit" then
          local result = require("sim.contract").settle(S_)
          S_.persist.debt = result.debt_after
          S_.persist.credits = S_.persist.credits + result.kept
          S_.stack:switch(require("game.states.report"), result)
        end
      end,
    })
  elseif id == "coordinator" then
    S_.stack:push(require("game.states.offers"))
  elseif id == "trader" then
    S_.stack:push(require("game.states.transfer"), container_here(S_))
    -- market event that's still news? the keeper talks first
    local ev = S_.market and S_.market.event
    if ev and not ev.gossip_seen then
      ev.gossip_seen = true
      S_.stack:push(require("game.states.gossip"), ev)
    end
  elseif id == "bunk" then
    -- sleeping passes time and saves: worth a deliberate yes
    S_.stack:push(require("game.states.confirm"), {
      text = "Sleep until morning? (heals, hungers, saves)",
      extra_hint = "[G] open your lockbox first",
      extra_keys = {
        g = function()
          S_.stack:push(require("game.states.transfer"), container_here(S_))
        end,
      },
      on_yes = function()
        S_.stack:push(require("game.states.sleepwipe"))
      end,
    })
  elseif id == "skiff_dock" then
    S_.stack:push(require("game.states.transfer"), container_here(S_))
  elseif sub.feature_covering(S_.island, S_.player.x, S_.player.y) then
    -- on (or inside the footprint of) a latent feature: survey work, or
    -- replaying a logged find; a real assay costs a turn like any verb
    if turn.take(S_, "assay") == "collapse" then
      require("game.run").rescue()
    end
  end
end

-- Every turn-taking action goes through here so a collapse (hunger clock
-- run out) is caught no matter which verb triggered it.
local function act(verb, arg)
  if turn.take(State, verb, arg) == "collapse" then
    require("game.run").rescue()
  end
end

function S.key(self, k)
  local d = DIRS[k]
  if d then
    act("move", { dx = d[1], dy = d[2] })
    return
  end
  if k == "g" then
    local cont = container_here(State)
    if cont then
      State.stack:push(require("game.states.transfer"), cont)
    else
      flavor.emit("nothing_here", {})
    end
  elseif k == "o" then
    act("toggle_door")
  elseif k == "period" then
    act("wait")
  elseif k == "t" then
    local near = require("sim.npcs").adjacent_to(State.island,
      State.player.x, State.player.y)
    if #near == 0 then
      flavor.emit("talk_no_one", {})
    elseif #near == 1 then
      State.stack:push(require("game.states.talk"), near[1])
    else
      State.stack:push(require("game.states.pick_npc"), near)
    end
  elseif k == "i" then
    State.stack:push(require("game.states.inventory"))
  elseif k == "x" then
    State.stack:push(require("game.states.examine"))
  elseif k == "space" then
    interact(State)
  end
end

function S.draw(self)
  draw.frame(State)
end

return S
