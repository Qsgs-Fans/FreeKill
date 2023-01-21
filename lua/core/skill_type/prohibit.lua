---@class ProhibitSkill : Skill
---@field global boolean
local ProhibitSkill = Skill:subclass("ProhibitSkill")

function ProhibitSkill:initialize(name)
  Skill.initialize(self, name, Skill.NotFrequent)

  self.global = false
end

---@param from Player
---@param to Player
---@param card Card
---@return integer
function ProhibitSkill:isProhibited(from, to, card)
  return 0
end

return ProhibitSkill
