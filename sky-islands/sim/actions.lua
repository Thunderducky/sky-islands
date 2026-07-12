-- Actions are data; each verb validates and applies. Adding a verb = one
-- entry here. Apply functions return an event table for turn.lua's post
-- hooks, or nil if the action didn't consume a turn.
local sub = require("world.substrate")
local flavor = require("flavor")
local inv = require("sim.inventory")

local M = {}

local function enter_tile(S, x, y)
  local island, defs = S.island, S.defs
  local f = sub.feature_at(island, x, y)
  if f and f.def.loot_table and not f.opened then
    -- discovery only: the loot stays inside; [g] opens the transfer UI
    f.opened = true
    S.run.discovered[#S.run.discovered + 1] = f
    if #f.loot > 0 then
      flavor.emit("cache_open", { feature = f.def.name,
                                  contents = inv.summary(f.loot, defs.item_by_id) })
    else
      flavor.emit("cache_empty", { feature = f.def.name })
    end
  elseif f and f.def.id == "extract_beacon" then
    flavor.emit("submit_hint", {})
  else
    -- footprint membership counts as standing on the feature
    local lf = sub.feature_covering(island, x, y)
    if lf and lf.def.latent and lf.def.discover == "assay"
        and not lf.found then
      flavor.emit("assay_hint", { feature = lf.def.name })
    end
  end
end

M.verbs = {
  move = function(S, a)
    local island, defs = S.island, S.defs
    local nx, ny = S.player.x + a.dx, S.player.y + a.dy
    if not sub.in_bounds(island, nx, ny) then return nil end
    local creatures = require("sim.creatures")
    local c, ci = creatures.at(island, nx, ny)
    if c then -- bump attack
      creatures.player_attack(S, c, ci)
      return { kind = "attack" }
    end
    local t = defs.terrain[sub.get(island, "terrain", nx, ny)]
    if t.is_sky then
      flavor.emit("sky_blocked", {})
      return { kind = "bump_sky" } -- costs a turn: you flinched
    end
    if t.door and not t.walkable then
      sub.set(island, "terrain", nx, ny, defs.tid[t.door.opens_to])
      flavor.emit("door_open", {})
      return { kind = "door", x = nx, y = ny }
    end
    if not t.walkable then return nil end
    S.player.x, S.player.y = nx, ny
    enter_tile(S, nx, ny)
    return { kind = "move" }
  end,

  toggle_door = function(S)
    local island, defs = S.island, S.defs
    local px, py = S.player.x, S.player.y
    for _, d in ipairs({ { 0, -1 }, { 0, 1 }, { -1, 0 }, { 1, 0 } }) do
      local x, y = px + d[1], py + d[2]
      if sub.in_bounds(island, x, y) then
        local t = defs.terrain[sub.get(island, "terrain", x, y)]
        if t.door then
          if t.walkable then
            sub.set(island, "terrain", x, y, defs.tid[t.door.closes_to])
            flavor.emit("door_close", {})
          else
            sub.set(island, "terrain", x, y, defs.tid[t.door.opens_to])
            flavor.emit("door_open", {})
          end
          return { kind = "door", x = x, y = y }
        end
      end
    end
    return nil
  end,

  -- NOTE: pickup is no longer a turn action — [g] opens the transfer UI
  -- (see states/play.lua); the container at the player's feet is resolved
  -- there. Kept out of verbs so the turn loop stays action-only.

  wait = function(S)
    flavor.emit("wait", {})
    return { kind = "wait" }
  end,

  assay = function(S)
    if require("sim.discovery").assay(S) then return { kind = "assay" } end
    return nil
  end,

  submit = function(S)
    local f = sub.feature_at(S.island, S.player.x, S.player.y)
    if f and f.def.id == "extract_beacon" then
      return { kind = "submit" }
    end
    return nil
  end,
}

return M
