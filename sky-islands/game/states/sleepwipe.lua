-- Sleep transition: a black wipe rolls in, the night passes at full
-- cover (game.run.sleep() fires there — save, healing, hunger), and the
-- screen holds dark until the player presses Space to rise; morning
-- then chases the dark off to the right. Pure presentation; every sim
-- effect stays in sleep().
local P = require("palette")

local S = {}

local W, H = 640, 360
local IN_T, OUT_T = 0.35, 0.35

function S.enter(self)
  self.t = 0
  self.phase = "in" -- in -> hold (until Space) -> out
end

function S.update(self, dt)
  self.t = self.t + dt
  if self.phase == "in" and self.t >= IN_T then
    self.phase = "hold"
    require("game.run").sleep()
  elseif self.phase == "out" and self.t >= OUT_T then
    State.stack:pop()
  end
end

function S.key(self, k)
  -- the night lasts as long as you let it
  if self.phase == "hold" and k == "space" then
    self.phase = "out"
    self.t = 0
  end
end

function S.draw(self)
  if self.phase == "in" then
    local w = math.floor(W * math.min(1, self.t / IN_T) + 0.5)
    gfx.rect_fill(0, 0, w, H, P.BLACK)
  elseif self.phase == "hold" then
    gfx.rect_fill(0, 0, W, H, P.BLACK)
    gfx.text("you sleep.", 290, 168, P.GRAY + 6)
    gfx.text("[Space] rise", 284, 190, P.GRAY + 5)
  else
    local k = math.min(1, self.t / OUT_T)
    local x = math.floor(W * k + 0.5)
    gfx.rect_fill(x, 0, W - x, H, P.BLACK)
  end
end

return S
