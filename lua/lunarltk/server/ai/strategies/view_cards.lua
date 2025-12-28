local AIStrategy = require "lunarltk.server.ai.strategy"

---@class AI.ViewCardsStrategy : AIStrategy
local ViewCardsStrategy = AIStrategy:subclass("AI.ViewCardsStrategy")

function ViewCardsStrategy:think(ai)
end

---@param val boolean?
---@return "OK"
function ViewCardsStrategy:convertThinkResult(val)
  return "OK"
end

---@param spec {
--- think?: fun(self: AI.ViewCardsStrategy, ai: SmartAI)
--- }
---@return AI.ViewCardsStrategy
local function newViewCardsStrategy(spec)
  local ret = ViewCardsStrategy:new()
  if spec.think then ret.think = spec.think end
  return ret
end

return {
  ViewCardsStrategy,
  newViewCardsStrategy,
}
