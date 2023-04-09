-- SPDX-License-Identifier: GPL-3.0-or-later

---@class InvaliditySkill : StatusSkill
local InvaliditySkill = StatusSkill:subclass("InvaliditySkill")

---@param from Player
---@param skill Skill
---@return boolean
function InvaliditySkill:getInvalidity(from, skill)
  return false
end

return InvaliditySkill
