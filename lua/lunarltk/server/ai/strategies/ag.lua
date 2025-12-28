local AIStrategy = require "lunarltk.server.ai.strategy"

---@class AI.AGStrategy : AIStrategy
local AGStrategy = AIStrategy:subclass("AI.AGStrategy")

---@return integer?, number?
function AGStrategy:think(ai)
end

---@param val integer?
---@return integer?
function AGStrategy:convertThinkResult(val)
  if not val then return end
  return val
end



---@param spec {
--- think?: fun(self: AI.AGStrategy, ai: SmartAI)
--- }
---@return AI.AGStrategy
local function newAGStrategy(spec)
  local ret = AGStrategy:new()

  if spec.think then ret.think = spec.think end

  return ret
end

return {
  AGStrategy,
  newAGStrategy,
}

