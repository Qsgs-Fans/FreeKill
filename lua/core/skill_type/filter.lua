-- SPDX-License-Identifier: GPL-3.0-or-later

---@class FilterSkill: StatusSkill
local FilterSkill = StatusSkill:subclass("FilterSkill")

---@param card Card
function FilterSkill:cardFilter(card, player)
  return false
end

---@param card Card
---@return Card
function FilterSkill:viewAs(card, player)
  return nil
end

return FilterSkill
