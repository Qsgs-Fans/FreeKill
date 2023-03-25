---@class UsableSkill : Skill
---@field public max_use_time integer[]
---@field public expand_pile string
local UsableSkill = Skill:subclass("UsableSkill")

function UsableSkill:initialize(name, frequency)
  frequency = frequency or Skill.NotFrequent
  Skill.initialize(self, name, frequency)

  self.max_use_time = {9999, 9999, 9999, 9999}
end

function UsableSkill:getMaxUseTime(player, scope, card)
  scope = scope or Player.HistoryTurn
  local ret = self.max_use_time[scope]
  local status_skills = Fk:currentRoom().status_skills[TargetModSkill] or {}
  for _, skill in ipairs(status_skills) do
    local correct = skill:getResidueNum(player, self, scope, card)
    if correct == nil then correct = 0 end
    ret = ret + correct
  end
  return ret
end

return UsableSkill
