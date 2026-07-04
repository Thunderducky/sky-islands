-- Narration engine. Pure Lua, no engine calls.
--
-- flavor.init(opts) where opts = {
--   pools = <events table, see format below>,
--   rng = <object with :int(lo, hi)>,
--   sink = function(text, color) end,
-- }
--
-- Pools format (provided by defs/flavor.lua, not created here):
--   events = {
--     cache_open = {
--       color = 23,
--       templates = { "You pry the {feature} open - {contents}.", ... },
--     },
--     ...
--   }

local M = {}

local pools = nil
local rng = nil
local sink = nil
local last_index = {} -- event_key -> last template index picked
local fired_once = {} -- event_key -> true once emit_once has fired

--- Initialize (or reset) the flavor engine.
-- @param opts { pools = table, rng = object with :int(lo,hi), sink = function }
function M.init(opts)
  opts = opts or {}
  pools = opts.pools or {}
  rng = opts.rng
  sink = opts.sink
  last_index = {}
  fired_once = {}
end

-- Substitute every {name} in template with tostring(slots[name]);
-- missing slots become "???".
local function fill(template, slots)
  slots = slots or {}
  local result = template:gsub("{(%w+)}", function(name)
    local value = slots[name]
    if value == nil then
      return "???"
    end
    return tostring(value)
  end)
  return result
end

-- Pick a template index for the given pool, honoring anti-repeat when the
-- pool has more than one template.
local function pick_index(event_key, pool)
  local n = #pool.templates
  if n <= 1 then
    return 1
  end
  local prev = last_index[event_key]
  local idx = rng:int(1, n)
  if prev ~= nil and idx == prev then
    -- Anti-repeat: never pick the same template twice in a row.
    idx = (idx % n) + 1
  end
  return idx
end

--- Emit a flavor event, substituting slots into a chosen template and
-- calling the sink with the filled text and pool color.
-- @param event_key string
-- @param slots table of string/number values (optional)
function M.emit(event_key, slots)
  local pool = pools[event_key]
  if pool == nil then
    sink("[flavor missing: " .. tostring(event_key) .. "]", nil)
    return
  end

  local idx = pick_index(event_key, pool)
  last_index[event_key] = idx
  local template = pool.templates[idx]

  local text = fill(template, slots)
  sink(text, pool.color)
end

--- Same as emit, but fires at most once per init() call for a given key.
-- @param event_key string
-- @param slots table of string/number values (optional)
function M.emit_once(event_key, slots)
  if fired_once[event_key] then
    return
  end
  fired_once[event_key] = true
  M.emit(event_key, slots)
end

return M
