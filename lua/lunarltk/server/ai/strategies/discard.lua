local AIStrategy = require "lunarltk.server.ai.strategy"

---@class AI.DiscardStrategy : AIStrategy
local DiscardStrategy = AIStrategy:subclass("AI.DiscardStrategy")

---@param ai SmartAI
---@return integer[]?, number?
function DiscardStrategy:chooseCards(ai)
end

---@param spec {
---  choose_cards?: (fun(self: AI.DiscardStrategy, ai: SmartAI): integer[]?, number?),
---}
---@return AI.DiscardStrategy
local function newDiscardStrategy(spec)
  local ret = DiscardStrategy:new()
  if spec.choose_cards then
    ret.chooseCards = spec.choose_cards
  end

  return ret
end

return {
  DiscardStrategy,
  newDiscardStrategy,
}

