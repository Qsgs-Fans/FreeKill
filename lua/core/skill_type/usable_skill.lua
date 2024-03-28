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

  self.max_use_time = {9999, 9999, 9999, 9999}
end

function UsableSkill:getMaxUseTime(player, scope, card, to)
  scope = scope or Player.HistoryTurn
  local ret = self.max_use_time[scope]
  local status_skills = Fk:currentRoom().status_skills[TargetModSkill] or Util.DummyTable
  for _, skill in ipairs(status_skills) do
    local correct = skill:getResidueNum(player, self, scope, card, to)
    if correct == nil then correct = 0 end
    ret = ret + correct
  end
  return ret
end

function UsableSkill:withinTimesLimit(player, scope, card, card_name, to)
  if to and to.dead then return false end
  scope = scope or Player.HistoryTurn
  local status_skills = Fk:currentRoom().status_skills[TargetModSkill] or Util.DummyTable
  if not card and self.name:endsWith("_skill") then
    card = Fk:cloneCard(self.name:sub(1, #self.name - 6))
  end
  for _, skill in ipairs(status_skills) do
    if skill:bypassTimesCheck(player, self, scope, card, to) then return true end
  end

  card_name = card_name or card.trueName
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

  return player:usedCardTimes(card_name, scope) < self:getMaxUseTime(player, scope, card, to) or
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

return UsableSkill
