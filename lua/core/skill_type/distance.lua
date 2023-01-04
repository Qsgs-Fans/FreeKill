---@class DistanceSkill : Skill
---@field global boolean
local DistanceSkill = Skill:subclass("DistanceSkill")

function DistanceSkill:initialize(name)
  Skill.initialize(self, name, Skill.NotFrequent)

  self.global = false
end

---@param from Player
---@param to Player
---@return integer
function DistanceSkill:getCorrect(from, to)
  return 0
end

return DistanceSkill
