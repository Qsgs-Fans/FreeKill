---@class ProhibitSkill : StatusSkill
local ProhibitSkill = StatusSkill:subclass("ProhibitSkill")

---@param from Player
---@param to Player
---@param card Card
---@return integer
function ProhibitSkill:isProhibited(from, to, card)
  return 0
end

return ProhibitSkill
