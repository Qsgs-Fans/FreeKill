local AIStrategy = require "lunarltk.server.ai.strategy"

---@class AI.ViewCardsAndChoiceStrategy : AIStrategy
local ViewCardsAndChoiceStrategy = AIStrategy:subclass("AI.ViewCardsAndChoiceStrategy")

---@return string?, number?
function ViewCardsAndChoiceStrategy:think(ai)
end

---@param val string?
function ViewCardsAndChoiceStrategy:convertThinkResult(val)
  if not val then return end
  return val
end



---@param spec {
--- think?: fun(self: AI.ViewCardsAndChoiceStrategy, ai: SmartAI)
--- }
---@return AI.ViewCardsAndChoiceStrategy
local function newViewCardsAndChoiceStrategy(spec)
  local ret = ViewCardsAndChoiceStrategy:new()

  if spec.think then ret.think = spec.think end

  return ret
end

return {
  ViewCardsAndChoiceStrategy,
  newViewCardsAndChoiceStrategy,
}

