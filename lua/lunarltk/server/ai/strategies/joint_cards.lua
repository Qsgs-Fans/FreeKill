local AIStrategy = require "lunarltk.server.ai.strategy"

---@class AI.JointCardsStrategy : AIStrategy
local JointCardsStrategy = AIStrategy:subclass("AI.JointCardsStrategy")

---@param ai SmartAI
---@return integer[]?, number?
function JointCardsStrategy:chooseCards(ai)
end

---@param spec {
---  choose_cards?: (fun(self: AI.JointCardsStrategy, ai: SmartAI): integer[]?, number?),
---}
---@return AI.JointCardsStrategy
local function newJointCardsStrategy(spec)
  local ret = JointCardsStrategy:new()
  if spec.choose_cards then
    ret.chooseCards = spec.choose_cards
  end

  return ret
end

return {
  JointCardsStrategy,
  newJointCardsStrategy,
}

