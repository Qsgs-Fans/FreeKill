-- SPDX-License-Identifier: GPL-3.0-or-later

---@class MaxCardsSkill : StatusSkill
local MaxCardsSkill = StatusSkill:subclass("MaxCardsSkill")

---@return integer?
function MaxCardsSkill:getFixed(player)
  return nil
end

---@return integer
function MaxCardsSkill:getCorrect(player)
  return 0
end

---@param card Card
---@return boolean
function MaxCardsSkill:excludeFrom(player, card)
  return false
end

return MaxCardsSkill
