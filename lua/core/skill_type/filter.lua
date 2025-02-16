-- SPDX-License-Identifier: GPL-3.0-or-later

---@class FilterSkill: StatusSkill
local FilterSkill = StatusSkill:subclass("FilterSkill")

---@param card Card
---@param player Player
---@param isJudgeEvent boolean?
function FilterSkill:cardFilter(card, player, isJudgeEvent)
  return false
end

---@param player Player
---@param card Card
---@return Card?
function FilterSkill:viewAs(player, card)
  return nil
end

---@param skill Skill
---@param player Player
---@return string
function FilterSkill:equipSkillFilter(skill, player)
  return nil
end

--- 视为拥有的如手牌般使用的牌
---@param player Player
---@return integer[]
function FilterSkill:handlyCardsFilter(player)
  return {}
end

return FilterSkill
