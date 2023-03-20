---@class InvaliditySkill : StatusSkill
local InvaliditySkill = StatusSkill:subclass("InvaliditySkill")

---@param from Player
---@param skill Skill
---@return boolean
function InvaliditySkill:getInvalidity(from, skill)
  return false
end

return InvaliditySkill