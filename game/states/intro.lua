local L = require("ui.layout")
local P = require("palette")

local S = {}

local TITLE = "SKY ISLANDS"

function S.draw(self)
  gfx.clear(P.GRAY + 1)

  -- title in a blue-ramp gradient, scale 2
  local tx = (640 - #TITLE * 12) // 2
  for i = 1, #TITLE do
    local step = math.min(6, 2 + ((i - 1) * 5) // #TITLE + 1)
    gfx.text_ex(TITLE:sub(i, i), tx + (i - 1) * 12, 36, 2, 0, P.BLUE + step, 1.0)
  end

  local eco = State.defs.economy
  local lines = {
    { "", 0 },
    { "The Meridian Survey Company owns your passage debt:", P.UI_TEXT },
    { string.format("%d credits, plus interest in patience.", eco.debt_start), P.RED + 5 },
    { "", 0 },
    { "The work: uncharted islands, out past the safe lanes.", P.UI_TEXT },
    { "Land. Chart. Open what you find. Come back alive.", P.UI_TEXT },
    { "", 0 },
    { string.format("CONTRACT: %dc scouting fee on completion.", eco.scouting_fee), P.GOLD + 5 },
    { string.format("          %d%% share of declared findings.", eco.proceeds_share * 100), P.GOLD + 5 },
    { string.format("          %d%% of every payout is garnished.", eco.debt_garnish * 100), P.RED + 4 },
    { "          Thorough surveys earn a coverage bonus.", P.GREEN + 5 },
    { "", 0 },
    { "Work the debt to zero and you're free.", P.MAGENTA + 5 },
  }
  for i, ln in ipairs(lines) do
    if ln[1] ~= "" then
      L.text(14, 6 + i, ln[1], ln[2])
    end
  end

  L.text(27, 26, "[ Space to take the contract ]", P.WHITE)
end

function S.key(self, k)
  if k == "space" then
    local seed = State.next_seed
    State.next_seed = State.next_seed + 1
    require("game.run").new_run(seed)
  end
end

return S
