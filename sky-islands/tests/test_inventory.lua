local inv = require("sim.inventory")

local MAX = { copper = 10, cable = 4, tool = 1 }
local function max_of(id) return MAX[id] end
local BY_ID = {
  copper = { name = "copper", value = 8 },
  cable = { name = "cable", value = 14 },
  tool = { name = "tool", value = 25 },
}

return {
  add_tops_up_existing_stacks_first = function(t)
    local slots = { { id = "copper", n = 7 } }
    local moved, left = inv.add(slots, 8, max_of, { id = "copper", n = 5 })
    t.eq(moved, 5)
    t.eq(left, 0)
    t.eq(#slots, 2)
    t.eq(slots[1].n, 10, "existing stack topped to max")
    t.eq(slots[2].n, 2, "overflow opens a new slot")
  end,

  add_respects_cap = function(t)
    local slots = { { id = "cable", n = 4 }, { id = "tool", n = 1 } }
    local moved, left = inv.add(slots, 3, max_of, { id = "copper", n = 15 })
    t.eq(moved, 10, "one free slot takes one max stack")
    t.eq(left, 5)
    t.eq(#slots, 3)
  end,

  add_to_full_moves_nothing = function(t)
    local slots = { { id = "tool", n = 1 } }
    local moved, left = inv.add(slots, 1, max_of, { id = "copper", n = 3 })
    t.eq(moved, 0)
    t.eq(left, 3)
  end,

  unstackables_take_one_slot_each = function(t)
    local slots = {}
    local moved, left = inv.add(slots, 8, max_of, { id = "tool", n = 3 })
    t.eq(moved, 3)
    t.eq(left, 0)
    t.eq(#slots, 3, "max_stack 1 means one slot per unit")
  end,

  containers_are_just_bigger_slot_lists = function(t)
    -- a 6-slot cache accepting a big haul: same add(), bigger cap
    local box = {}
    local moved, left = inv.add(box, 6, max_of, { id = "copper", n = 45 })
    t.eq(moved, 45)
    t.eq(left, 0)
    t.eq(#box, 5, "45 copper = 4 full stacks + 1 partial")
    -- and it still fills up eventually
    moved, left = inv.add(box, 6, max_of, { id = "tool", n = 3 })
    t.eq(moved, 1, "one slot left takes one unstackable")
    t.eq(left, 2)
  end,

  value_and_summary = function(t)
    local items = { { id = "copper", n = 2 }, { id = "tool", n = 1 } }
    t.eq(inv.value(items, BY_ID), 41)
    t.eq(inv.summary(items, BY_ID), "copper x2, tool")
  end,
}
