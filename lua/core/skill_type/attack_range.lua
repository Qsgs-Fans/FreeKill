---@class AttackRangeSkill : Skill
---@field global boolean
local AttackRangeSkill = Skill:subclass("AttackRangeSkill")

function AttackRangeSkill:initialize(name)
  Skill.initialize(self, name, Skill.NotFrequent)

  self.global = false
end

---@param from Player
---@param to Player
---@return integer
function AttackRangeSkill:getCorrect(from, to)
  return 0
end

return AttackRangeSkill
