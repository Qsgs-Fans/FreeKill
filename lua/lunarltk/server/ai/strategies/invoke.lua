local AIStrategy = require "lunarltk.server.ai.strategy"

---@class AI.InvokeStrategy : AIStrategy
local InvokeStrategy = AIStrategy:subclass("AI.InvokeStrategy")

---@return boolean?
function InvokeStrategy:think(ai)
end

---@param val boolean?
function InvokeStrategy:convertThinkResult(val)
  if not val then return end
  return val
end


---@param spec {
--- think?: fun(self: AI.InvokeStrategy, ai: SmartAI): boolean?
--- }
---@return AI.InvokeStrategy
local function newInvokeStrategy(spec)
  local ret = InvokeStrategy:new()
  if spec.think then ret.think = spec.think end
  return ret
end

return {
  InvokeStrategy,
  newInvokeStrategy,
}
