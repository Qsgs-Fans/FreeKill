local AIStrategy = require "lunarltk.server.ai.strategy"

---@class AI.ChoosePlayerStrategy : AIStrategy
local ChoosePlayerStrategy = AIStrategy:subclass("AI.ChoosePlayerStrategy")

---@param ai SmartAI
---@return integer[]?, number?
function ChoosePlayerStrategy:chooseCards(ai)
end

---@param ai SmartAI
---@return ServerPlayer[]?, number?
function ChoosePlayerStrategy:choosePlayers(ai)
end

---@param spec {
---  choose_cards?: (fun(self: AI.ChoosePlayerStrategy, ai: SmartAI): integer[]?, number?),
---  choose_players?: (fun(self: AI.ChoosePlayerStrategy, ai: SmartAI): ServerPlayer[]?, number?),
---}
---@return AI.ChoosePlayerStrategy
local function newChoosePlayerStrategy(spec)
  local ret = ChoosePlayerStrategy:new()
  if spec.choose_cards then
    ret.chooseCards = spec.choose_cards
  end

  if spec.choose_players then
    ret.choosePlayers = spec.choose_players
  end

  return ret
end

return {
  ChoosePlayerStrategy,
  newChoosePlayerStrategy,
}

