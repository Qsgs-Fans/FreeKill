---@class ViewAsSkill
---@field
local ViewAsSkill = Skill:subclass("ViewAsSkill")

---@param to_select integer @ id of a card not selected
---@param selected integer[] @ ids of selected cards
---@return boolean
function ViewAsSkill:cardFilter(to_select, selected)
  return true
end

---@param cards integer[] @ ids of cards
---@return card
function ViewAsSkill:viewAs(cards)
  return nil
end


return ViewAsSkill
