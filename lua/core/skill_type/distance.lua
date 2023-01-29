---@class DistanceSkill : StatusSkill
local DistanceSkill = StatusSkill:subclass("DistanceSkill")

---@param from Player
---@param to Player
---@return integer
function DistanceSkill:getCorrect(from, to)
  return 0
end

return DistanceSkill
