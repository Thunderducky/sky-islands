-- seed -> island. Pure function of (seed, defs); all randomness from
-- rng streams forked off the seed. Pipeline per SPEC: silhouette ->
-- terrain -> buildings -> features -> loot -> validate.
local sub = require("world.substrate")
local rng = require("util.rng")
local G = require("util.grid")

local M = {}

-- Value noise: random lattice + bilinear interpolation, two octaves.
local function make_noise(r, w, h, cell)
  local lw, lh = w // cell + 2, h // cell + 2
  local lattice = {}
  for i = 1, lw * lh do lattice[i] = r:float() end
  return function(x, y)
    local fx, fy = x / cell, y / cell
    local x0, y0 = math.floor(fx), math.floor(fy)
    local tx, ty = fx - x0, fy - y0
    local function lat(ix, iy) return lattice[iy * lw + ix + 1] end
    local a = lat(x0, y0) + (lat(x0 + 1, y0) - lat(x0, y0)) * tx
    local b = lat(x0, y0 + 1) + (lat(x0 + 1, y0 + 1) - lat(x0, y0 + 1)) * tx
    return a + (b - a) * ty
  end
end

local function build_mask(r, w, h)
  local n1 = make_noise(r, w, h, 12)
  local n2 = make_noise(r, w, h, 5)
  local cx, cy = (w - 1) / 2, (h - 1) / 2
  local mask, count = {}, 0
  for y = 0, h - 1 do
    for x = 0, w - 1 do
      local dx, dy = (x - cx) / cx, (y - cy) / cy
      local d = math.sqrt(dx * dx + dy * dy)
      local v = (1.0 - d) + n1(x, y) * 0.55 + n2(x, y) * 0.25 - 0.45
      if v > 0 then
        mask[y * w + x] = true
        count = count + 1
      end
    end
  end
  -- fracture bites: circular punches out of the rim
  for _ = 1, r:int(2, 4) do
    -- pick a rim-ish point: random angle, walk in from the edge to first land
    local ang = r:float() * 2 * math.pi
    local px, py = cx + math.cos(ang) * cx, cy + math.sin(ang) * cy
    local steps = math.max(w, h)
    local bx, by
    for s = 0, steps do
      local x = math.floor(px + (cx - px) * s / steps + 0.5)
      local y = math.floor(py + (cy - py) * s / steps + 0.5)
      if mask[y * w + x] then bx, by = x, y break end
    end
    if bx then
      local br = r:int(3, 6)
      for y = math.max(0, by - br), math.min(h - 1, by + br) do
        for x = math.max(0, bx - br), math.min(w - 1, bx + br) do
          local ddx, ddy = x - bx, y - by
          if ddx * ddx + ddy * ddy <= br * br and mask[y * w + x] then
            mask[y * w + x] = nil
            count = count - 1
          end
        end
      end
    end
  end
  -- keep only the largest connected landmass (bites can sever fragments)
  local best_set, best_count = nil, 0
  local claimed = {}
  for idx in pairs(mask) do
    if not claimed[idx] then
      local x, y = G.xy(idx, w)
      local set, c = G.flood(w, h, x, y, function(fx, fy) return mask[fy * w + fx] end)
      for i in pairs(set) do claimed[i] = true end
      if c > best_count then best_set, best_count = set, c end
    end
  end
  return best_set or {}, best_count
end

