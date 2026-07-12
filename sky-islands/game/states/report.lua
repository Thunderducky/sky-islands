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

  -- flowing layout: optional blocks (notable features, manumission)
  -- push what follows instead of overlapping it
  local y = 6
  local function put(label, value, lcolor, vcolor)
    row(y, label, value, lcolor, vcolor)
    y = y + 1
  end

  put("scouting fee", string.format("%6dc", r.fee), nil, P.GOLD + 5)
  put(string.format("cache bounties (%d/%d found)", r.caches_found, r.caches_total),
    string.format("%6dc", r.bounty), nil, P.GOLD + 4)

  local cov_pct = math.floor(r.coverage * 100)
  local cov_color = r.coverage >= 0.75 and P.GREEN + 5 or
      r.coverage >= 0.5 and P.GOLD + 4 or P.RED + 5
  put(string.format("coverage %d%%", cov_pct),
    string.format("%6dc", r.bonus), cov_color, cov_color)

  if r.notable and #r.notable > 0 then
    put(string.format("notable features (%d)", #r.notable),
      string.format("%6dc", r.notable_bounty), P.MAGENTA + 5, P.MAGENTA + 5)
    local names = table.concat(r.notable, ", ")
    if #names > 54 then names = names:sub(1, 51) .. "..." end
    L.text(22, y, names, P.MAGENTA + 4)
    y = y + 1
  end
  y = y + 1

  put("contract total", string.format("%6dc", r.total), P.WHITE, P.WHITE)
  put("company garnish", string.format("-%5dc", r.to_debt), P.RED + 4, P.RED + 4)
  put("paid out to you", string.format("%6dc", r.kept), P.GREEN + 5, P.GREEN + 5)
  y = y + 1

  put("goods retained (pack + hold)",
    string.format("~%5dc", r.goods_est), P.GOLD + 5, P.GOLD + 5)
  L.text(22, y, "at store rates; sell them back home", P.UI_DIM)
  y = y + 2

  put("indenture", string.format("%6dc", r.debt_before), P.RED + 4, P.RED + 4)
  put("after garnish", string.format("%6dc", r.debt_after), P.RED + 5,
    r.debt_after == 0 and P.GREEN + 6 or P.RED + 5)
  put("cash", string.format("%6dc", State.persist.credits), P.GOLD + 5, P.GOLD + 5)

  if r.debt_before > 0 and r.debt_after == 0 then
    gfx.text_ex("INDENTURE CLEARED", 208, L.py(y + 1), 2, 0, P.GREEN + 6, 1.0)
    L.text(20, y + 2, "The paperwork is waiting back at The Tether.", P.MAGENTA + 5)
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
