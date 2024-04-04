-- SPDX-License-Identifier: GPL-3.0-or-later

---@class DistanceSkill : StatusSkill
local DistanceSkill = StatusSkill:subclass("DistanceSkill")

---@param from Player
---@param to Player
---@return integer
function DistanceSkill:getCorrect(from, to)
  return 0
end

---@param from Player
---@param to Player
---@return integer|nil
function DistanceSkill:getFixed(from, to)
  return nil
end

return DistanceSkill
