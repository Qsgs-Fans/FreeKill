local AIStrategy = require "lunarltk.server.ai.strategy"

---@class AI.YijiStrategy : AIStrategy
local YijiStrategy = AIStrategy:subclass("AI.YijiStrategy")

---@param ai SmartAI
---@return integer[]?, number?
function YijiStrategy:chooseCards(ai)
end

---@param ai SmartAI
---@return ServerPlayer[]?, number?
function YijiStrategy:choosePlayers(ai)
end

---@param spec {
---  choose_cards?: (fun(self: AI.YijiStrategy, ai: SmartAI): integer[]?, number?),
---  choose_players?: (fun(self: AI.YijiStrategy, ai: SmartAI): ServerPlayer[]?, number?),
---}
---@return AI.YijiStrategy
local function newYijiStrategy(spec)
  local ret = YijiStrategy:new()
  if spec.choose_cards then
    ret.chooseCards = spec.choose_cards
  end

  if spec.choose_players then
    ret.choosePlayers = spec.choose_players
  end

  return ret
end

return {
  YijiStrategy,
  newYijiStrategy,
}

