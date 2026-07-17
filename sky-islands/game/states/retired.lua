-- The placeholder ending (SI-0006a): passage bought at the Core, out of
-- the sector for good. Explicitly temporary — the real escape routes
-- through the faction race (SI-0008, DESIGN.md endings).
local L = require("ui.layout")
local P = require("palette")

local S = {}
S.opaque = true

function S.draw(self)
  gfx.clear(P.GRAY + 1)
  gfx.text_ex("PASSAGE BOOKED", 220, 60, 2, 0, P.GREEN + 6, 1.0)
  L.text(14, 9, "The liner is bigger than the Tether. The berth is small,", P.UI_TEXT)
  L.text(14, 10, "paid, and yours. Below, the archipelago tilts away -", P.UI_TEXT)
  L.text(14, 11, "islands, wards, ledgers, all of it somebody else's", P.UI_TEXT)
  L.text(14, 12, "problem now.", P.UI_TEXT)
  L.text(14, 14, "You came here owing " .. State.defs.economy.debt_start ..
    "c. You leave owning yourself.", P.GOLD + 5)
  L.text(14, 17, "THE SURVEYOR RETIRES", P.MAGENTA + 5)
  L.text(14, 20, "(Whatever holds the islands up is still failing.", P.UI_DIM)
  L.text(14, 21, " Someone else will have to decide what that means.)", P.UI_DIM)
  L.text(14, 24, "[Space] return to the title", P.UI_TEXT)
end

function S.key(self, k)
  if k == "space" then
    State.stack:switch(require("game.states.titlescreen"))
  end
end

return S
