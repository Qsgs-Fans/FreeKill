-- SPDX-License-Identifier: GPL-3.0-or-later

---@class ProhibitSkill : StatusSkill
local ProhibitSkill = StatusSkill:subclass("ProhibitSkill")

--- 判定是否合法目标
---@param from Player? 使用者
---@param to Player @ 使用目标
---@param card Card @ 使用的牌
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

---@param from Player
---@param to Player
---@return boolean
function ProhibitSkill:prohibitPindian(from, to)
  return false
end

return ProhibitSkill
