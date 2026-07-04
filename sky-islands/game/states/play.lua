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
        prices = { buy = eco.buy_mult, sell = eco.sell_mult } }
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
    if turn.take(S_, "submit") == "submit" then
      local result = require("sim.contract").settle(S_)
      S_.persist.debt = result.debt_after
      S_.persist.credits = S_.persist.credits + result.kept
      S_.stack:switch(require("game.states.report"), result)
    end
  elseif id == "coordinator" then
    S_.stack:push(require("game.states.offers"))
  elseif id == "trader" then
    S_.stack:push(require("game.states.transfer"), container_here(S_))
  elseif id == "bunk" then
    require("game.run").sleep()
  elseif id == "skiff_dock" then
    S_.stack:push(require("game.states.transfer"), container_here(S_))
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
