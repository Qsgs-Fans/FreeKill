-- SPDX-License-Identifier: GPL-3.0-or-later

---@class InvaliditySkill : StatusSkill
local InvaliditySkill = StatusSkill:subclass("InvaliditySkill")

--- 判断一名角色的某技能是否被无效
---@param from Player @ 技能拥有者
---@param skill Skill
---@return boolean
function InvaliditySkill:getInvalidity(from, skill)
  return false
end

--- 判断一名角色的某武器的攻击范围是否被无效
---@param player Player @ 武器拥有者
---@param card Weapon
---@return boolean
function InvaliditySkill:getInvalidityAttackRange(player, card)
  return false
end

return InvaliditySkill
