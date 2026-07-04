-- Def loader: interns string ids to ints (terrain only, for the hot layer),
-- resolves copy_from via metatable chain, exposes lookup tables.
local M = {}

local function index_by_id(list)
  local by_id = {}
  for _, d in ipairs(list) do
    assert(d.id, "def missing id")
    assert(by_id[d.id] == nil, "duplicate def id: " .. d.id)
    by_id[d.id] = d
  end
  return by_id
end

local function resolve_copy_from(list, by_id)
  for _, d in ipairs(list) do
    if d.copy_from then
      local parent = assert(by_id[d.copy_from], d.id .. ": unknown copy_from " .. d.copy_from)
      assert(parent ~= d, "self copy_from")
      setmetatable(d, { __index = parent })
    end
  end
end

function M.load()
  -- terrain: interned, hot layer stores ints
  M.terrain_list = require("defs.terrain")
  M.terrain_by_id = index_by_id(M.terrain_list)
  resolve_copy_from(M.terrain_list, M.terrain_by_id)
  M.terrain = {} -- [int] -> def
  M.tid = {}     -- [string id] -> int
  for i, d in ipairs(M.terrain_list) do
    d.int = i
    M.terrain[i] = d
    M.tid[d.id] = i
  end

  M.item_list = require("defs.items")
  M.item_by_id = index_by_id(M.item_list)
  resolve_copy_from(M.item_list, M.item_by_id)

  local feats = require("defs.features")
  M.feature_list = feats.features
  M.feature_by_id = index_by_id(M.feature_list)
  resolve_copy_from(M.feature_list, M.feature_by_id)
  M.loot_tables = feats.loot_tables

  -- cross-reference check, CDDA-style: fail at load, not mid-game
  for name, table_ in pairs(M.loot_tables) do
    for _, entry in ipairs(table_) do
      assert(M.item_by_id[entry.item], "loot table " .. name .. ": unknown item " .. entry.item)
    end
  end
  for _, f in ipairs(M.feature_list) do
    if f.loot_table then
      assert(M.loot_tables[f.loot_table], f.id .. ": unknown loot_table " .. f.loot_table)
    end
  end

  M.economy = require("defs.economy")
  return M
end

return M
