-- Creature AI + combat. v0 per SPEC: attack-on-sight + wander, greedy
-- pursuit via last_seen, symmetric concealment. Deliberately dumb;
-- dijkstra.lua is the upgrade path.
local sub = require("world.substrate")
local G = require("util.grid")
local rng = require("util.rng")
local flavor = require("flavor")

local M = {}

local function cheb(ax, ay, bx, by)
  return math.max(math.abs(ax - bx), math.abs(ay - by))
end

function M.at(island, x, y)
  for i, c in ipairs(island.creatures or {}) do
    if c.x == x and c.y == y then return c, i end
  end
end

local function terr(island, defs, x, y)
  return defs.terrain[sub.get(island, "terrain", x, y)]
end

-- Symmetric visibility between two tiles: within radius, clear ray
-- (intermediate tiles transparent), and the concealment rule — whatever
-- stands on concealing terrain is invisible beyond adjacency.
function M.tile_visible(island, defs, fx, fy, tx, ty, radius)
  local d = cheb(fx, fy, tx, ty)
  if d > radius then return false end
  if d > 1 and terr(island, defs, tx, ty).conceals then return false end
  local line = G.line(fx, fy, tx, ty)
  for i = 2, #line - 1 do
    if terr(island, defs, line[i].x, line[i].y).opaque then return false end
  end
  return true
end

-- Can the player see this creature? (fog + the same concealment rule.)
function M.visible_to_player(S, c)
  local island = S.island
  if sub.get(island, "fog", c.x, c.y) ~= 2 then return false end
  if terr(island, S.defs, c.x, c.y).conceals
      and cheb(S.player.x, S.player.y, c.x, c.y) > 1 then
    return false
  end
  return true
end

local function free(S, x, y)
  local island = S.island
  if not sub.in_bounds(island, x, y) then return false end
  if not terr(island, S.defs, x, y).walkable then return false end
  if M.at(island, x, y) then return false end
  if S.player.x == x and S.player.y == y then return false end
  return true
end

local function step_toward(S, c, tx, ty)
  local dx, dy = tx - c.x, ty - c.y
  local sx = dx > 0 and 1 or dx < 0 and -1 or 0
  local sy = dy > 0 and 1 or dy < 0 and -1 or 0
  local tries
  if math.abs(dx) >= math.abs(dy) then
    tries = { { sx, sy }, { sx, 0 }, { 0, sy } }
  else
    tries = { { sx, sy }, { 0, sy }, { sx, 0 } }
  end
  for _, t in ipairs(tries) do
    if (t[1] ~= 0 or t[2] ~= 0) and free(S, c.x + t[1], c.y + t[2]) then
      c.x, c.y = c.x + t[1], c.y + t[2]
      return
    end
  end
end

local function creature_attack(S, c, r)
  local def = c.def
  if r:chance(def.acc) then
    local dmg = r:int(def.damage[1], def.damage[2])
    S.player.hp = S.player.hp - dmg
    flavor.emit("creature_hit", { name = def.name, dmg = dmg })
  else
    flavor.emit("creature_miss", { name = def.name })
  end
end

-- One creature action. r is injected (derived per creature-turn by
-- phase(), stubbed in tests).
function M.act(S, c, r)
  local island, defs = S.island, S.defs
  local def = c.def
  local px, py = S.player.x, S.player.y

  local radius = def.aggro_radius
  if radius == 0 and c.state == "hunt" then
    radius = 8 -- a hurt docile creature fights back with open eyes
  end
  local sees = radius > 0 and
      M.tile_visible(island, defs, c.x, c.y, px, py, radius)

  if sees then
    if c.state ~= "hunt" then
      flavor.emit("creature_notice", { name = def.name })
    end
    c.state = "hunt"
    c.last_x, c.last_y = px, py
  end

  if c.state == "hunt" then
    if cheb(c.x, c.y, px, py) <= 1 then
      creature_attack(S, c, r)
      return
    end
    if c.last_x then
      step_toward(S, c, c.last_x, c.last_y)
      if c.x == c.last_x and c.y == c.last_y and not sees then
        -- searched where you were; you weren't
        c.state = "wander"
        c.last_x, c.last_y = nil, nil
      end
      return
    end
    c.state = "wander"
  end

  -- wander: half the time, a random walkable step
  if r:chance(0.5) then
    local dirs = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 },
      { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }
    local d = dirs[r:int(1, 8)]
    if free(S, c.x + d[1], c.y + d[2]) then
      c.x, c.y = c.x + d[1], c.y + d[2]
    end
  end
end

-- The creature phase of every world turn. Determinism: each action
-- draws from a stream derived purely from (master, island, creature,
-- turn, mp) — nothing to save, replays exactly.
function M.phase(S)
  local island = S.island
  if not island.creatures then return end
  for i, c in ipairs(island.creatures) do
    c.mp = (c.mp or 0) + (c.def.speed or 100)
    while c.mp >= 100 do
      c.mp = c.mp - 100
      local r = rng.derive(S.master, "ai:" .. island.seed .. ":" .. i
        .. ":" .. S.clock.turn .. ":" .. c.mp)
      M.act(S, c, r)
      if S.player.hp <= 0 then return end
    end
  end
end

-- Player bump attack. ci is the creature's index in island.creatures.
function M.player_attack(S, c, ci)
  local pl = S.defs.economy.player
  local def = c.def
  local r = rng.derive(S.master, "combat:" .. S.clock.turn)
  -- getting hit wakes anything up, hit or miss
  c.state = "hunt"
  c.last_x, c.last_y = S.player.x, S.player.y
  if not r:chance(pl.acc) then
    flavor.emit("miss", { name = def.name })
    return
  end
  local dmg = r:int(pl.damage[1], pl.damage[2])
  c.hp = c.hp - dmg
  if c.hp > 0 then
    flavor.emit("hit", { name = def.name, dmg = dmg })
    return
  end
  for _, dr in ipairs(def.drops or {}) do
    if r:chance(dr.chance) then
      sub.add_item(S.island, c.x, c.y, { id = dr.item, n = r:int(dr.min, dr.max) })
    end
  end
  table.remove(S.island.creatures, ci)
  flavor.emit("kill", { name = def.name })
end

return M
