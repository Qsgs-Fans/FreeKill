local AIStrategy = require "lunarltk.server.ai.strategy"

---@class AI.ChooseGeneralStrategy : AIStrategy
local ChooseGeneralStrategy = AIStrategy:subclass("AI.ChooseGeneralStrategy")

---@return string?, number?
function ChooseGeneralStrategy:think(ai)
end

---@param val string?
---@return string?
function ChooseGeneralStrategy:convertThinkResult(val)
  if not val then return end
  return val
end



---@param spec {
--- think?: fun(self: AI.ChooseGeneralStrategy, ai: SmartAI)
--- }
---@return AI.ChooseGeneralStrategy
local function newChooseGeneralStrategy(spec)
  local ret = ChooseGeneralStrategy:new()

  if spec.think then ret.think = spec.think end

  return ret
end

return {
  ChooseGeneralStrategy,
  newChooseGeneralStrategy,
}

