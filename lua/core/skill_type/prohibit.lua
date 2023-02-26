---@class ProhibitSkill : StatusSkill
local ProhibitSkill = StatusSkill:subclass("ProhibitSkill")

---@param from Player
---@param to Player
---@param card Card
---@return boolean
function ProhibitSkill:isProhibited(from, to, card)
  return false
end

---@param player Player
---@param card Card
function ProhibitSkill:prohibitUse(player, card)
  return false
end

---@param player Player
---@param card Card
function ProhibitSkill:prohibitResponse(player, card)
  return false
end

---@param player Player
---@param card Card
function ProhibitSkill:prohibitDiscard(player, card)
  return false
end

return ProhibitSkill
