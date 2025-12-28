local AIStrategy = require "lunarltk.server.ai.strategy"

---@class AI.GuanxingStrategy : AIStrategy
local GuanxingStrategy = AIStrategy:subclass("AI.GuanxingStrategy")

---@param ai SmartAI
---@return table[]?, number?
function GuanxingStrategy:think(ai)
end

---@param val table[]?
---@return table<"top"|"bottom", integer[]>?
function GuanxingStrategy:convertThinkResult(val)
  if not val then return end
  return { top = val[1], bottom = val[2] }
end

---@param spec {
---  think?: (fun(self: AI.GuanxingStrategy, ai: SmartAI): table[]?, number?),
---}
---@return AI.GuanxingStrategy
local function newGuanxingStrategy(spec)
  local ret = GuanxingStrategy:new()
  if spec.think then
    ret.think = spec.think
  end

  return ret
end

return {
  GuanxingStrategy,
  newGuanxingStrategy,
}

