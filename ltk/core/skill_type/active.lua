-- SPDX-License-Identifier: GPL-3.0-or-later

---@class ActiveSkill : ButtonSkill
local ActiveSkill = ButtonSkill:subclass("ActiveSkill")

---------
-- 注：客户端函数，AI也会调用以作主动技判断
------- {

-- 判断该技能是否可主动发动
---@param player Player @ 使用者
---@param card? Card @ 牌，若该技能是卡牌的效果技能，需输入此值
---@param extra_data? UseExtraData @ 额外数据
---@return boolean?
function ActiveSkill:canUse(player, card, extra_data)
  return self:isEffectable(player) and self:withinTimesLimit(player, Player.HistoryPhase, card)
end

-- 获取选择时的固定目标。注意，不需要进行任何合法性判断
---@param player Player @ 使用者
---@param selected_cards integer[] @ 已选牌
---@param card? Card @ 牌
---@param extra_data? UseExtraData @ 额外数据
---@return Player[]? @ 返回固定目标角色列表。若此牌可以选择目标，返回空表
function ActiveSkill:fixTargets(player, selected_cards, card, extra_data)
  if self:getMaxTargetNum(player) == 0 then
    return {}
  end
  return nil
end

------- }

return ActiveSkill
