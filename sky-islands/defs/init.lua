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
    if f.latent then
      assert(f.discover == "sight" or f.discover == "assay",
        f.id .. ": latent feature needs discover = sight|assay")
      assert(f.bounty, f.id .. ": latent feature needs a bounty")
    end
    if f.footprint then
      local reps = 0
      for _, row in ipairs(f.footprint.rows) do
        for rx = 1, #row do
          local ch = row:sub(rx, rx)
          if ch ~= " " then
            local cell = f.footprint.legend[ch]
            assert(cell, f.id .. (": footprint char %q not in legend"):format(ch))
            if ch == "@" then
              assert(cell.rep, f.id .. ": footprint @ cell must set rep = true")
              reps = reps + 1
            end
          end
        end
      end
      assert(reps == 1, f.id .. ": footprint needs exactly one @ (has " ..
        reps .. ")")
      for ch, cell in pairs(f.footprint.legend) do
        assert(M.tid[cell.t], f.id .. ": footprint legend " .. ch ..
          ": unknown terrain " .. tostring(cell.t))
      end
    end
  end

  M.creature_list = require("defs.creatures")
  M.creature_by_id = index_by_id(M.creature_list)
  resolve_copy_from(M.creature_list, M.creature_by_id)
  for _, c in ipairs(M.creature_list) do
    for _, dr in ipairs(c.drops or {}) do
      assert(M.item_by_id[dr.item], c.id .. ": unknown drop item " .. dr.item)
    end
  end

  M.economy = require("defs.economy")

  -- market events: same fail-at-load discipline
  M.econ_event_list = require("defs.econ_events")
  M.econ_event_by_id = index_by_id(M.econ_event_list)
  for _, e in ipairs(M.econ_event_list) do
    assert(type(e.gossip) == "table" and #e.gossip > 0, e.id .. ": needs gossip lines")
    assert(e.log, e.id .. ": needs a log line")
    assert(e.duration and e.duration[1] and e.duration[2]
      and e.duration[1] <= e.duration[2], e.id .. ": bad duration")
    for _, eff in ipairs(e.effects or {}) do
      assert(eff.match and (eff.match.id or eff.match.has),
        e.id .. ": effect needs match.id or match.has")
      if eff.match.id then
        assert(M.item_by_id[eff.match.id], e.id .. ": unknown item " .. eff.match.id)
      end
      if eff.demand then
        assert(M.economy.demand_levels[eff.demand],
          e.id .. ": unknown demand level " .. tostring(eff.demand))
      end
    end
    for _, a in ipairs(e.add_stock or {}) do
      assert(M.item_by_id[a.item], e.id .. ": unknown add_stock item " .. a.item)
    end
  end
  for _, s in ipairs(M.economy.store.staples) do
    assert(M.item_by_id[s.item], "store staple: unknown item " .. s.item)
  end
  for _, s in ipairs(M.economy.store.grab_bag) do
    assert(M.item_by_id[s.item], "store grab_bag: unknown item " .. s.item)
  end

  -- people: strict at load, like everything else
  M.npc_list = require("defs.npcs")
  M.npc_by_id = index_by_id(M.npc_list)
  for _, n in ipairs(M.npc_list) do
    local c = n.conversation
    assert(c and c.greeting, n.id .. ": needs a conversation greeting")
    for _, topic in ipairs(c.topics or {}) do
      assert(topic.label and topic.text, n.id .. ": topic needs label + text")
    end
    if n.trade then
      assert(n.slots, n.id .. ": traders need a slots cap")
    end
    for _, e in ipairs(n.stock_table or {}) do
      assert(M.item_by_id[e.item], n.id .. ": unknown stock item " .. e.item)
    end
    if n.visit_on_event then
      assert(M.econ_event_by_id[n.visit_on_event],
        n.id .. ": unknown visit_on_event " .. n.visit_on_event)
    end
  end

  -- authored islands: strict at load, like everything else
  M.island_list = require("defs.islands")
  M.island_by_id = index_by_id(M.island_list)
  for _, isl in ipairs(M.island_list) do
    local w = #isl.map[1]
    local beacons, starts = 0, 0
    for ry, row in ipairs(isl.map) do
      assert(#row == w, isl.id .. ": row " .. ry .. " width " .. #row ..
        " ~= " .. w)
      for rx = 1, #row do
        local cell = isl.legend[row:sub(rx, rx)]
        assert(cell, isl.id .. (": char %q at row %d col %d not in legend")
          :format(row:sub(rx, rx), ry, rx))
        if cell.f == "extract_beacon" then beacons = beacons + 1 end
        if cell.start then starts = starts + 1 end
      end
    end
    if isl.destination then
      assert(beacons == 0 and starts == 1, isl.id ..
        ": destination needs one start cell and no beacon")
      for _, eff in ipairs(isl.store_bias or {}) do
        assert(eff.match and (eff.match.id or eff.match.has),
          isl.id .. ": store_bias needs match.id or match.has")
        if eff.match.id then
          assert(M.item_by_id[eff.match.id],
            isl.id .. ": store_bias unknown item " .. eff.match.id)
        end
        assert(M.economy.demand_levels[eff.demand],
          isl.id .. ": store_bias unknown demand " .. tostring(eff.demand))
      end
    else
      assert(beacons == 1, isl.id ..
        ": needs exactly one extract_beacon, has " .. beacons)
    end
    for ch, cell in pairs(isl.legend) do
      assert(M.tid[cell.t], isl.id .. ": legend " .. ch ..
        ": unknown terrain " .. tostring(cell.t))
      if cell.f then
        assert(M.feature_by_id[cell.f], isl.id .. ": legend " .. ch ..
          ": unknown feature " .. tostring(cell.f))
      end
      for _, s in ipairs(cell.loot or {}) do
        assert(M.item_by_id[s.id], isl.id .. ": legend " .. ch ..
          ": unknown loot item " .. tostring(s.id))
      end
    end
    for _, c in ipairs(isl.creatures or {}) do
      assert(M.creature_by_id[c.def], isl.id .. ": unknown creature " ..
        tostring(c.def))
    end
    for _, n in ipairs(isl.npcs or {}) do
      assert(M.npc_by_id[n.def], isl.id .. ": unknown npc " .. tostring(n.def))
      for _, s in ipairs(n.stock or {}) do
        assert(M.item_by_id[s.id], isl.id .. ": npc " .. n.def ..
          ": unknown stock item " .. tostring(s.id))
      end
    end
  end
  for _, d in ipairs(M.economy.travel.destinations) do
    local spec = M.island_by_id[d.id]
    assert(spec and spec.destination,
      "economy.travel: " .. d.id .. " is not a destination island spec")
  end
  return M
end

return M
