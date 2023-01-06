---@class ViewAsSkill
---@field pattern string @ cards that can be viewAs'ed by this skill
local ViewAsSkill = Skill:subclass("ViewAsSkill")

function ViewAsSkill:initialize(name)
  Skill.initialize(self, name, Skill.NotFrequent)
  self.pattern = ""
end

---@param to_select integer @ id of a card not selected
---@param selected integer[] @ ids of selected cards
---@return boolean
function ViewAsSkill:cardFilter(to_select, selected)
  return false
end

---@param cards integer[] @ ids of cards
---@return card
function ViewAsSkill:viewAs(cards)
  return nil
end

-- For extra judgement, like mark or HP

---@param player Player
function ViewAsSkill:enabledAtPlay(player)
  return true
end

---@param player Player
function ViewAsSkill:enabledAtResponse(player)
  return true
end

return ViewAsSkill
