-- Applies one action, advances the clock, runs post-hooks (FOV, one-time
-- discovery flavor). Player-only for the slice, but this is where an actor
-- scheduler slots in later.
local sub = require("world.substrate")
local fov = require("world.fov")
local flavor = require("flavor")
local G = require("util.grid")

local M = {}

local function post_sight_hooks(S)
  local island, defs = S.island, S.defs
  -- one-time beats when the player first STANDS next to notable things
  for _, nb in ipairs(G.neighbors8(S.player.x, S.player.y, island.w, island.h)) do
    local t = defs.terrain[sub.get(island, "terrain", nb.x, nb.y)]
    if t.is_sky then flavor.emit_once("first_sky_edge", {}) end
    if t.id == "wall_plank" or t.door then flavor.emit_once("first_building", {}) end
  end
end

-- returns "submit" when the run should end, otherwise nil
function M.take(S, verb, arg)
  local actions = require("sim.actions")
  local fn = actions.verbs[verb]
  if not fn then return nil end
  local ev = fn(S, arg)
  if not ev then return nil end
  if ev.kind == "submit" then return "submit" end

  S.clock.turn = S.clock.turn + 1
  if require("sim.needs").tick(S) then
    return "collapse" -- caller (play state) handles the rescue
  end
  require("sim.creatures").phase(S)
  if S.player.hp <= 0 then
    return "collapse" -- injury; rescue() reads hp to pick the invoice
  end
  if ev.kind == "move" or ev.kind == "door" then
    fov.update(S.island, S.defs, S.player.x, S.player.y,
      S.defs.economy.island.fov_radius)
    require("sim.discovery").scan_sight(S)
    post_sight_hooks(S)
  end
  return nil
end

return M
