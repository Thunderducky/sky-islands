local draw = require("ui.draw")
local turn = require("sim.turn")

local S = {}

local DIRS = {
  up = { 0, -1 }, down = { 0, 1 }, left = { -1, 0 }, right = { 1, 0 },
  k = { 0, -1 }, j = { 0, 1 }, h = { -1, 0 }, l = { 1, 0 },
  y = { -1, -1 }, u = { 1, -1 }, b = { -1, 1 }, n = { 1, 1 },
}

function S.key(self, k)
  local d = DIRS[k]
  if d then
    turn.take(State, "move", { dx = d[1], dy = d[2] })
    return
  end
  if k == "g" then
    turn.take(State, "pickup")
  elseif k == "o" then
    turn.take(State, "toggle_door")
  elseif k == "period" then
    turn.take(State, "wait")
  elseif k == "i" then
    State.stack:push(require("game.states.inventory"))
  elseif k == "x" then
    State.stack:push(require("game.states.examine"))
  elseif k == "space" then
    if turn.take(State, "submit") == "submit" then
      local result = require("sim.contract").settle(State)
      State.persist.debt = result.debt_after
      State.persist.credits = State.persist.credits + result.kept
      State.stack:switch(require("game.states.report"), result)
    end
  end
end

function S.draw(self)
  draw.frame(State)
end

return S
