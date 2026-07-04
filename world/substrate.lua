-- The ONLY module that knows layer storage. Everything goes through
-- get/set — no exceptions (this is the Rust escape hatch's contract).
-- Dense layers are flat arrays stored 1-based at (y*w+x)+1.
local M = {}

local DENSE = { terrain = true, fog = true }

function M.new_island(w, h)
  local n = w * h
  local terrain, fog = {}, {}
  for i = 1, n do
    terrain[i] = 0
    fog[i] = 0
  end
  return {
    w = w, h = h,
    terrain = terrain,
    fog = fog, -- 0 unknown, 1 remembered, 2 visible
    features = {},   -- sparse: [0-based idx] = {def=<feature def>, opened=bool}
    item_piles = {}, -- sparse: [0-based idx] = { {id=,n=}, ... }
    start_x = 0, start_y = 0,
    extract_idx = -1,
    land_count = 0, seen_count = 0,
    seed = 0, name = "?",
  }
end

function M.get(island, layer, x, y)
  assert(DENSE[layer], "not a dense layer: " .. tostring(layer))
  return island[layer][y * island.w + x + 1]
end

function M.set(island, layer, x, y, v)
  assert(DENSE[layer], "not a dense layer: " .. tostring(layer))
  island[layer][y * island.w + x + 1] = v
end

function M.in_bounds(island, x, y)
  return x >= 0 and y >= 0 and x < island.w and y < island.h
end

function M.feature_at(island, x, y)
  return island.features[y * island.w + x]
end

function M.set_feature(island, x, y, f)
  island.features[y * island.w + x] = f
end

function M.pile_at(island, x, y)
  return island.item_piles[y * island.w + x]
end

function M.add_item(island, x, y, item)
  local idx = y * island.w + x
  local pile = island.item_piles[idx]
  if not pile then
    pile = {}
    island.item_piles[idx] = pile
  end
  -- stack onto an existing entry of the same id
  for _, it in ipairs(pile) do
    if it.id == item.id then
      it.n = it.n + item.n
      return
    end
  end
  pile[#pile + 1] = item
end

function M.take_pile(island, x, y)
  local idx = y * island.w + x
  local pile = island.item_piles[idx]
  island.item_piles[idx] = nil
  return pile
end

return M
