local AIStrategy = require "lunarltk.server.ai.strategy"

---@class AI.MoveBoardStrategy : AIStrategy
local MoveBoardStrategy = AIStrategy:subclass("AI.MoveBoardStrategy")

---@param ai SmartAI
---@return integer?, number?
function MoveBoardStrategy:chooseMoveFrom(ai)
end

---@param ai SmartAI
---@return integer?, number?
function MoveBoardStrategy:chooseMoveTo(ai)
end

---@param spec {
---  choose_move_from?: (fun(self: AI.ActiveStrategy, ai: SmartAI): integer?, number?),
---  choose_move_to?: (fun(self: AI.ActiveStrategy, ai: SmartAI): integer?, number?),
---}
---@return AI.MoveBoardStrategy
local function newMoveBoardStrategy(spec)
  local ret = MoveBoardStrategy:new()
  if spec.choose_move_from then
    ret.chooseMoveFrom = spec.choose_move_from
  end

  if spec.choose_move_to then
    ret.chooseMoveTo = spec.choose_move_to
  end

  return ret
end

return {
  MoveBoardStrategy,
  newMoveBoardStrategy,
}

