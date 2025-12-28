local AIStrategy = require "lunarltk.server.ai.strategy"

---@class AI.ExchangeStrategy : AIStrategy
local ExchangeStrategy = AIStrategy:subclass("AI.ExchangeStrategy")

---@param ai SmartAI
---@return table[]?, number?
function ExchangeStrategy:think(ai)
end

---@param spec {
---  think?: (fun(self: AI.ExchangeStrategy, ai: SmartAI): table[]?, number?),
---}
---@return AI.ExchangeStrategy
local function newExchangeStrategy(spec)
  local ret = ExchangeStrategy:new()
  if spec.think then
    ret.think = spec.think
  end

  return ret
end

return {
  ExchangeStrategy,
  newExchangeStrategy,
}

