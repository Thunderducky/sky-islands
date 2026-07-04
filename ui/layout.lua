-- The 80x30 cell geometry. Everything that positions text goes through
-- these numbers; change the grid here, nowhere else.
local L = {}

L.CELL_W, L.CELL_H = 8, 12
-- one cell of breathing room on every side: 78x28 grid + 8px/12px margins
L.MARGIN_X, L.MARGIN_Y = 8, 12
L.COLS, L.ROWS = 78, 28

L.MAP = { x = 0, y = 0, w = 56, h = 23 } -- cells
L.SIDE = { x = 57, y = 0, w = 21, h = 23 }
L.LOG = { x = 0, y = 23, w = 78, h = 5 }

function L.px(cx) return cx * L.CELL_W + L.MARGIN_X end
function L.py(cy) return cy * L.CELL_H + L.MARGIN_Y end

-- draw text at a cell position (+1px x nudges the 5px glyph toward center)
function L.text(cx, cy, s, color)
  gfx.text(s, L.px(cx) + 1, L.py(cy) + 2, color)
end

return L
