-- Latent-feature discovery (SI-0003). Two modes, set per feature def:
--   sight — surveyed the moment it's first rendered visible
--   assay — deliberate work: Space on the tile, costs a turn
-- Found features land in S.run.notable (NOT run.discovered — that list
-- is caches, and caches_found must stay honest). Pure Lua.
local sub = require("world.substrate")
local flavor = require("flavor")

local M = {}

local function found(S, f)
  f.found = true
  S.run.notable[#S.run.notable + 1] = f
end

-- Is any mask tile of this feature currently visible? Footprints are
-- seen when ANY of their tiles is (bigger splats catch the eye sooner);
-- single-tile features check just their own tile.
local function any_tile_visible(island, idx, f)
  local fp = f.def.footprint
  -- no origin = placed without stamping (debug force_latent, authored
  -- maps): behaves as a single tile
  if not (fp and f.ox) then return island.fog[idx + 1] == 2 end
  for ry, row in ipairs(fp.rows) do
    for rx = 1, #row do
      if row:sub(rx, rx) ~= " " then
        local x, y = f.ox + rx - 1, f.oy + ry - 1
        if x >= 0 and y >= 0 and x < island.w and y < island.h
            and island.fog[y * island.w + x + 1] == 2 then
          return true
        end
      end
    end
  end
  return false
end

-- Sight pass: call after any FOV update. Sorted-index iteration — the
-- flavor stream is cosmetic but its draw order stays deterministic
-- anyway (hard rule 9).
function M.scan_sight(S)
  if not (S.run and S.run.notable) then return end
  local island = S.island
  local idxs = {}
  for idx in pairs(island.features) do idxs[#idxs + 1] = idx end
  table.sort(idxs)
  for _, idx in ipairs(idxs) do
    local f = island.features[idx]
    if f.def.latent and f.def.discover == "sight" and not f.found
        and any_tile_visible(island, idx, f) then
      found(S, f)
      flavor.emit("latent_sighted", { feature = f.def.name })
    end
  end
end

-- Assay/inspect the latent feature underfoot — or the footprint the
-- player is standing INSIDE (mask membership). Returns true if survey
-- work was done (a turn should pass), nil otherwise. Deliberate
-- interaction always acknowledges: an already-found feature (either
-- mode) replays its logged line instead of silence.
function M.assay(S)
  if not (S.run and S.run.notable) then return nil end
  local f = sub.feature_covering(S.island, S.player.x, S.player.y)
  if not (f and f.def.latent) then return nil end
  if f.found then
    flavor.emit("assay_already", { feature = f.def.name })
    return nil
  end
  if f.def.discover ~= "assay" then return nil end
  found(S, f)
  flavor.emit("assay_done", { feature = f.def.name })
  return true
end

return M
