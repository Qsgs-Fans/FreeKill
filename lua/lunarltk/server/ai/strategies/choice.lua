local AIStrategy = require "lunarltk.server.ai.strategy"

---@class AI.ChoiceStrategy : AIStrategy
local ChoiceStrategy = AIStrategy:subclass("AI.ChoiceStrategy")

---@return string?, number?
function ChoiceStrategy:think(ai)
end

---@param val string?
---@return string?
function ChoiceStrategy:convertThinkResult(val)
  if not val then return end
  return val
end



---@param spec {
--- think?: fun(self: AI.ChoiceStrategy, ai: SmartAI)
--- }
---@return AI.ChoiceStrategy
local function newChoiceStrategy(spec)
  local ret = ChoiceStrategy:new()

  if spec.think then ret.think = spec.think end

  return ret
end

return {
  ChoiceStrategy,
  newChoiceStrategy,
}

