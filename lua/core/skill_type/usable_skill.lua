-- SPDX-License-Identifier: GPL-3.0-or-later

---@class UsableSkill : Skill
---@field public main_skill UsableSkill
---@field public max_use_time integer[]
---@field public expand_pile? string | integer[] | fun(self: UsableSkill): integer[]|string?
---@field public derived_piles? string | string[]
local UsableSkill = Skill:subclass("UsableSkill")

function UsableSkill:initialize(name, frequency)
  frequency = frequency or Skill.NotFrequent
  Skill.initialize(self, name, frequency)

  self.max_use_time = { nil, nil, nil, nil }
end

-- 获得技能的最大使用次数
---@param player Player @ 使用者
---@param scope integer @ 查询历史范围（默认为回合）
---@param card? Card @ 卡牌
---@param to? Player @ 目标
---@return number? @ 最大使用次数，nil就是无限
function UsableSkill:getMaxUseTime(player, scope, card, to)
  scope = scope or Player.HistoryTurn
  local ret = self.max_use_time[scope]
  if not ret then return nil end
  local status_skills = Fk:currentRoom().status_skills[TargetModSkill] or Util.DummyTable
  for _, skill in ipairs(status_skills) do
    local correct = skill:getResidueNum(player, self, scope, card, to)
    if correct == nil then correct = 0 end
    ret = ret + correct
  end
  return ret
end

-- 判断一个角色是否在技能的次数限制内
---@param player Player @ 使用者
---@param scope integer @ 查询历史范围（默认为回合）
---@param card? Card @ 牌，若没有牌，则尝试制造一张虚拟牌
---@param card_name? string @ 牌名
---@param to? Player @ 目标
---@return boolean?
function UsableSkill:withinTimesLimit(player, scope, card, card_name, to)
  if to and to.dead then return false end -- 一般情况不会对死人使用技能的……
  scope = scope or Player.HistoryTurn
  local status_skills = Fk:currentRoom().status_skills[TargetModSkill] or Util.DummyTable
  if not card then
    if card_name then
      card = Fk:cloneCard(card_name)
    elseif self.name:endsWith("_skill") then
      card = Fk:cloneCard(self.name:sub(1, #self.name - 6))
    end
  end

  local limit = self:getMaxUseTime(player, scope, card, to)
  if not limit then return true end
  for _, skill in ipairs(status_skills) do
    if skill:bypassTimesCheck(player, self, scope, card, to) then return true end
  end

  if not card_name then
    if card then
      card_name = card.trueName
    else ---坏了，不是卡的技能
      return player:usedSkillTimes(self.name, scope) < limit
    end
  end

  local temp_suf = table.simpleClone(MarkEnum.TempMarkSuffix)
  local card_temp_suf = table.simpleClone(MarkEnum.CardTempMarkSuffix)

  ---@param object? Card|Player
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

  return player:usedCardTimes(card_name, scope) < limit or
  hasMark(card, MarkEnum.BypassTimesLimit, card_temp_suf) or
  hasMark(player, MarkEnum.BypassTimesLimit, temp_suf) or
  hasMark(to, MarkEnum.BypassTimesLimitTo, temp_suf)
  -- (card and table.find(card_temp_suf, function(s)
  --   return card:getMark(MarkEnum.BypassTimesLimit .. s) ~= 0
  -- end)) or
  -- (table.find(temp_suf, function(s)
  --   return player:getMark(MarkEnum.BypassTimesLimit .. s) ~= 0
  -- end)) or
  -- (to and (table.find(temp_suf, function(s)
  --   return to:getMark(MarkEnum.BypassTimesLimitTo .. s) ~= 0
  -- end)))
end

-- 失去此技能时，触发此函数
---@param player ServerPlayer
---@param is_death boolean?
function UsableSkill:onLose(player, is_death)
  local lost_piles = {}
  if self.derived_piles then
    for _, pile_name in ipairs(self.derived_piles) do
      table.insertTableIfNeed(lost_piles, player:getPile(pile_name))
    end
  end

  if #lost_piles > 0 then
    player.room:moveCards({
      ids = lost_piles,
      from = player.id,
      toArea = Card.DiscardPile,
      moveReason = fk.ReasonPutIntoDiscardPile,
    })
  end

  Skill.onLose(self, player, is_death)
end

return UsableSkill
