---@class ViewAsSkill
---@field available_cards string @ cards that can be viewAs'ed by this skill
local ViewAsSkill = Skill:subclass("ViewAsSkill")

function ViewAsSkill:initialize(name)
  Skill.initialize(self, name, Skill.NotFrequent)
  self.available_cards = ""
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


return ViewAsSkill
