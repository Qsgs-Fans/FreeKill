local AIStrategy = require "lunarltk.server.ai.strategy"

---@class AI.ChooseCardsAndChoiceStrategy : AIStrategy
local ChooseCardsAndChoiceStrategy = AIStrategy:subclass("AI.ChooseCardsAndChoiceStrategy")

---@param ai SmartAI
---@return integer[]?, number?
function ChooseCardsAndChoiceStrategy:chooseCards(ai)
end

---@param ai SmartAI
---@return string?, number?
function ChooseCardsAndChoiceStrategy:chooseChoice(ai)
end

---@param spec {
---  choose_cards?: (fun(self: AI.ChooseCardsAndChoiceStrategy, ai: SmartAI): integer[]?, number?),
---  choose_choice?: (fun(self: AI.ChooseCardsAndChoiceStrategy, ai: SmartAI): string?, number?),
---}
---@return AI.ChooseCardsAndChoiceStrategy
local function newChooseCardsAndChoiceStrategy(spec)
  local ret = ChooseCardsAndChoiceStrategy:new()
  if spec.choose_cards then
    ret.chooseCards = spec.choose_cards
  end
  if spec.choose_choice then
    ret.chooseChoice = spec.choose_choice
  end

  return ret
end

return {
  ChooseCardsAndChoiceStrategy,
  newChooseCardsAndChoiceStrategy,
}

