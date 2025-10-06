-- SPDX-License-Identifier: GPL-3.0-or-later

---@class ActiveSkill : UsableSkill
---@field public min_target_num integer
---@field public max_target_num integer
---@field public target_num integer
---@field public min_card_num integer
---@field public max_card_num integer
---@field public card_num integer
---@field public interaction any
---@field public prompt string | function? @ 技能提示
---@field public handly_pile boolean?  @ 是否能够选择“如手牌使用或打出”的牌
---@field public click_count? boolean @ 是否在点击按钮瞬间就计数并播放特效和语音
---@field public include_equip? boolean @ 选牌时是否展开装备区
local ActiveSkill = UsableSkill:subclass("ActiveSkill")

function ActiveSkill:initialize(name, frequency)
  UsableSkill.initialize(self, name, frequency)
  self.min_target_num = 0
  self.max_target_num = 999
  self.min_card_num = 0
  self.max_card_num = 999
end

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

--- 判断一张牌是否可被此技能选中
---@param player Player @ 使用者
---@param to_select integer @ 待选牌
---@param selected integer[] @ 已选牌
---@param selected_targets Player[] @ 已选目标
---@return boolean?
function ActiveSkill:cardFilter(player, to_select, selected, selected_targets)
  return self:getMaxCardNum(player) > 0
end

-- 判断一名角色是否可被此技能选中
---@param player Player @ 使用者
---@param to_select Player @ 待选目标
---@param selected Player[] @ 已选目标
---@param selected_cards integer[] @ 已选牌
---@param card? Card @ 牌
---@param extra_data? UseExtraData @ 额外数据
---@return boolean?
function ActiveSkill:targetFilter(player, to_select, selected, selected_cards, card, extra_data)
  return false
end

-- 判断一名角色是否可成为此技能的目标
---@param player Player @ 使用者
---@param to_select Player @ 待选目标
---@param selected Player[] @ 已选目标
---@param card? Card @ 牌
---@param extra_data? any @ 额外数据
---@return boolean?
function ActiveSkill:modTargetFilter(player, to_select, selected, card, extra_data)
  return false
end

-- 获取使用此牌时的固定目标。注意，不需要进行任何合法性判断
---@param player Player @ 使用者
---@param card? Card @ 牌
---@param extra_data? UseExtraData @ 额外数据
---@return Player[]? @ 返回固定目标角色列表。若此牌可以选择目标，返回空表
function ActiveSkill:fixTargets(player, card, extra_data)
  return nil
end

-- 获得技能的最小目标数
---@param player Player @ 使用者
---@return number @ 最小目标数
function ActiveSkill:getMinTargetNum(player)
  local ret
  if self.target_num then ret = self.target_num
  else ret = self.min_target_num end

  if type(ret) == "function" then
    ret = ret(self, player)
  end
  return ret
end

-- 获得技能的最大目标数
---@param player? Player @ 使用者
---@return number @ 最大目标数
function ActiveSkill:getMaxTargetNum(player)
  local ret
  if self.target_num then ret = self.target_num
  else ret = self.max_target_num end

  if type(ret) == "function" then
    ret = ret(self, player)
  end
  return ret
end

-- 获得技能的最小卡牌数
---@param player Player @ 使用者
---@return number @ 最小卡牌数
function ActiveSkill:getMinCardNum(player)
  local ret
  if self.card_num then ret = self.card_num
  else ret = self.min_card_num end

  if type(ret) == "function" then
    ret = ret(self, player)
  end
  if type(ret) == "table" then
    return ret[1]
  else
    return ret
  end
end

-- 获得技能的最大卡牌数
---@param player Player @ 使用者
---@return number @ 最大卡牌数
function ActiveSkill:getMaxCardNum(player)
  local ret
  if self.card_num then ret = self.card_num
  else ret = self.max_card_num end

  if type(ret) == "function" then
    ret = ret(self, player)
  end
  return ret
end

-- 获得技能的距离限制
---@param player Player @ 使用者
---@param card Card @ 使用卡牌
---@param to Player @ 目标
---@return number @ 距离限制
function ActiveSkill:getDistanceLimit(player, card, to)
  local ret = self.distance_limit or 0
  local status_skills = Fk:currentRoom().status_skills[TargetModSkill] or Util.DummyTable
  for _, skill in ipairs(status_skills) do
    local correct = skill:getDistanceLimit(player, self, card, to)
    if correct == nil then correct = 0 end
    ret = ret + correct
  end
  return ret
end

-- 判断一个角色是否在技能的距离限制内
---@param player Player @ 使用者
---@param isattack boolean? @ 是否使用攻击距离
---@param card Card @ 使用卡牌
---@param to Player @ 目标
---@return boolean?
function ActiveSkill:withinDistanceLimit(player, isattack, card, to)
  if not to or player:distanceTo(to, nil, nil, table.connect(Card:getIdList(card), card.fake_subcards)) < 1 then return false end
  local status_skills = Fk:currentRoom().status_skills[TargetModSkill] or Util.DummyTable
  if not card and self.name:endsWith("_skill") then
    card = Fk:cloneCard(self.name:sub(1, #self.name - 6))
  end
  for _, skill in ipairs(status_skills) do
    if skill:bypassDistancesCheck(player, self, card, to) then return true end
  end

  return (isattack and player:inMyAttackRange(to, nil, table.connect(Card:getIdList(card), card.fake_subcards))) or
  (player:distanceTo(to, nil, nil, table.connect(Card:getIdList(card), card.fake_subcards)) <= self:getDistanceLimit(player, card, to)) or
  not not card:hasMark(MarkEnum.BypassDistancesLimit) or
  not not player:hasMark(MarkEnum.BypassDistancesLimit) or
  not not to:hasMark(MarkEnum.BypassDistancesLimitTo)
end

-- 判断一个技能是否可发动（也就是确认键是否可点击）。默认值为选择卡牌数和选择目标数均在允许范围内
-- 警告：没啥事别改
---@param player Player @ 使用者
---@param selected Player[] @ 已选目标
---@param selected_cards integer[] @ 已选牌
---@return boolean
function ActiveSkill:feasible(player, selected, selected_cards)
  return #selected >= self:getMinTargetNum(player) and #selected <= self:getMaxTargetNum(player)
    and #selected_cards >= self:getMinCardNum(player) and #selected_cards <= self:getMaxCardNum(player)
end

-- 使用技能时默认的烧条提示（一般会在主动使用时出现）
---@param player Player @ 使用者
---@param selected_cards integer[] @ 已选牌
---@param selected_targets Player[] @ 已选目标
---@param extra_data? any
---@return string?
function ActiveSkill:prompt(player, selected_cards, selected_targets, extra_data) return "" end

------- }

--- 发动技能时实际执行的函数
---@param room Room @ 服务端房间
---@param cardUseEvent SkillUseData @ 技能使用数据
function ActiveSkill:onUse(room, cardUseEvent) end




--- 选择目标时产生的目标提示，贴在目标脸上
---@param player Player @ 使用者
---@param to_select Player @ 当前目标
---@param selected Player[] @ 已选角色目标
---@param selected_cards integer[] @ 已选卡牌ID表
---@param card Card? @ (CardSkill?)所使用的牌
---@param selectable boolean? @ 当前目标是否可选择
---@param extra_data? table|UseExtraData @ 额外数据
---@return string|TargetTipDataSpec?
function ActiveSkill:targetTip(player, to_select, selected, selected_cards, card, selectable, extra_data) end

return ActiveSkill
