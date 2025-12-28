local AIStrategy = require "lunarltk.server.ai.strategy"

---@class AI.ArrangeCardsStrategy : AIStrategy
local ArrangeCardsStrategy = AIStrategy:subclass("AI.ArrangeCardsStrategy")

---@param ai SmartAI
---@return table[]?, number?
function ArrangeCardsStrategy:think(ai)
end

---@param val table[]?
---@return table[]?
function ArrangeCardsStrategy:convertThinkResult(val)
  if not val then return end
  return val
end

---@param spec {
---  think?: (fun(self: AI.ArrangeCardsStrategy, ai: SmartAI): table[]?, number?),
---}
---@return AI.ArrangeCardsStrategy
local function newArrangeCardsStrategy(spec)
  local ret = ArrangeCardsStrategy:new()
  if spec.think then
    ret.think = spec.think
  end

  return ret
end

return {
  ArrangeCardsStrategy,
  newArrangeCardsStrategy,
}

