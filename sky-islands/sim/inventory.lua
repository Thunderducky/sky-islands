-- Slot/stack math, pure and testable. A "stack" is {id=, n=}; a slot list
-- is a packed array of stacks. EVERY holder — pack, cache, skiff hold,
-- ground — is a capped slot list; only the cap differs. One mechanism.
local M = {}

-- Add a stack into a capped slot list: top up existing stacks first, then
-- open new slots. Mutates slots. Returns (moved_n, leftover_n).
function M.add(slots, cap, max_stack_of, stack)
  local remaining = stack.n
  local max = max_stack_of(stack.id)
  for _, s in ipairs(slots) do
    if remaining == 0 then break end
    if s.id == stack.id and s.n < max then
      local take = math.min(max - s.n, remaining)
      s.n, remaining = s.n + take, remaining - take
    end
  end
  while remaining > 0 and #slots < cap do
    local take = math.min(max, remaining)
    slots[#slots + 1] = { id = stack.id, n = take }
    remaining = remaining - take
  end
  return stack.n - remaining, remaining
end

function M.value(items, item_by_id)
  local v = 0
  for _, s in ipairs(items) do
    v = v + item_by_id[s.id].value * s.n
  end
  return v
end

function M.summary(items, item_by_id)
  local parts = {}
  for _, s in ipairs(items) do
    local name = item_by_id[s.id].name
    parts[#parts + 1] = s.n > 1 and (name .. " x" .. s.n) or name
  end
  return table.concat(parts, ", ")
end

return M
