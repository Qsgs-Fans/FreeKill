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
-- Note: these functions are used both client and ai
------- {

--- Determine whether the skill can be used in playing phase
---@param player Player
---@param card Card @ helper
function ActiveSkill:canUse(player, card)
  return self:isEffectable(player)
end

--- Determine whether a card can be selected by this skill
--- only used in skill of players
---@param to_select integer @ id of a card not selected
---@param selected integer[] @ ids of selected cards
---@param selected_targets integer[] @ ids of selected players
function ActiveSkill:cardFilter(to_select, selected, selected_targets)
  return true
end

--- Determine whether a target can be selected by this skill
--- only used in skill of players
---@param to_select integer @ id of the target
---@param selected integer[] @ ids of selected targets
---@param selected_cards integer[] @ ids of selected cards
---@param card Card @ helper
function ActiveSkill:targetFilter(to_select, selected, selected_cards, card)
  return false
end

--- Determine whether a target can be selected by this skill(in modifying targets)
--- only used in skill of players
---@param to_select integer @ id of the target
---@param selected nil|integer[] @ ids of selected targets
---@param user nil|integer @ id of the userdata
---@param card nil|Card @ helper
---@param distance_limited boolean @ is limited by distance
function ActiveSkill:modTargetFilter(to_select, selected, user, card, distance_limited)
  return false
end

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

--- Determine if selected cards and targets are valid for this skill
--- If returns true, the OK button should be enabled
--- only used in skill of players

-- NOTE: don't reclaim it
---@param selected integer[] @ ids of selected players
---@param selected_cards integer[] @ ids of selected cards
function ActiveSkill:feasible(selected, selected_cards, player, card)
  return #selected >= self:getMinTargetNum() and #selected <= self:getMaxTargetNum(player, card)
    and #selected_cards >= self:getMinCardNum() and #selected_cards <= self:getMaxCardNum()
end

------- }

---@param room Room
---@param cardUseEvent CardUseStruct
function ActiveSkill:onUse(room, cardUseEvent) end

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

---@param selected integer[] @ ids of selected players
---@param selected_cards integer[] @ ids of selected cards
function ActiveSkill:prompt(selected, selected_cards) return "" end

return ActiveSkill
