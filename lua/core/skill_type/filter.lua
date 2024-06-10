-- SPDX-License-Identifier: GPL-3.0-or-later

---@class FilterSkill: StatusSkill
local FilterSkill = StatusSkill:subclass("FilterSkill")

---@param card Card
---@param player Player
---@param isJudgeEvent bool
function FilterSkill:cardFilter(card, player, isJudgeEvent)
  return false
end

---@param card Card
---@param player Player
---@return Card
function FilterSkill:viewAs(card, player)
  return nil
end

---@param skill Skill
---@param player Player
---@return string
function FilterSkill:equipSkillFilter(skill, player)
  return nil
end

return FilterSkill
