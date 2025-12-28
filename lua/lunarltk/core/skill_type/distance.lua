-- SPDX-License-Identifier: GPL-3.0-or-later

---@class DistanceSkill : StatusSkill
local DistanceSkill = StatusSkill:subclass("DistanceSkill")

---@param from Player
---@param to Player
---@param card? Card
---@return integer
function DistanceSkill:getCorrect(from, to, card)
  return 0
end

---@param from Player
---@param to Player
---@param card? Card
---@return integer|nil
function DistanceSkill:getFixed(from, to, card)
  return nil
end

return DistanceSkill
