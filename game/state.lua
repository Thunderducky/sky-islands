-- State-stack machine. Each state: { enter?, leave?, update?, draw, key? }.
-- draw runs bottom-up (overlays render over play); key/update hit top only.
local M = {}

function M.new()
  return setmetatable({ stack = {} }, { __index = M })
end

function M.push(self, state, ...)
  self.stack[#self.stack + 1] = state
  if state.enter then state.enter(state, ...) end
end

function M.pop(self)
  local top = self.stack[#self.stack]
  self.stack[#self.stack] = nil
  if top and top.leave then top.leave(top) end
  return top
end

function M.switch(self, state, ...)
  while #self.stack > 0 do self:pop() end
  self:push(state, ...)
end

function M.top(self)
  return self.stack[#self.stack]
end

function M.key(self, k)
  local top = self:top()
  if top and top.key then top.key(top, k) end
end

function M.update(self, dt)
  local top = self:top()
  if top and top.update then top.update(top, dt) end
end

function M.draw(self, dt)
  for _, s in ipairs(self.stack) do
    s.draw(s, dt)
  end
end

return M
