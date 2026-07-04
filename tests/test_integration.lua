-- Headless full-loop test: stub the engine globals, load main.lua, and
-- drive intro -> play -> overlays -> submit -> report -> restart, calling
-- _draw throughout. Catches wiring errors no unit test can see.

local function noop() end
local draw_calls = 0
local counting = function() draw_calls = draw_calls + 1 end

gfx = {
  clear = counting, text = counting, text_ex = counting,
  rect = counting, rect_fill = counting,
}
usagi = { quit = noop }
input = { key_pressed = function() return false end }
for i, name in ipairs({ "UP", "DOWN", "LEFT", "RIGHT", "H", "J", "K", "L",
  "Y", "U", "B", "N", "G", "O", "I", "X", "R", "Q",
  "PERIOD", "SPACE", "ENTER", "ESCAPE" }) do
  input["KEY_" .. name] = i
end

require("main")

local rng = require("util.rng")

return {
  full_loop = function(t)
    _config()
    _init()
    t.ok(State ~= nil, "State built")
    State.next_seed = 1234 -- deterministic island

    -- intro -> play
    State.stack:key("space")
    t.ok(State.island ~= nil, "island generated")
    t.ok(State.log:count() >= 1, "game_start narrated")
    State.stack:draw(0.016)

    -- wander deterministically; every action must be error-free
    local r = rng.new(99)
    local moves = { "h", "j", "k", "l", "y", "u", "b", "n" }
    for _ = 1, 120 do
      State.stack:key(r:pick(moves))
    end
    State.stack:key("g")
    State.stack:key("o")
    State.stack:key("period")
    State.stack:draw(0.016)
    t.ok(State.island.seen_count > 0, "fog revealed by wandering")

    -- overlays over play
    State.stack:key("i")
    State.stack:draw(0.016)
    State.stack:key("space")
    State.stack:key("x")
    State.stack:key("l")
    State.stack:key("l")
    State.stack:draw(0.016)
    State.stack:key("space")

    -- walk home: teleport is cheating, so just verify submit off-beacon
    -- does nothing, then submit from the beacon tile.
    local island = State.island
    if not (State.player.x == island.start_x and State.player.y == island.start_y) then
      State.stack:key("space")
      t.ok(State.run ~= nil and State.stack:top() ~= nil, "no submit off beacon")
    end
    State.player.x, State.player.y = island.start_x, island.start_y

    local debt_before = State.persist.debt
    State.stack:key("space")
    State.stack:draw(0.016)
    t.ok(State.persist.debt < debt_before, "garnish chipped the debt")

    -- restart from report
    local old_seed = State.island.seed
    State.stack:key("r")
    t.ok(State.island.seed ~= old_seed, "new contract, new island")
    State.stack:draw(0.016)

    t.ok(draw_calls > 100, "drawing actually happened")
  end,
}
