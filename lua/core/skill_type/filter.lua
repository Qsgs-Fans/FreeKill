-- SPDX-License-Identifier: GPL-3.0-or-later

---@class FilterSkill: StatusSkill
local FilterSkill = StatusSkill:subclass("FilterSkill")

---@param card Card
function FilterSkill:cardFilter(card)
  return false
end

---@param card Card
---@return Card
function FilterSkill:viewAs(card)
  return nil
end

return FilterSkill