local function place_buildings(r, island, defs, mask)
  local w, h = island.w, island.h
  local eco = defs.economy.island
  local placed = {}
  local want = r:int(eco.buildings_min, eco.buildings_max)
  local tries = 0
  while #placed < want and tries < 120 do
    tries = tries + 1
    local bw, bh = r:int(5, 9), r:int(5, 8)
    local bx, by = r:int(1, w - bw - 2), r:int(1, h - bh - 2)
    local ok = true
    -- footprint + 1 margin must be land and building-free
    for y = by - 1, by + bh do
      for x = bx - 1, bx + bw do
        if not mask[y * w + x] then ok = false break end
      end
      if not ok then break end
    end
    if ok then
      for _, b in ipairs(placed) do
        if not (bx + bw + 1 < b.x or b.x + b.w + 1 < bx or
                by + bh + 1 < b.y or b.y + b.h + 1 < by) then
          ok = false
          break
        end
      end
    end
    if ok then
      for y = by, by + bh - 1 do
        for x = bx, bx + bw - 1 do
          local edge = (x == bx or x == bx + bw - 1 or y == by or y == by + bh - 1)
          sub.set(island, "terrain", x, y, defs.tid[edge and "wall_plank" or "floor_planks"])
        end
      end
      -- 1-2 doors on non-corner perimeter cells
      local sides = {}
      for x = bx + 1, bx + bw - 2 do
        sides[#sides + 1] = { x = x, y = by }
        sides[#sides + 1] = { x = x, y = by + bh - 1 }
      end
      for y = by + 1, by + bh - 2 do
        sides[#sides + 1] = { x = bx, y = y }
        sides[#sides + 1] = { x = bx + bw - 1, y = y }
      end
      for _ = 1, r:int(1, 2) do
        local d = r:pick(sides)
        sub.set(island, "terrain", d.x, d.y, defs.tid["door_closed"])
      end
      placed[#placed + 1] = { x = bx, y = by, w = bw, h = bh }
    end
  end
  return placed
end

local function roll_loot(r, defs, table_name)
  local items = {}
  for _, entry in ipairs(defs.loot_tables[table_name]) do
    if r:chance(entry.chance) then
      items[#items + 1] = { id = entry.item, n = r:int(entry.min, entry.max) }
    end
  end
  return items
end

local function walkable_at(island, defs)
  return function(x, y)
    local t = defs.terrain[sub.get(island, "terrain", x, y)]
    return t.walkable or (t.door ~= nil) -- doors count as passable for reachability
  end
end

function M.generate(seed, defs)
  local eco = defs.economy.island
  local w, h = eco.w, eco.h
  for attempt = 0, 29 do
    local r = rng.new(seed + attempt * 1000003)
    local island = sub.new_island(w, h)
    island.seed = seed
    island.name = string.format("Isle-%03d", seed % 1000)

    local mask, land = build_mask(r, w, h)
    if land >= w * h * eco.land_min_frac and land <= w * h * eco.land_max_frac then
      -- terrain from a texture noise
      local tex = make_noise(r, w, h, 7)
      for y = 0, h - 1 do
        for x = 0, w - 1 do
          local id = "sky"
          if mask[y * w + x] then
            local v = tex(x, y)
            if v < 0.35 then id = "rock"
            elseif v < 0.55 then id = "dirt"
            elseif v < 0.8 then id = "grass"
            else id = "grass_tall" end
          end
          sub.set(island, "terrain", x, y, defs.tid[id])
        end
      end
      island.land_count = land

      local buildings = place_buildings(r, island, defs, mask)

      -- land tiles near the rim (within 2 of sky) for beacon + outdoor caches
      local rim = {}
      for idx in pairs(mask) do
        local x, y = G.xy(idx, w)
        local near_sky = false
        for _, nb in ipairs(G.neighbors8(x, y, w, h)) do
          if not mask[nb.y * w + nb.x] then near_sky = true break end
        end
        local t = defs.terrain[sub.get(island, "terrain", x, y)]
        if near_sky and t.walkable and not t.door then rim[#rim + 1] = { x = x, y = y } end
      end

      -- beacon + start
      local beacon = r:pick(rim)
      if beacon then
        sub.set_feature(island, beacon.x, beacon.y,
          { def = defs.feature_by_id["extract_beacon"] })
        island.extract_idx = beacon.y * w + beacon.x
        island.start_x, island.start_y = beacon.x, beacon.y

        -- caches: prefer building interiors, spill to rim
        local spots = {}
        for _, b in ipairs(buildings) do
          for _ = 1, 2 do
            spots[#spots + 1] = { x = r:int(b.x + 1, b.x + b.w - 2),
                                  y = r:int(b.y + 1, b.y + b.h - 2) }
          end
        end
        r:shuffle(rim)
        for i = 1, math.min(6, #rim) do spots[#spots + 1] = rim[i] end
        r:shuffle(spots)

        local reach = G.flood(w, h, beacon.x, beacon.y, walkable_at(island, defs))
        local want = r:int(eco.caches_min, eco.caches_max)
        local caches = 0
        for _, s in ipairs(spots) do
          if caches >= want then break end
          local idx = s.y * w + s.x
          if reach[idx] and not sub.feature_at(island, s.x, s.y) then
            local kind = r:chance(eco.ruin_cache_chance) and "cache_ruin" or "cache_small"
            local fdef = defs.feature_by_id[kind]
            sub.set_feature(island, s.x, s.y,
              { def = fdef, opened = false, loot = roll_loot(r, defs, fdef.loot_table) })
            caches = caches + 1
          end
        end
        island.cache_count = caches

        if caches >= eco.caches_min then
          return island -- valid: everything placed was flood-verified reachable
        end
      end
    end
  end
  error("islandgen: no valid island in 30 attempts for seed " .. seed)
end

return M
