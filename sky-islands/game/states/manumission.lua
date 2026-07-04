-- The debt hits zero. The company's coldest, tersest letter — the
-- counterpart to the retrieval invoice. Reached from either payment
-- path: settlement garnish or the store counter.
local L = require("ui.layout")
local P = require("palette")
local flavor = require("flavor")

local S = {}

function S.enter(self, opts)
  self.opts = opts or {}
  flavor.emit("manumitted", {})
end

function S.draw(self)
  gfx.clear(P.GRAY + 1)

  gfx.text_ex("ACCOUNT CLOSED", 232, 36, 2, 0, P.GREEN + 6, 1.0)

  local lines = {
    { "", 0 },
    { "The Meridian Survey Company confirms receipt in full.", P.UI_TEXT },
    { "", 0 },
    { "indenture . . . . . . . . . . . . . . 0c", P.GREEN + 6 },
    { "status  . . . . . . . . . . . . . . . FREE AGENT", P.GREEN + 6 },
    { "", 0 },
    { "No ceremony is scheduled. The clerk has already filed you", P.UI_TEXT },
    { "under 'former'.", P.UI_TEXT },
    { "", 0 },
    { "The company reminds you that contracts remain available to", P.GOLD + 4 },
    { "free agents at full payout, and that the skiff lease, bunk,", P.GOLD + 4 },
    { "and retrieval services remain billable.", P.GOLD + 4 },
    { "", 0 },
    { "Stay fed. Stay stitched. Owe no one.", P.MAGENTA + 5 },
    { "", 0 },
    { "You came here with a debt. The sky is yours now.", P.BLUE + 6 },
  }
  for i, ln in ipairs(lines) do
    if ln[1] ~= "" then
      L.text(15, 6 + i, ln[1], ln[2])
    end
  end

  L.text(28, 26, "[ Space, free agent ]", P.WHITE)
end

function S.key(self, k)
  if k == "space" then
    if self.opts.and_then then
      self.opts.and_then()
    else
      State.stack:pop()
    end
  end
end

return S
