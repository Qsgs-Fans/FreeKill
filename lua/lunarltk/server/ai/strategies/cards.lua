local AIStrategy = require "lunarltk.server.ai.strategy"

---@class AI.CardsStrategy : AIStrategy
local CardsStrategy = AIStrategy:subclass("AI.CardsStrategy")

---@param ai SmartAI
---@return integer[]?, number?
function CardsStrategy:chooseCards(ai)
end

---@param spec {
---  choose_cards?: (fun(self: AI.CardsStrategy, ai: SmartAI): integer[]?, number?),
---}
---@return AI.CardsStrategy
local function newCardsStrategy(spec)
  local ret = CardsStrategy:new()
  if spec.choose_cards then
    ret.chooseCards = spec.choose_cards
  end

  return ret
end

return {
  CardsStrategy,
  newCardsStrategy,
}

