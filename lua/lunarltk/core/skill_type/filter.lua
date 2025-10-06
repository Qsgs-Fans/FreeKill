-- SPDX-License-Identifier: GPL-3.0-or-later

---@class FilterSkill: StatusSkill
local FilterSkill = StatusSkill:subclass("FilterSkill")

--- 判定此牌能否被应用锁视
---@param card Card @ 待判定的牌
---@param player Player @ 有关的角色
---@param isJudgeEvent boolean? @ 是否判定事件
function FilterSkill:cardFilter(card, player, isJudgeEvent)
  return false
end

--- 将此牌视为什么
---@param player Player @ 有关的角色
---@param card Card @ 之前的牌
---@return Card
function FilterSkill:viewAs(player, card)
  return card
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
