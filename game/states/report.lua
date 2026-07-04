local L = require("ui.layout")
local P = require("palette")

local S = {}

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
  row(7, string.format("findings declared (%dc)", r.findings),
    string.format("%6dc", math.floor(r.share * r.findings + 0.5)), nil, P.GOLD + 4)
  L.text(22, 8, string.format("salvage %dc, cache bounties %dc (%d/%d found)",
    r.items_value, r.bounty, r.caches_found, r.caches_total), P.UI_DIM)

  local cov_pct = math.floor(r.coverage * 100)
  local cov_color = r.coverage >= 0.75 and P.GREEN + 5 or
      r.coverage >= 0.5 and P.GOLD + 4 or P.RED + 5
  row(10, string.format("coverage %d%%", cov_pct),
    string.format("%6dc", r.bonus), cov_color, cov_color)

  row(12, "payout", string.format("%6dc", r.total), P.WHITE, P.WHITE)
  row(13, "company garnish", string.format("-%5dc", r.to_debt), P.RED + 4, P.RED + 4)
  row(14, "yours", string.format("%6dc", r.kept), P.GREEN + 5, P.GREEN + 5)

  row(17, "indenture", string.format("%6dc", r.debt_before), P.RED + 4, P.RED + 4)
  row(18, "after garnish", string.format("%6dc", r.debt_after), P.RED + 5,
    r.debt_after == 0 and P.GREEN + 6 or P.RED + 5)
  row(19, "banked", string.format("%6dc", State.persist.credits), P.GOLD + 5, P.GOLD + 5)

  if r.debt_after == 0 then
    gfx.text_ex("INDENTURE CLEARED", 208, L.py(22), 2, 0, P.GREEN + 6, 1.0)
    L.text(20, 24, "The sky is yours now. (This is as far as the prototype goes.)", P.MAGENTA + 5)
  end

  L.text(20, 27, "[R] next contract    [Q] quit", P.UI_TEXT)
end

function S.key(self, k)
  if k == "r" then
    local seed = State.next_seed
    State.next_seed = State.next_seed + 1
    require("game.run").new_run(seed)
  elseif k == "q" then
    usagi.quit()
  end
end

return S
