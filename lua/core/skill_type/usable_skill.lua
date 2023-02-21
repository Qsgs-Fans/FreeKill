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

---@param player Player
function UsableSkill:getMinTargetNum(player, card)
  local ret = type(self.target_num) == "table" and self.target_num[1] or self.target_num
  return ret
end

function UsableSkill:getMaxTargetNum(player, card)
  local ret = type(self.target_num) == "table" and self.target_num[2] or self.target_num
  local status_skills = Fk:currentRoom().status_skills[TargetModSkill] or {}
  for _, skill in ipairs(status_skills) do
    local correct = skill:getExtraTargetNum(player, self, card)
    if correct == nil then correct = 0 end
    ret = ret + correct
  end
  return ret
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

function UsableSkill:getDistanceLimit(player, card)
  local ret = self.distance_limit
  local status_skills = Fk:currentRoom().status_skills[TargetModSkill] or {}
  for _, skill in ipairs(status_skills) do
    local correct = skill:getDistanceLimit(player, self, card)
    if correct == nil then correct = 0 end
    ret = ret + correct
  end
  return ret
end

return UsableSkill
