local AIStrategy = require "lunarltk.server.ai.strategy"

---@class AI.ChooseCardsStrategy : AIStrategy
local ChooseCardsStrategy = AIStrategy:subclass("AI.ChooseCardsStrategy")

---@param ai SmartAI
---@return integer[]?, number?
function ChooseCardsStrategy:think(ai)
end

---@param val integer[]?
---@return integer[]?
function ChooseCardsStrategy:convertThinkResult(val)
  if not val then return end
  return val
end

---@param spec {
---  think?: (fun(self: AI.ChooseCardsStrategy, ai: SmartAI): integer[]?, number?),
---}
---@return AI.ChooseCardsStrategy
local function newChooseCardsStrategy(spec)
  local ret = ChooseCardsStrategy:new()
  if spec.think then
    ret.think = spec.think
  end

  return ret
end

return {
  ChooseCardsStrategy,
  newChooseCardsStrategy,
}

