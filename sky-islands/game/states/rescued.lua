-- The retrieval invoice. You collapsed; the company fetched you; here is
-- what mercy costs. World state is already back at the hub (see
-- run.rescue) — this screen is just the sting.
local L = require("ui.layout")
local P = require("palette")

local S = {}

function S.enter(self, info)
  self.info = info or {}
end

function S.draw(self)
  gfx.clear(P.GRAY + 1)
  local eco = State.defs.economy
  local injured = self.info.injured

  gfx.text_ex("RETRIEVAL NOTICE", 224, 36, 2, 0, P.RED + 5, 1.0)

  local opening = injured
      and "You remember teeth, and then not much."
      or "You remember the ground coming up to meet you."
  local lines = {
    { "", 0 },
    { opening, P.UI_TEXT },
    { "Then rope, engine-drone, and the smell of the company skiff.", P.UI_TEXT },
    { "", 0 },
    { "The Meridian Survey Company is pleased to report the", P.UI_TEXT },
    { "successful retrieval of: one (1) surveyor, alive.", P.UI_TEXT },
    { "", 0 },
    { string.format("retrieval . . . . . . . . . . . . %dc", eco.rescue_fee), P.RED + 5 },
  }
  if injured then
    lines[#lines + 1] = { string.format(
      "field stabilization (medical)  . . %dc", eco.medical_fee), P.RED + 5 }
  end
  lines[#lines + 1] = { "survey contract . . . . . . . . . forfeit", P.RED + 4 }
  lines[#lines + 1] = { string.format(
    "outstanding indenture . . . . . . %dc", State.persist.debt), P.RED + 5 }
  lines[#lines + 1] = { "", 0 }
  lines[#lines + 1] = { "Your effects were recovered with you. You wake in your bunk.", P.GOLD + 4 }
  lines[#lines + 1] = { "The company thanks you for choosing to survive.", P.MAGENTA + 5 }
  for i, ln in ipairs(lines) do
    if ln[1] ~= "" then
      L.text(16, 7 + i, ln[1], ln[2])
    end
  end

  L.text(26, 25, "[ Space to wake up, poorer ]", P.WHITE)
end

function S.key(self, k)
  if k == "space" then
    State.stack:switch(require("game.states.play"))
  end
end

return S
