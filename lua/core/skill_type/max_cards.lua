---@class MaxCardsSkill : Skill
---@field global boolean
local MaxCardsSkill = Skill:subclass("MaxCardsSkill")

function MaxCardsSkill:initialize(name)
  Skill.initialize(self, name, Skill.NotFrequent)

  self.global = false
end

---@param from Player
---@param to Player
---@return integer
function MaxCardsSkill:getFixed(player)
  return nil
end

---@param from Player
---@param to Player
---@return integer
function MaxCardsSkill:getCorrect(player)
  return 0
end

return MaxCardsSkill
