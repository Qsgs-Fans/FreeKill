---@class MaxCardsSkill : StatusSkill
local MaxCardsSkill = StatusSkill:subclass("MaxCardsSkill")

---@param from Player
---@param to Player
---@return integer
function MaxCardsSkill:getFixed(player)
  return nil
end

---@param from Player
---@param to Player
---@return integer
function MaxCardsSkill:getCorrect(player)
  return 0
end

return MaxCardsSkill
