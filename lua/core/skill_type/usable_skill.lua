-- SPDX-License-Identifier: GPL-3.0-or-later

---@class UsableSkill : Skill
---@field public max_use_time integer[]
---@field public expand_pile string
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
  scope = scope or Player.HistoryTurn
  local status_skills = Fk:currentRoom().status_skills[TargetModSkill] or Util.DummyTable
  for _, skill in ipairs(status_skills) do
    if skill:isUnlimited(player, self, scope, card, to) then return true end
  end
  card_name = card_name or card.trueName
  return player:usedCardTimes(card_name, scope) < self:getMaxUseTime(player, scope, card, to)
end

function UsableSkill:withinDistanceLimit(player, isattack, card, to)
  local status_skills = Fk:currentRoom().status_skills[AttackRangeSkill] or Util.DummyTable
  for _, skill in ipairs(status_skills) do
    if skill:withinAttackRange(player, to) then return true end
  end
  return isattack and player:inMyAttackRange(to, self:getDistanceLimit(player, card, to)) or player:distanceTo(to) <= self:getDistanceLimit(player, card, to)
end

return UsableSkill
