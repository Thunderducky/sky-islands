-- tests/run.lua
-- Tiny test runner. Run as `lua tests/run.lua` from the project root, or
-- `lua run.lua` from inside tests/ — both are supported.
--
-- Discovery: every tests/test_*.lua file must return a table mapping
-- test-name-string -> function(t). We shell out (io.popen) to `ls` to find
-- them, since we don't want a hard dependency on a filesystem library.

-- Derive the tests/ dir and project root from arg[0], regardless of which
-- directory the script was invoked from.
local function dirname(path)
  local d = path:match("^(.*)[/\\][^/\\]*$")
  return d or "."
end

local script_path = arg[0] or "run.lua"
-- Normalize to an absolute-ish path: if arg[0] has no directory component,
-- it was run as `lua run.lua` from within tests/.
local script_dir = dirname(script_path)
if script_dir == script_path then
  -- No directory separator found at all; treat as "."
  script_dir = "."
end

-- tests_dir is wherever this file lives. project root is tests_dir/..,
-- unless this file was invoked directly from the root as tests/run.lua
-- (in which case script_dir already IS "<root>/tests").
local tests_dir = script_dir
local project_root = tests_dir .. "/.."

-- Fix package.path so require("util.rng") etc. resolve from project root.
package.path = project_root .. "/?.lua;"
    .. project_root .. "/?/init.lua;"
    .. package.path

-- ---------------------------------------------------------------------
-- Assertion helpers passed to each test function as `t`.
-- ---------------------------------------------------------------------

local function tostr(v)
  if type(v) == "table" then
    local parts = {}
    -- best-effort shallow dump, array part first
    local n = #v
    for i = 1, n do
      parts[#parts + 1] = tostr(v[i])
    end
    for k, val in pairs(v) do
      if not (math.type(k) == "integer" and k >= 1 and k <= n) then
        parts[#parts + 1] = tostring(k) .. "=" .. tostr(val)
      end
    end
    return "{" .. table.concat(parts, ", ") .. "}"
  end
  return tostring(v)
end

local function deep_eq(a, b)
  if a == b then return true end
  if type(a) ~= "table" or type(b) ~= "table" then return false end
  for k, v in pairs(a) do
    if not deep_eq(v, b[k]) then return false end
  end
  for k in pairs(b) do
    if a[k] == nil then return false end
  end
  return true
end

local function make_t()
  local t = {}

  function t.eq(got, expected, msg)
    if got ~= expected then
      error(string.format(
        "%sexpected <%s> but got <%s>",
        msg and (msg .. ": ") or "",
        tostr(expected), tostr(got)
      ), 2)
    end
  end

  function t.ok(cond, msg)
    if not cond then
      error(msg or "expected condition to be truthy", 2)
    end
  end

  function t.near(got, expected, eps, msg)
    eps = eps or 1e-9
    if math.abs(got - expected) > eps then
      error(string.format(
        "%sexpected <%s> near (eps=%s) but got <%s>",
        msg and (msg .. ": ") or "",
        tostr(expected), tostr(eps), tostr(got)
      ), 2)
    end
  end

  function t.deep_eq(got, expected, msg)
    if not deep_eq(got, expected) then
      error(string.format(
        "%sexpected <%s> but got <%s>",
        msg and (msg .. ": ") or "",
        tostr(expected), tostr(got)
      ), 2)
    end
  end

  return t
end

-- ---------------------------------------------------------------------
-- Discovery
-- ---------------------------------------------------------------------

local function find_test_files(dir)
  local files = {}
  local cmd = string.format('ls "%s" 2>/dev/null', dir)
  local pipe = io.popen(cmd)
  if pipe then
    for line in pipe:lines() do
      if line:match("^test_.*%.lua$") then
        files[#files + 1] = dir .. "/" .. line
      end
    end
    pipe:close()
  end
  table.sort(files)
  return files
end

-- ---------------------------------------------------------------------
-- Run
-- ---------------------------------------------------------------------

local files = find_test_files(tests_dir)

local total_passed = 0
local total_failed = 0

for _, filepath in ipairs(files) do
  local filename = filepath:match("([^/\\]+)$") or filepath
  local chunk, load_err = loadfile(filepath)
  if not chunk then
    total_failed = total_failed + 1
    print(string.format("FAIL [%s] <load error> - %s", filename, tostring(load_err)))
  else
    local ok_load, cases = pcall(chunk)
    if not ok_load or type(cases) ~= "table" then
      total_failed = total_failed + 1
      print(string.format("FAIL [%s] <module error> - %s", filename, tostring(cases)))
    else
      -- sort case names for stable output
      local names = {}
      for name in pairs(cases) do names[#names + 1] = name end
      table.sort(names)

      for _, name in ipairs(names) do
        local fn = cases[name]
        local t = make_t()
        local ok, err = pcall(fn, t)
        if ok then
          total_passed = total_passed + 1
          print(string.format("PASS [%s] %s", filename, name))
        else
          total_failed = total_failed + 1
          print(string.format("FAIL [%s] %s - %s", filename, name, tostring(err)))
        end
      end
    end
  end
end

print(string.format("%d passed, %d failed", total_passed, total_failed))

if total_failed > 0 then
  os.exit(1)
else
  os.exit(0)
end
