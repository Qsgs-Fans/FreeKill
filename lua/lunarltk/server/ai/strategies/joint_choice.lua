local AIStrategy = require "lunarltk.server.ai.strategy"

---@class AI.JointChoiceStrategy : AIStrategy
local JointChoiceStrategy = AIStrategy:subclass("AI.JointChoiceStrategy")

---@return string?, number?
function JointChoiceStrategy:think(ai)
end

---@param val string?
function JointChoiceStrategy:convertThinkResult(val)
  if not val then return end
  return val
end



---@param spec {
--- think?: fun(self: AI.JointChoiceStrategy, ai: SmartAI)
--- }
---@return AI.JointChoiceStrategy
local function newJointChoiceStrategy(spec)
  local ret = JointChoiceStrategy:new()

  if spec.think then ret.think = spec.think end

  return ret
end

return {
  JointChoiceStrategy,
  newJointChoiceStrategy,
}

