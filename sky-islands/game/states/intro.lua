local L = require("ui.layout")
local P = require("palette")

local S = {}

function S.enter(self)
  self.saved = require("game.save").read()
end

function S.draw(self)
  gfx.clear(P.GRAY + 1)

  -- no title header here — the previous screen (titlescreen.lua) already
  -- showed it; repeating it back-to-back would read as a mistake.
  local eco = State.defs.economy
  local lines = {
    { "", 0 },
    { "The Meridian Survey Company owns your passage debt:", P.UI_TEXT },
    { string.format("%d credits, plus interest in patience.", eco.debt_start), P.RED + 5 },
    { "", 0 },
    { "They gave you a bunk on The Tether, a leased skiff,", P.UI_TEXT },
    { "and a standing offer: uncharted islands, out past the", P.UI_TEXT },
    { "safe lanes. Land. Chart. Come back alive.", P.UI_TEXT },
    { "", 0 },
    { string.format("%d%% of every payout is garnished for the debt.", eco.debt_garnish * 100), P.RED + 4 },
    { "What you haul back is yours - to sell at their store,", P.GOLD + 5 },
    { "at their prices.", P.GOLD + 5 },
    { "", 0 },
    { "Work the debt to zero and you're free.", P.MAGENTA + 5 },
  }
  for i, ln in ipairs(lines) do
    if ln[1] ~= "" then
      L.text(14, 6 + i, ln[1], ln[2])
    end
  end

  if self.saved then
    L.text(22, 26, "[N] new debtor      [C] continue where you slept", P.WHITE)
  else
    L.text(27, 26, "[ Space to take the contract ]", P.WHITE)
  end
end

function S.key(self, k)
  local run = require("game.run")
  if self.saved then
    if k == "n" then
      run.new_game((os and os.time and os.time() or 20260704) % 1000000)
    elseif k == "c" then
      run.continue_game(self.saved)
    end
  elseif k == "space" or k == "n" then
    run.new_game((os and os.time and os.time() or 20260704) % 1000000)
  end
end

return S
