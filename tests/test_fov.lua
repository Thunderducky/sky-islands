local fov = require("world.fov")

-- Build opaque/mark harness from an ASCII map: '#' opaque, '.' clear.
local function harness(rows)
  local h, w = #rows, #rows[1]
  local function opaque(x, y)
    if x < 0 or y < 0 or x >= w or y >= h then return true end
    return rows[y + 1]:sub(x + 1, x + 1) == "#"
  end
  local visible = {}
  -- bounds-check like the real caller (fov.update) does: unchecked OOB
  -- marks would alias into in-map indices under y*w+x
  local function mark(x, y)
    if x >= 0 and y >= 0 and x < w and y < h then visible[y * w + x] = true end
  end
  return opaque, mark, visible, w
end

return {
  open_room_all_visible = function(t)
    local map = { ".....", ".....", ".....", ".....", "....." }
    local opaque, mark, vis, w = harness(map)
    fov.compute(2, 2, 10, opaque, mark)
    local n = 0
    for _ in pairs(vis) do n = n + 1 end
    t.eq(n, 25, "everything visible in an open room")
  end,

  pillar_casts_shadow = function(t)
    local map = {
      ".......",
      ".......",
      ".......",
      "...#...", -- pillar at (3,3); origin at (1,3)
      ".......",
      ".......",
      ".......",
    }
    local opaque, mark, vis, w = harness(map)
    fov.compute(1, 3, 10, opaque, mark)
    t.ok(vis[3 * w + 3], "pillar itself is visible")
    t.ok(not vis[3 * w + 5], "tile directly behind pillar is shadowed")
    t.ok(not vis[3 * w + 6], "far tile behind pillar is shadowed")
    t.ok(vis[0 * w + 3], "off-axis tile is visible")
  end,

  wall_blocks_room = function(t)
    local map = {
      "......",
      "######",
      "......",
    }
    local opaque, mark, vis, w = harness(map)
    fov.compute(2, 0, 10, opaque, mark)
    t.ok(vis[1 * w + 2], "wall face visible")
    t.ok(not vis[2 * w + 2], "behind solid wall not visible")
    t.ok(not vis[2 * w + 0], "behind solid wall not visible (corner)")
  end,

  radius_clips = function(t)
    local map = {}
    for _ = 1, 20 do map[#map + 1] = string.rep(".", 20) end
    local opaque, mark, vis, w = harness(map)
    fov.compute(10, 10, 3, opaque, mark)
    t.ok(vis[10 * w + 13], "r=3 on axis visible")
    t.ok(not vis[10 * w + 14], "r=4 on axis clipped")
    t.ok(not vis[6 * w + 6], "diagonal beyond radius clipped")
  end,

  origin_always_visible = function(t)
    local map = { "###", "#.#", "###" }
    local opaque, mark, vis, w = harness(map)
    fov.compute(1, 1, 5, opaque, mark)
    t.ok(vis[1 * w + 1], "origin visible in a closet")
    t.ok(vis[0 * w + 1], "adjacent wall visible")
  end,
}
