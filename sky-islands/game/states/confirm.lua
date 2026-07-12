-- Generic y/n confirm overlay. Push with { text = "...", on_yes = fn }.
-- Deliberately does NOT accept Space: the actions worth confirming are
-- triggered by Space, and a double-tap shouldn't blow through the guard.
local L = require("ui.layout")
local P = require("palette")

local S = {}

local BOX_X, BOX_W = 16, 46 -- cells

-- opts.extra_keys = { [key] = fn } lets a caller add detour actions
-- (e.g. g = open the skiff hold before deciding); the confirm pops
-- itself first, so the player returns to the prompt by re-interacting.
-- opts.extra_hint is the matching hint line.
function S.enter(self, opts)
  self.text = opts.text
  self.on_yes = opts.on_yes
  self.extra_keys = opts.extra_keys
  self.extra_hint = opts.extra_hint
end

function S.key(self, k)
  if k == "y" then
    local yes = self.on_yes
    State.stack:pop()
    yes()
  elseif k == "n" or k == "backspace" then
    State.stack:pop()
  elseif self.extra_keys and self.extra_keys[k] then
    local fn = self.extra_keys[k]
    State.stack:pop()
    fn()
  end
end

function S.draw(self)
  local top_y = 11
  local rows = self.extra_hint and 5 or 4
  local px, py = L.px(BOX_X), L.py(top_y)
  local pw, ph = BOX_W * L.CELL_W, rows * L.CELL_H
  gfx.rect_fill(px - 4, py - 4, pw + 8, ph + 8, P.GRAY + 2)
  gfx.rect(px - 4, py - 4, pw + 8, ph + 8, P.GOLD + 4)
  L.text(BOX_X + 1, top_y + 1, self.text, P.UI_TEXT)
  L.text(BOX_X + 1, top_y + 3, "[Y] yes   [N] no", P.UI_DIM)
  if self.extra_hint then
    L.text(BOX_X + 1, top_y + 4, self.extra_hint, P.UI_DIM)
  end
end

return S
