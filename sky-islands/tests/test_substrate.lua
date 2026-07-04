local sub = require("world.substrate")

return {
  dense_roundtrip = function(t)
    local isl = sub.new_island(8, 6)
    sub.set(isl, "terrain", 0, 0, 3)
    sub.set(isl, "terrain", 7, 5, 9)
    sub.set(isl, "fog", 4, 2, 2)
    t.eq(sub.get(isl, "terrain", 0, 0), 3)
    t.eq(sub.get(isl, "terrain", 7, 5), 9)
    t.eq(sub.get(isl, "fog", 4, 2), 2)
    t.eq(sub.get(isl, "fog", 0, 0), 0)
  end,

  unknown_layer_errors = function(t)
    local isl = sub.new_island(4, 4)
    t.ok(not pcall(sub.get, isl, "nope", 0, 0))
  end,

  in_bounds = function(t)
    local isl = sub.new_island(4, 4)
    t.ok(sub.in_bounds(isl, 0, 0))
    t.ok(sub.in_bounds(isl, 3, 3))
    t.ok(not sub.in_bounds(isl, 4, 0))
    t.ok(not sub.in_bounds(isl, 0, -1))
  end,

  features = function(t)
    local isl = sub.new_island(4, 4)
    t.eq(sub.feature_at(isl, 1, 1), nil)
    sub.set_feature(isl, 1, 1, { def = { id = "x" } })
    t.eq(sub.feature_at(isl, 1, 1).def.id, "x")
    sub.set_feature(isl, 1, 1, nil)
    t.eq(sub.feature_at(isl, 1, 1), nil)
  end,

  piles_stack_same_id = function(t)
    local isl = sub.new_island(4, 4)
    sub.add_item(isl, 2, 2, { id = "a", n = 2 })
    sub.add_item(isl, 2, 2, { id = "a", n = 3 })
    sub.add_item(isl, 2, 2, { id = "b", n = 1 })
    local pile = sub.pile_at(isl, 2, 2)
    t.eq(#pile, 2)
    t.eq(pile[1].n, 5)
    local taken = sub.take_pile(isl, 2, 2)
    t.eq(#taken, 2)
    t.eq(sub.pile_at(isl, 2, 2), nil)
  end,
}
