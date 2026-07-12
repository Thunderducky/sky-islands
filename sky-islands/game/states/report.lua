local L = require("ui.layout")
local P = require("palette")

local S = {}
S.opaque = true -- full-screen letter; nothing beneath should draw

function S.enter(self, result)
  self.r = result
end

local function row(y, label, value, lcolor, vcolor)
  L.text(20, y, label, lcolor or P.UI_TEXT)
  L.text(48, y, value, vcolor or P.WHITE)
end

function S.draw(self)
  gfx.clear(P.GRAY + 1)
  local r = self.r

  gfx.text_ex("SURVEY REPORT", 236, 24, 2, 0, P.GOLD + 5, 1.0)
  L.text(20, 4, string.format("%s - filed after %d turns",
    State.island.name, r.turns), P.BLUE + 6)

  row(6, "scouting fee", string.format("%6dc", r.fee), nil, P.GOLD + 5)
  row(7, string.format("cache bounties (%d/%d found)", r.caches_found, r.caches_total),
    string.format("%6dc", r.bounty), nil, P.GOLD + 4)

  local cov_pct = math.floor(r.coverage * 100)
  local cov_color = r.coverage >= 0.75 and P.GREEN + 5 or
      r.coverage >= 0.5 and P.GOLD + 4 or P.RED + 5
  row(8, string.format("coverage %d%%", cov_pct),
    string.format("%6dc", r.bonus), cov_color, cov_color)

  row(10, "contract total", string.format("%6dc", r.total), P.WHITE, P.WHITE)
  row(11, "company garnish", string.format("-%5dc", r.to_debt), P.RED + 4, P.RED + 4)
  row(12, "paid out to you", string.format("%6dc", r.kept), P.GREEN + 5, P.GREEN + 5)

  row(14, "goods retained (pack + hold)",
    string.format("~%5dc", r.goods_est), P.GOLD + 5, P.GOLD + 5)
  L.text(22, 15, "at store rates; sell them back home", P.UI_DIM)

  row(17, "indenture", string.format("%6dc", r.debt_before), P.RED + 4, P.RED + 4)
  row(18, "after garnish", string.format("%6dc", r.debt_after), P.RED + 5,
    r.debt_after == 0 and P.GREEN + 6 or P.RED + 5)
  row(19, "cash", string.format("%6dc", State.persist.credits), P.GOLD + 5, P.GOLD + 5)

  if r.debt_before > 0 and r.debt_after == 0 then
    gfx.text_ex("INDENTURE CLEARED", 208, L.py(22), 2, 0, P.GREEN + 6, 1.0)
    L.text(20, 24, "The paperwork is waiting back at The Tether.", P.MAGENTA + 5)
  end

  L.text(20, 26, "[R] fly home to The Tether", P.UI_TEXT)
end

function S.key(self, k)
  if k == "r" then
    if self.r.debt_before > 0 and self.r.debt_after == 0 then
      State.stack:switch(require("game.states.manumission"),
        { and_then = function() require("game.run").return_to_hub() end })
    else
      require("game.run").return_to_hub()
    end
  end
end

return S
