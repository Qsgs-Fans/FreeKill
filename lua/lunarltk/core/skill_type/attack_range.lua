-- SPDX-License-Identifier: GPL-3.0-or-later

---@class AttackRangeSkill : StatusSkill
local AttackRangeSkill = StatusSkill:subclass("AttackRangeSkill")

--- 获取角色攻击范围修改值
---@param from Player
---@param to? Player @ 目标角色，可能不存在
---@return integer
function AttackRangeSkill:getCorrect(from, to)
  return 0
end

--- 获取角色攻击范围初值
---@param from Player
---@return integer|nil
function AttackRangeSkill:getFixed(from)
  return nil
end

--- 获取角色攻击范围终值
---@param from Player
---@return integer|nil
function AttackRangeSkill:getFinal(from)
  return nil
end

---@param from Player
---@param to Player
---@return boolean
function AttackRangeSkill:withinAttackRange(from, to)
  return false
end

---@param from Player
---@param to Player
---@return boolean
function AttackRangeSkill:withoutAttackRange(from, to)
  return false
end

return AttackRangeSkill
