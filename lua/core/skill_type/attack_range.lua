-- SPDX-License-Identifier: GPL-3.0-or-later

---@class AttackRangeSkill : StatusSkill
local AttackRangeSkill = StatusSkill:subclass("AttackRangeSkill")

---@param from Player
---@param to Player
---@return integer
function AttackRangeSkill:getCorrect(from, to)
  return 0
end

return AttackRangeSkill
