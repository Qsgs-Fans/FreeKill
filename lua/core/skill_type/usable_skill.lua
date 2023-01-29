---@class UsableSkill : Skill
---@field target_num integer|integer[]
---@field max_use_time integer[]
---@field distance_limit integer
local UsableSkill = Skill:subclass("UsableSkill")

function UsableSkill:initialize(name, frequency)
  frequency = frequency or Skill.NotFrequent
  Skill.initialize(self, name, frequency)

  self.target_num = 9999
  self.max_use_time = {9999, 9999, 9999, 9999}
  self.distance_limit = 9999
end

function UsableSkill:getMinTargetNum()
  return type(self.target_num) == "table" and self.target_num[1] or self.target_num
end

function UsableSkill:getMaxTargetNum()
  return type(self.target_num) == "table" and self.target_num[2] or self.target_num
end

function UsableSkill:getMaxUseTime(scope)
  scope = scope or Player.HistoryTurn
  return self.max_use_time[scope]
end

function UsableSkill:getDistanceLimit()
  return self.distance_limit
end

return UsableSkill
