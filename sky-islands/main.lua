-- Sky Islands — survey-contract vertical slice. See SPEC.md.
-- main.lua is wiring only: engine callbacks in, state stack out.
local statestack = require("game.state")
local defs = require("defs")

local KEYS -- name -> engine keycode; built in _init (input exists by then)

function _config()
  ---@type Usagi.Config
  return {
    name = "Sky Islands",
    game_id = "com.ericmscott.skyislands",
    game_width = 640,
    game_height = 360,
  }
end

function _init()
  -- NOTE: Esc / P / Enter are intercepted by the engine's pause menu
  -- (pause_menu defaults true) and never reach us — don't bind them.
  KEYS = {
    up = input.KEY_UP, down = input.KEY_DOWN,
    left = input.KEY_LEFT, right = input.KEY_RIGHT,
    h = input.KEY_H, j = input.KEY_J, k = input.KEY_K, l = input.KEY_L,
    y = input.KEY_Y, u = input.KEY_U, b = input.KEY_B, n = input.KEY_N,
    g = input.KEY_G, o = input.KEY_O, i = input.KEY_I, x = input.KEY_X,
    t = input.KEY_T,
    r = input.KEY_R, q = input.KEY_Q, c = input.KEY_C, d = input.KEY_D,
    period = input.KEY_PERIOD, space = input.KEY_SPACE,
    tab = input.KEY_TAB, backspace = input.KEY_BACKSPACE,
  }

  -- debugflags.lua (gitignored, optional): a plain table of local dev
  -- flags. Absent in normal play; everything reading State.debug must
  -- be nil-safe. See CLAUDE.md "Debug flags".
  package.loaded["debugflags"] = nil -- re-read on every reset, not once per VM
  local dbg_ok, dbg = pcall(require, "debugflags")
  if not (dbg_ok and type(dbg) == "table") then dbg = nil end
  if dbg and next(dbg) == nil then dbg = nil end -- all-commented file = off

  State = {
    defs = defs.load(),
    stack = statestack.new(),
    debug = dbg,
  }
  if dbg then print("[sky-islands] DEBUG FLAGS ACTIVE - not a real playtest") end
  State.stack:push(require("game.states.titlescreen"))
  if dbg and dbg.skip_title then State.stack:key("space") end
end

function _update(dt)
  for name, code in pairs(KEYS) do
    if input.key_pressed(code) then
      State.stack:key(name)
    end
  end
  State.stack:update(dt)
end

function _draw(dt)
  State.stack:draw(dt)
end
