-- SPDX-License-Identifier: GPL-3.0-or-later

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
---@return boolean
function ProhibitSkill:prohibitUse(player, card)
  return false
end

---@param player Player
---@param card Card
---@return boolean
function ProhibitSkill:prohibitResponse(player, card)
  return false
end

---@param player Player
---@param card Card
---@return boolean
function ProhibitSkill:prohibitDiscard(player, card)
  return false
end

return ProhibitSkill
