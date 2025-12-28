local AIStrategy = require "lunarltk.server.ai.strategy"

---@class AI.ChooseCardStrategy : AIStrategy
local ChooseCardStrategy = AIStrategy:subclass("AI.ChooseCardStrategy")

---@return integer?, number?
function ChooseCardStrategy:think(ai)
end

---@param val integer?
---@return integer?
function ChooseCardStrategy:convertThinkResult(val)
  if not val then return end
  return val
end



---@param spec {
--- think?: fun(self: AI.ChooseCardStrategy, ai: SmartAI)
--- }
---@return AI.ChooseCardStrategy
local function newChooseCardStrategy(spec)
  local ret = ChooseCardStrategy:new()

  if spec.think then ret.think = spec.think end

  return ret
end

return {
  ChooseCardStrategy,
  newChooseCardStrategy,
}

