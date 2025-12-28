local AIStrategy = require "lunarltk.server.ai.strategy"

---@class AI.ChooseCardsAndPlayersStrategy : AIStrategy
local ChooseCardsAndPlayersStrategy = AIStrategy:subclass("AI.ChooseCardsAndPlayersStrategy")

---@param ai SmartAI
---@return integer[]?, number?
function ChooseCardsAndPlayersStrategy:chooseCards(ai)
end

---@param ai SmartAI
---@return ServerPlayer[]?, number?
function ChooseCardsAndPlayersStrategy:choosePlayers(ai)
end

---@param spec {
---  choose_cards?: (fun(self: AI.ChooseCardsAndPlayersStrategy, ai: SmartAI): integer[]?, number?),
---  choose_players?: (fun(self: AI.ChooseCardsAndPlayersStrategy, ai: SmartAI): ServerPlayer[]?, number?),
---}
---@return AI.ChooseCardsAndPlayersStrategy
local function newChooseCardsAndPlayersStrategy(spec)
  local ret = ChooseCardsAndPlayersStrategy:new()
  if spec.choose_cards then
    ret.chooseCards = spec.choose_cards
  end

  if spec.choose_players then
    ret.choosePlayers = spec.choose_players
  end

  return ret
end

return {
  ChooseCardsAndPlayersStrategy,
  newChooseCardsAndPlayersStrategy,
}

