local AIStrategy = require "lunarltk.server.ai.strategy"

---@class AI.ChoicesStrategy : AIStrategy
local ChoicesStrategy = AIStrategy:subclass("AI.ChoicesStrategy")

---@return string[]?, number?
function ChoicesStrategy:think(ai)
end

---@param val string[]?
---@return string[]?
function ChoicesStrategy:convertThinkResult(val)
  if not val then return end
  return val
end



---@param spec {
--- think?: fun(self: AI.ChoicesStrategy, ai: SmartAI)
--- }
---@return AI.ChoicesStrategy
local function newChoicesStrategy(spec)
  local ret = ChoicesStrategy:new()

  if spec.think then ret.think = spec.think end

  return ret
end

return {
  ChoicesStrategy,
  newChoicesStrategy,
}

