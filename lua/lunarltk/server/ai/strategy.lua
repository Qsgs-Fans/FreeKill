---@class AIStrategy : Object
---@field skill_name string
local AIStrategy = class("AIStrategy")

--- 判断这个strategy是否是需要的 一般直接返true
---@param ai SmartAI
---@return boolean?
function AIStrategy:matchContext(ai)
  return true
end

function AIStrategy:makeReply(ai)
  local ret, val = self:think(ai)
  return self:convertThinkResult(ret), val or 0
end

--- AI策略统一的“思考”接口，由ai提供上下文 返回策略及其收益
---@param ai SmartAI
---@return any, number?
function AIStrategy:think(ai)
end

--- AI策略还需要将思考结果转为req想要的返回类型
function AIStrategy:convertThinkResult(val)
  return val
end

return AIStrategy
