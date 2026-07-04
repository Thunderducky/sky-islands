-- Starts a survey run: island, player, streams, log, flavor, first FOV.
-- Debt and banked credits live in State.persist and carry across runs —
-- successive surveys chip the indenture; that's the game.
local islandgen = require("world.islandgen")
local fov = require("world.fov")
local rng = require("util.rng")
local log = require("ui.log")
local flavor = require("flavor")

local M = {}

function M.new_run(seed)
  local defs = State.defs
  State.seed = seed
  State.island = islandgen.generate(seed, defs)
  State.player = {
    x = State.island.start_x, y = State.island.start_y, inv = {},
  }
  State.clock = { turn = 0 }
  State.run = {
    debt = State.persist.debt,
    discovered = {},
  }
  State.rng = { flavor = rng.new(seed):fork("flavor") }
  State.log = log.new(60)
  flavor.init({
    pools = require("defs.flavor").events,
    rng = State.rng.flavor,
    sink = function(text, color) State.log:push(text, color) end,
  })

  fov.update(State.island, defs, State.player.x, State.player.y,
    defs.economy.island.fov_radius)
  flavor.emit("game_start", { island = State.island.name })

  State.stack:switch(require("game.states.play"))
end

return M
