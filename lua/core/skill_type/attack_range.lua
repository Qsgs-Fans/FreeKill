-- SPDX-License-Identifier: GPL-3.0-or-later

---@class AttackRangeSkill : StatusSkill
local AttackRangeSkill = StatusSkill:subclass("AttackRangeSkill")

---@param from Player
---@return integer
function AttackRangeSkill:getCorrect(from)
  return 0
end

---@param from Player
---@return integer|nil
function AttackRangeSkill:getFixed(from)
  return nil
end

function AttackRangeSkill:withinAttackRange(from, to)
  return false
end

return AttackRangeSkill
