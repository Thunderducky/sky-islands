local defs = require("defs").load()
local sub = require("world.substrate")
local creatures = require("sim.creatures")
local flavor = require("flavor")

-- 11x11 all-grass island; place terrain by id string.
local function arena()
  local isl = sub.new_island(11, 11)
  for y = 0, 10 do
    for x = 0, 10 do
      sub.set(isl, "terrain", x, y, defs.tid["grass"])
    end
  end
  isl.seed = 1
  isl.creatures = {}
  return isl
end

local function put(isl, id, x, y)
  local d = defs.creature_by_id[id]
  local c = { def = d, x = x, y = y, hp = d.max_hp, mp = 0, state = "wander" }
  isl.creatures[#isl.creatures + 1] = c
  return c
end

local function fake_S(isl, px, py)
  flavor.init({ pools = {}, rng = { int = function() return 1 end },
    sink = function() end })
  return {
    island = isl, defs = defs, master = 42, clock = { turn = 1 },
    player = { x = px, y = py, hp = 20, inv = {} },
    persist = {}, skiff = { hold = {} },
  }
end

-- deterministic rng stub: always hits, max damage, never idles
local SURE = {
  chance = function(_, p) return p > 0 end,
  int = function(_, lo, hi) return hi end,
}

return {
  sees_across_open_ground = function(t)
    local isl = arena()
    t.ok(creatures.tile_visible(isl, defs, 1, 5, 8, 5, 9))
    t.ok(not creatures.tile_visible(isl, defs, 1, 5, 8, 5, 5), "radius clips")
  end,

  wall_blocks_sight = function(t)
    local isl = arena()
    sub.set(isl, "terrain", 4, 5, defs.tid["wall_plank"])
    t.ok(not creatures.tile_visible(isl, defs, 1, 5, 8, 5, 9))
  end,

  concealment_is_about_the_target_tile = function(t)
    local isl = arena()
    sub.set(isl, "terrain", 8, 5, defs.tid["bush"])
    -- target in a bush: hidden at range, seen when adjacent
    t.ok(not creatures.tile_visible(isl, defs, 1, 5, 8, 5, 9))
    t.ok(creatures.tile_visible(isl, defs, 7, 5, 8, 5, 9))
    -- and looking OUT of the bush at open ground works fine
    t.ok(creatures.tile_visible(isl, defs, 8, 5, 1, 5, 9))
  end,

  hunts_toward_the_player = function(t)
    local isl = arena()
    local c = put(isl, "rim_shrike", 1, 5)
    local S = fake_S(isl, 8, 5)
    creatures.act(S, c, SURE)
    t.eq(c.state, "hunt")
    t.eq(c.x, 2, "stepped toward the player")
  end,

  loses_you_in_a_thicket_and_gives_up = function(t)
    local isl = arena()
    sub.set(isl, "terrain", 8, 8, defs.tid["bush"])
    local c = put(isl, "rim_shrike", 1, 5)
    local S = fake_S(isl, 7, 5)
    creatures.act(S, c, SURE) -- spotted in the open: hunt, last_seen (7,5)
    t.eq(c.state, "hunt")
    S.player.x, S.player.y = 8, 8 -- duck into the bush
    for _ = 1, 12 do creatures.act(S, c, SURE) end
    -- it searched where you were, couldn't see into the thicket, gave up
    t.eq(c.state, "wander", "search of last_seen exhausted")
    t.ok(not (c.x == 8 and c.y == 8), "didn't magically walk to your hide")
  end,

  docile_ignores_you_until_hurt = function(t)
    local isl = arena()
    local c = put(isl, "dust_hen", 3, 5)
    local S = fake_S(isl, 5, 5)
    creatures.act(S, c, SURE)
    t.ok(c.state ~= "hunt", "dust-hen doesn't care about you")
    creatures.player_attack(S, c, 1) -- whatever the roll, it's awake now
    t.eq(c.state, "hunt", "retaliates once hurt")
  end,

  adjacent_hunter_attacks = function(t)
    local isl = arena()
    local c = put(isl, "thorn_hog", 5, 4)
    local S = fake_S(isl, 5, 5)
    creatures.act(S, c, SURE)
    t.ok(S.player.hp < 20, "adjacent + hostile = damage")
  end,

  debug_invulnerable_skips_the_wound = function(t)
    local isl = arena()
    local c = put(isl, "thorn_hog", 5, 4)
    local S = fake_S(isl, 5, 5)
    S.debug = { invulnerable = true }
    creatures.act(S, c, SURE)
    t.eq(S.player.hp, 20, "sure hit, no wound")
  end,

  debug_docile_creatures_never_hunt = function(t)
    local isl = arena()
    local c = put(isl, "thorn_hog", 5, 4)
    c.state = "hunt" -- even an angry one calms down
    local S = fake_S(isl, 5, 5)
    S.debug = { docile_creatures = true }
    creatures.act(S, c, SURE)
    t.eq(S.player.hp, 20, "adjacent hostile never swings")
    t.eq(c.state, "wander", "grudge dropped")
  end,

  kill_drops_and_removes = function(t)
    local isl = arena()
    local c = put(isl, "dust_hen", 5, 4)
    local S = fake_S(isl, 5, 5)
    c.hp = 1
    -- swing until the derived stream lands a hit (acc 0.8)
    for turn = 1, 20 do
      S.clock.turn = turn
      if #isl.creatures == 0 then break end
      creatures.player_attack(S, isl.creatures[1], 1)
    end
    t.eq(#isl.creatures, 0, "dead and gone")
    t.ok(sub.pile_at(isl, 5, 4) ~= nil, "dust-hen drops meat (chance 0.9, many rolls)")
  end,

  phase_is_deterministic = function(t)
    local function run_phase()
      local isl = arena()
      put(isl, "rim_shrike", 1, 1)
      put(isl, "dust_hen", 9, 9)
      local S = fake_S(isl, 5, 5)
      for turn = 1, 10 do
        S.clock.turn = turn
        creatures.phase(S)
      end
      local out = {}
      for _, c in ipairs(isl.creatures) do
        out[#out + 1] = { c.def.id, c.x, c.y, c.state }
      end
      return out
    end
    t.deep_eq(run_phase(), run_phase(), "same master+turns, same dance")
  end,
}
