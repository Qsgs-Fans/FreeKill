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
---@param card Card @ 牌
---@param extra_data UseExtraData @ 额外数据
---@return bool
function ActiveSkill:canUse(player, card, extra_data)
  return self:isEffectable(player)
end

-- 判断一张牌是否可被此技能选中
---@param to_select integer @ 待选牌
---@param selected integer[] @ 已选牌
---@param selected_targets integer[] @ 已选目标
---@return bool
function ActiveSkill:cardFilter(to_select, selected, selected_targets)
  return true
end

-- 判断一名角色是否可被此技能选中
---@param to_select integer @ 待选目标
---@param selected integer[] @ 已选目标
---@param selected_cards integer[] @ 已选牌
---@param card Card @ 牌
---@param extra_data UseExtraData @ 额外数据
---@return bool
function ActiveSkill:targetFilter(to_select, selected, selected_cards, card, extra_data)
  return false
end

-- 判断一名角色是否可成为此技能的目标
---@param to_select integer @ 待选目标
---@param selected integer[] @ 已选目标
---@param user? integer @ 使用者
---@param card? Card @ 牌
---@param distance_limited? boolean @ 是否受距离限制
---@return bool
function ActiveSkill:modTargetFilter(to_select, selected, user, card, distance_limited)
  return false
end

-- 获得技能的最小目标数
---@return number @ 最小目标数
function ActiveSkill:getMinTargetNum()
  local ret
  if self.target_num then ret = self.target_num
  elseif self.target_num_table then ret = self.target_num_table
  else ret = self.min_target_num end

  if type(ret) == "function" then
    ret = ret(self)
  end
  if type(ret) == "table" then
    return ret[1]
  else
    return ret
  end
end

-- 获得技能的最大目标数
---@param player Player @ 使用者
---@param card Card @ 牌
---@return number @ 最大目标数
function ActiveSkill:getMaxTargetNum(player, card)
  local ret
  if self.target_num then ret = self.target_num
  elseif self.target_num_table then ret = self.target_num_table
  else ret = self.max_target_num end

  if type(ret) == "function" then
    ret = ret(self)
  end
  if type(ret) == "table" then
    ret = ret[#ret]
  end

  local status_skills = Fk:currentRoom().status_skills[TargetModSkill] or Util.DummyTable
  for _, skill in ipairs(status_skills) do
    local correct = skill:getExtraTargetNum(player, self, card)
    if correct == nil then correct = 0 end
    ret = ret + correct
  end
  return ret
end

-- 获得技能的最小卡牌数
---@return number @ 最小卡牌数
function ActiveSkill:getMinCardNum()
  local ret
  if self.card_num then ret = self.card_num
  elseif self.card_num_table then ret = self.card_num_table
  else ret = self.min_card_num end

  if type(ret) == "function" then
    ret = ret(self)
  end
  if type(ret) == "table" then
    return ret[1]
  else
    return ret
  end
end

-- 获得技能的最大卡牌数
---@return number @ 最大卡牌数
function ActiveSkill:getMaxCardNum()
  local ret
  if self.card_num then ret = self.card_num
  elseif self.card_num_table then ret = self.card_num_table
  else ret = self.max_card_num end

  if type(ret) == "function" then
    ret = ret(self)
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
---@param isattack bool @ 是否使用攻击距离
---@param card Card @ 使用卡牌
---@param to Player @ 目标
---@return bool
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

-- 判断一个技能是否可发动（也就是确认键是否可点击）
-- 警告：没啥事别改
---@param selected integer[] @ 已选目标
---@param selected_cards integer[] @ 已选牌
---@param player Player @ 使用者
---@param card Card @ 牌
---@return bool
function ActiveSkill:feasible(selected, selected_cards, player, card)
  return #selected >= self:getMinTargetNum() and #selected <= self:getMaxTargetNum(player, card)
    and #selected_cards >= self:getMinCardNum() and #selected_cards <= self:getMaxCardNum()
end

-- 使用技能时默认的烧条提示（一般会在主动使用时出现）
---@param selected_cards integer[] @ 已选牌
---@param selected_targets integer[] @ 已选目标
---@return string?
function ActiveSkill:prompt(selected_cards, selected_targets) return "" end

------- }

---@param room Room
---@param cardUseEvent CardUseStruct
function ActiveSkill:onUse(room, cardUseEvent) end

---@param room Room
---@param cardUseEvent CardUseStruct
---@param finished? bool
function ActiveSkill:onAction(room, cardUseEvent, finished) end

---@param room Room
---@param cardEffectEvent CardEffectEvent | SkillEffectEvent
function ActiveSkill:aboutToEffect(room, cardEffectEvent) end

---@param room Room
---@param cardEffectEvent CardEffectEvent | SkillEffectEvent
function ActiveSkill:onEffect(room, cardEffectEvent) end

-- Delayed Trick Only
---@param room Room
---@param cardEffectEvent CardEffectEvent | SkillEffectEvent
function ActiveSkill:onNullified(room, cardEffectEvent) end

return ActiveSkill
