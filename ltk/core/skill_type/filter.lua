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

--将此牌的技能改为另一技能
---@param card Card @ 之前的牌
---@param player Player
---@return string
function FilterSkill:cardSkillFilter(card, player)
  return nil
end

--视为拥有某技能（可通过hasSkill判定，无按钮，需先将技能手动加入Room）
---@param player Player
---@return string[]
function FilterSkill:skillFilter(player)
  return {}
end

--- 判定此牌的图像视为什么牌名
---@param card Card @ 待判定的牌
---@return string? @ 牌名
function FilterSkill:cardPicFilter(card)
  return nil
end

return FilterSkill
