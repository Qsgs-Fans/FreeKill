local AIStrategy = require "lunarltk.server.ai.strategy"

---@class AI.NumberStrategy : AIStrategy
local NumberStrategy = AIStrategy:subclass("AI.NumberStrategy")

---@param ai SmartAI
---@return integer?, number?
function NumberStrategy:chooseInteraction(ai)
end

---@param spec {
---  choose_interaction?: (fun(self: AI.NumberStrategy, ai: SmartAI): integer?, number?),
---}
---@return AI.NumberStrategy
local function newNumberStrategy(spec)
  local ret = NumberStrategy:new()
  if spec.choose_interaction then
    ret.chooseInteraction = spec.choose_interaction
  end

  return ret
end

return {
  NumberStrategy,
  newNumberStrategy,
}

