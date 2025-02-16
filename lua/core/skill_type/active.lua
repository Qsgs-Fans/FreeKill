-- SPDX-License-Identifier: GPL-3.0-or-later

---@class ActiveSkill : UsableSkill
---@field public min_target_num integer
---@field public max_target_num integer
---@field public target_num integer
---@field public target_num_table integer[]
---@field public min_card_num integer
---@field public max_card_num integer
---@field public card_num integer
---@field public card_num_table integer[]
---@field public interaction any
---@field public prompt string | function? @ 技能提示
---@field public handly_pile boolean?  @ 是否能够选择“如手牌使用或打出”的牌
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

-- 判断一张牌是否可被此技能选中
---@param player Player @ 使用者
---@param to_select integer @ 待选牌
---@param selected integer[] @ 已选牌
---@return boolean?
function ActiveSkill:cardFilter(player, to_select, selected)
  return true
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
  --FIXME: 删除了distance_limit牢参数，看看如何适配牢代码
  return false
end

---@param player Player @ 使用者
---@param card? Card @ 牌
---@param extra_data? UseExtraData @ 额外数据
---@return Player[]?
function ActiveSkill:fixTargets(player, card, extra_data)
  return nil
end

-- 获得技能的最小目标数
---@param player Player @ 使用者
---@return number @ 最小目标数
function ActiveSkill:getMinTargetNum(player)
  local ret
  if self.target_num then ret = self.target_num
  elseif self.target_num_table then ret = self.target_num_table
  else ret = self.min_target_num end

  if type(ret) == "function" then
    ret = ret(self, player)
  end
  if type(ret) == "table" then
    return ret[1]
  else
    return ret
  end
end

-- 获得技能的最大目标数
---@param player? Player @ 使用者
---@param card? Card @ 牌
---@return number @ 最大目标数
function ActiveSkill:getMaxTargetNum(player, card)
  local ret
  if self.target_num then ret = self.target_num
  elseif self.target_num_table then ret = self.target_num_table
  else ret = self.max_target_num end

  if type(ret) == "function" then
    ret = ret(self, player, card)
  end
  if type(ret) == "table" then
    ret = ret[#ret]
  end

  if player and card then
    local status_skills = Fk:currentRoom().status_skills[TargetModSkill] or Util.DummyTable
    for _, skill in ipairs(status_skills) do
      local correct = skill:getExtraTargetNum(player, self, card)
      if correct == nil then correct = 0 end
      ret = ret + correct
    end
  end
  return ret
end

-- 获得技能的最小卡牌数
---@param player Player @ 使用者
---@return number @ 最小卡牌数
function ActiveSkill:getMinCardNum(player)
  local ret
  if self.card_num then ret = self.card_num
  elseif self.card_num_table then ret = self.card_num_table
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
  elseif self.card_num_table then ret = self.card_num_table
  else ret = self.max_card_num end

  if type(ret) == "function" then
    ret = ret(self, player)
  end
  if type(ret) == "table" then
    return ret[#ret]
  else
    return ret
  end
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
  if not to or player:distanceTo(to) < 1 then return false end
  local status_skills = Fk:currentRoom().status_skills[TargetModSkill] or Util.DummyTable
  if not card and self.name:endsWith("_skill") then
    card = Fk:cloneCard(self.name:sub(1, #self.name - 6))
  end
  for _, skill in ipairs(status_skills) do
    if skill:bypassDistancesCheck(player, self, card, to) then return true end
  end

  local temp_suf = table.simpleClone(MarkEnum.TempMarkSuffix)
  local card_temp_suf = table.simpleClone(MarkEnum.CardTempMarkSuffix)

  ---@param object Card|Player
  ---@param markname string
  ---@param suffixes string[]
  ---@return boolean
  local function hasMark(object, markname, suffixes)
    if not object then return false end
    for mark, _ in pairs(object.mark) do
      if mark == markname then return true end
      if mark:startsWith(markname .. "-") then
        for _, suffix in ipairs(suffixes) do
          if mark:find(suffix, 1, true) then return true end
        end
      end
    end
    return false
  end

  return (isattack and player:inMyAttackRange(to)) or
  (player:distanceTo(to) <= self:getDistanceLimit(player, card, to)) or
  hasMark(card, MarkEnum.BypassDistancesLimit, card_temp_suf) or
  hasMark(player, MarkEnum.BypassDistancesLimit, temp_suf) or
  hasMark(to, MarkEnum.BypassDistancesLimitTo, temp_suf)
  -- (card and table.find(card_temp_suf, function(s)
  --   return card:getMark(MarkEnum.BypassDistancesLimit .. s) ~= 0
  -- end)) or
  -- (table.find(temp_suf, function(s)
  --   return player:getMark(MarkEnum.BypassDistancesLimit .. s) ~= 0
  -- end)) or
  -- (to and (table.find(temp_suf, function(s)
  --   return to:getMark(MarkEnum.BypassDistancesLimitTo .. s) ~= 0
  -- end)))
end

-- 判断一个技能是否可发动（也就是确认键是否可点击）。默认值为选择卡牌数和选择目标数均在允许范围内
-- 警告：没啥事别改
---@param player Player @ 使用者
---@param selected Player[] @ 已选目标
---@param selected_cards integer[] @ 已选牌
---@param card? Card @ 牌
---@return boolean
function ActiveSkill:feasible(player, selected, selected_cards, card)
  return #selected >= self:getMinTargetNum(player) and #selected <= self:getMaxTargetNum(player, card)
    and #selected_cards >= self:getMinCardNum(player) and #selected_cards <= self:getMaxCardNum(player)
end

-- 使用技能时默认的烧条提示（一般会在主动使用时出现）
---@param player Player @ 使用者
---@param selected_cards integer[] @ 已选牌
---@param selected_targets Player[] @ 已选目标
---@return string?
function ActiveSkill:prompt(player, selected_cards, selected_targets) return "" end

------- }

---@param room Room
---@param cardUseEvent UseCardData | SkillUseData
function ActiveSkill:onUse(room, cardUseEvent) end

---@param room Room
---@param cardUseEvent UseCardData | SkillEffectEvent
---@param finished? boolean?
function ActiveSkill:onAction(room, cardUseEvent, finished) end

---@param room Room
---@param cardEffectEvent CardEffectData | SkillEffectData
function ActiveSkill:aboutToEffect(room, cardEffectEvent) end

---@param room Room
---@param cardEffectEvent CardEffectData
function ActiveSkill:onEffect(room, cardEffectEvent) end

-- Delayed Trick Only
---@param room Room
---@param cardEffectEvent CardEffectData | SkillEffectData
function ActiveSkill:onNullified(room, cardEffectEvent) end

--- 选择目标时产生的目标提示，贴在目标脸上
---@param player Player @ 使用者
---@param to_select Player @ id of the target
---@param selected Player[] @ ids of selected targets
---@param selected_cards integer[] @ ids of selected cards
---@param card Card? @ helper
---@param selectable boolean? @can be selected
---@param extra_data? any @ extra_data
---@return string|table?
function ActiveSkill:targetTip(player, to_select, selected, selected_cards, card, selectable, extra_data) end

return ActiveSkill
