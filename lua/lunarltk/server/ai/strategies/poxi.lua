local AIStrategy = require "lunarltk.server.ai.strategy"

---@class AI.PoxiStrategy : AIStrategy
local PoxiStrategy = AIStrategy:subclass("AI.PoxiStrategy")

---@param ai SmartAI
---@return integer[]?, number?
function PoxiStrategy:think(ai)
end

---@param val integer[]?
---@return integer[]?
function PoxiStrategy:convertThinkResult(val)
  if not val then return end
  return val
end

---@param spec {
---  think?: (fun(self: AI.PoxiStrategy, ai: SmartAI): integer[]?, number?),
---}
---@return AI.PoxiStrategy
local function newPoxiStrategy(spec)
  local ret = PoxiStrategy:new()
  if spec.think then
    ret.think = spec.think
  end

  return ret
end

return {
  PoxiStrategy,
  newPoxiStrategy,
}

