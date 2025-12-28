local AIStrategy = require "lunarltk.server.ai.strategy"

---@class AI.ChooseKingdomStrategy : AIStrategy
local ChooseKingdomStrategy = AIStrategy:subclass("AI.ChooseKingdomStrategy")

---@return string?, number?
function ChooseKingdomStrategy:think(ai)
end

---@param val string?
function ChooseKingdomStrategy:convertThinkResult(val)
  if not val then return end
  return val
end



---@param spec {
--- think?: fun(self: AI.ChooseKingdomStrategy, ai: SmartAI)
--- }
---@return AI.ChooseKingdomStrategy
local function newChooseKingdomStrategy(spec)
  local ret = ChooseKingdomStrategy:new()

  if spec.think then ret.think = spec.think end

  return ret
end

return {
  ChooseKingdomStrategy,
  newChooseKingdomStrategy,
}

