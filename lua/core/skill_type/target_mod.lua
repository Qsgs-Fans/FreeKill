-- SPDX-License-Identifier: GPL-3.0-or-later

---@class TargetModSkill : StatusSkill
local TargetModSkill = StatusSkill:subclass("TargetModSkill")

-- 使用某技能在某时间段无次数限制
---@param player Player @ 使用者
---@param card_skill ActiveSkill @ 目标技能
---@param scope integer @ 考察时间段
---@param card? Card @ 使用牌时的牌
---@param to? Player @ 目标
function TargetModSkill:bypassTimesCheck(player, card_skill, scope, card, to)
  return false
end

-- 修改某技能在某时间段的次数上限
---@param player Player @ 使用者
---@param card_skill ActiveSkill @ 目标技能
---@param scope integer @ 考察时间段
---@param card? Card @ 使用牌时的牌
---@param to? Player @ 目标
function TargetModSkill:getResidueNum(player, card_skill, scope, card, to)
  return 0
end

-- 使用某技能无距离限制
---@param player Player @ 使用者
---@param card_skill ActiveSkill @ 目标技能
---@param card? Card @ 使用牌时的牌
---@param to? Player @ 目标
function TargetModSkill:bypassDistancesCheck(player, card_skill, card, to)
  return false
end

-- 修改某技能的距离限制
---@param player Player @ 使用者
---@param card_skill ActiveSkill @ 目标技能
---@param card? Card @ 使用牌时的牌
---@param to? Player @ 目标
function TargetModSkill:getDistanceLimit(player, card_skill, card, to)
  return 0
end

-- 修改某技能的额定目标数
---@param player Player @ 使用者
---@param card_skill ActiveSkill @ 目标技能
---@param card? Card @ 使用牌时的牌
function TargetModSkill:getExtraTargetNum(player, card_skill, card)
  return 0
end

-- 技能描述
---@param player Player @ 使用者
---@param to_select integer @ 待选目标
---@param selected integer[] @ 已选目标
---@param selected_cards integer[] @ 已选牌
---@param card? Card @ 使用牌时的牌
---@param selectable boolean @ 待选目标是否可选
---@param extra_data? any @ 额外信息
function TargetModSkill:getTargetTip(player, to_select, selected, selected_cards, card, selectable, extra_data) end

return TargetModSkill
