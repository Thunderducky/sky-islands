-- The very first thing the player sees. Full-bleed art (from
-- art-src/, baked into sprites.png by art-src/pack.py) with a solid
-- banner and the title, then Space -> the instruction screen.
--
-- The banner is a plain opaque fill, not real transparency: the
-- engine's fills are palette-indexed with no alpha channel, so a true
-- see-through scrim would mean either a dithered checkerboard (tried
-- it — reads as a harsh black/color checker at this resolution, not a
-- soft haze) or an engine-level blend mode. Not worth an engine dive
-- for a title banner; a solid panel is simpler and looks cleaner.
local P = require("palette")
local ok_art, art = pcall(require, "defs.art")

local S = {}

local TITLE = "SKY ISLANDS"
local PROMPT = "[ Space ]"

function S.draw(self)
  gfx.clear(P.GRAY + 1) -- fallback if art didn't pack yet
  if ok_art and art.TitleScreen then
    local t = art.TitleScreen
    -- source is 640x320 today; scale to fill the 640x360 canvas rather
    -- than guess at a fallback color for a 40px gap. Swap to gfx.sspr
    -- (native scale, no stretch) once the source is exported at 640x360.
    gfx.sspr_ex(t.x, t.y, t.w, t.h, 0, 0, 640, 360,
      false, false, 0, gfx.COLOR_TRUE_WHITE, 1.0)
  end

  local band_h = 140
  local band_y = (360 - band_h) // 2
  gfx.rect_fill(0, band_y, 640, band_h, P.GRAY + 2)

  -- per-letter blue gradient, matching the title treatment on the
  -- instruction screen — same brand, bigger stage.
  local scale, advance = 4, 24
  local tx = (640 - #TITLE * advance) // 2
  local ty = band_y + band_h // 2 - 14
  for i = 1, #TITLE do
    local step = math.min(6, 2 + ((i - 1) * 5) // #TITLE + 1)
    gfx.text_ex(TITLE:sub(i, i), tx + (i - 1) * advance, ty, scale, 0,
      P.BLUE + step, 1.0)
  end

  local pw = usagi.measure_text(PROMPT)
  gfx.text(PROMPT, (640 - pw) // 2, 330, P.WHITE)
end

function S.key(self, k)
  if k == "space" then
    State.stack:switch(require("game.states.intro"))
  end
end

return S
