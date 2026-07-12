local needs = require("sim.needs")
local flavor = require("flavor")

local ECO = {
  hunger = { per_turn = 1, peckish = 150, hungry = 300, starving = 500, collapse = 700 },
  player = { max_hp = 20 },
  regen_turns = 10,
}

local function fake_state(hunger, inv)
  return {
    defs = {
      economy = ECO,
      item_by_id = {
        ration = { name = "ration", nutrition = 250 },
        rock = { name = "rock" },
        bandage = { name = "bandage", heal = 8 },
      },
    },
    clock = { turn = 1 },
    player = { inv = inv or {}, hunger = hunger,
      hunger_state = needs.state(hunger, ECO), hp = 20 },
  }
end

local function init_flavor()
  local lines = {}
  flavor.init({
    pools = {},
    rng = { int = function() return 1 end },
    sink = function(text) lines[#lines + 1] = text end,
  })
  return lines
end

return {
  state_thresholds = function(t)
    t.eq(needs.state(0, ECO), "full")
    t.eq(needs.state(149, ECO), "full")
    t.eq(needs.state(150, ECO), "peckish")
    t.eq(needs.state(299, ECO), "peckish")
    t.eq(needs.state(300, ECO), "hungry")
    t.eq(needs.state(500, ECO), "starving")
    t.eq(needs.state(9999, ECO), "starving")
  end,

  tick_advances_and_warns_on_worsening = function(t)
    local lines = init_flavor()
    local S = fake_state(299)
    needs.tick(S)
    t.eq(S.player.hunger, 300)
    t.eq(S.player.hunger_state, "hungry")
    t.eq(#lines, 1, "crossing a threshold warns once")
    needs.tick(S)
    t.eq(#lines, 1, "staying in a state doesn't repeat the warning")
  end,

  debug_no_hunger_freezes_the_clock = function(t)
    init_flavor()
    local S = fake_state(699) -- one tick from collapse
    S.debug = { no_hunger = true }
    t.eq(needs.tick(S), false, "no collapse with the clock frozen")
    t.eq(S.player.hunger, 699, "hunger unchanged")
    S.debug = nil
    t.eq(needs.tick(S), true, "flag off: the clock resumes and collapses")
  end,

  regen_slow_and_gated_on_starving = function(t)
    init_flavor()
    local S = fake_state(0)
    S.player.hp = 10
    S.clock.turn = 9
    needs.tick(S) -- turn 9 -> hunger 1... tick doesn't advance clock; 9 % 10 ~= 0
    t.eq(S.player.hp, 10, "no regen off the beat")
    S.clock.turn = 10
    needs.tick(S)
    t.eq(S.player.hp, 11, "+1 on the regen beat")
    S.player.hunger = 600 -- starving
    S.player.hunger_state = "starving"
    S.clock.turn = 20
    needs.tick(S)
    t.eq(S.player.hp, 11, "starving stops regen")
    S.player.hp = 20
    S.player.hunger = 0
    S.player.hunger_state = "full"
    S.clock.turn = 30
    needs.tick(S)
    t.eq(S.player.hp, 20, "never past max")
  end,

  bandage_heals_and_refuses_at_full = function(t)
    init_flavor()
    local S = fake_state(0, { { id = "bandage", n = 2 } })
    S.player.hp = 20
    t.ok(not needs.use(S, 1), "refused at full hp")
    t.eq(S.player.inv[1].n, 2, "not consumed when refused")
    S.player.hp = 5
    t.ok(needs.use(S, 1))
    t.eq(S.player.hp, 13)
    t.eq(S.player.inv[1].n, 1)
    S.player.hp = 18
    t.ok(needs.use(S, 1))
    t.eq(S.player.hp, 20, "heal clamps at max")
    t.eq(#S.player.inv, 0, "stack consumed")
  end,

  tick_signals_collapse_at_the_line = function(t)
    init_flavor()
    local S = fake_state(698)
    t.ok(not needs.tick(S), "699 is still upright")
    t.ok(needs.tick(S), "700 is the floor coming up to meet you")
  end,

  eat_reduces_hunger_and_consumes = function(t)
    init_flavor()
    local S = fake_state(400, { { id = "ration", n = 2 }, { id = "rock", n = 1 } })
    t.ok(needs.eat(S, 1))
    t.eq(S.player.hunger, 150)
    t.eq(S.player.hunger_state, "peckish")
    t.eq(S.player.inv[1].n, 1)
    t.ok(needs.eat(S, 1))
    t.eq(S.player.hunger, 0)
    t.eq(#S.player.inv, 1, "empty stack removed")
    t.eq(S.player.inv[1].id, "rock")
  end,

  inedible_refused = function(t)
    init_flavor()
    local S = fake_state(400, { { id = "rock", n = 1 } })
    t.ok(not needs.eat(S, 1))
    t.eq(S.player.hunger, 400, "hunger unchanged")
    t.eq(S.player.inv[1].n, 1, "rock not consumed")
  end,

  hunger_can_get_hungry_again_after_eating = function(t)
    local lines = init_flavor()
    local S = fake_state(310, { { id = "ration", n = 1 } })
    needs.tick(S) -- already hungry, no new warning
    t.eq(#lines, 0)
    needs.eat(S, 1)   -- back to peckish-ish
    S.player.hunger = 299
    S.player.hunger_state = needs.state(299, ECO)
    needs.tick(S)     -- crosses into hungry AGAIN
    t.eq(lines[#lines] ~= nil, true, "re-crossing warns again")
  end,
}
