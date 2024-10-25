-- SPDX-License-Identifier: GPL-3.0-or-later

---@class TargetModSkill : StatusSkill
local TargetModSkill = StatusSkill:subclass("TargetModSkill")

---@param player Player
---@param card_skill ActiveSkill
---@param scope integer
---@param card Card
function TargetModSkill:bypassTimesCheck(player, card_skill, scope, card, to)
  return false
end

---@param player Player
---@param card_skill ActiveSkill
---@param scope integer
---@param card Card
function TargetModSkill:getResidueNum(player, card_skill, scope, card, to)
  return 0
end

---@param player Player
---@param card_skill ActiveSkill
---@param card Card
function TargetModSkill:bypassDistancesCheck(player, card_skill, card, to)
  return false
end

---@param player Player
---@param card_skill ActiveSkill
---@param card Card
function TargetModSkill:getDistanceLimit(player, card_skill, card, to)
  return 0
end

---@param player Player
---@param card_skill ActiveSkill
---@param card Card
function TargetModSkill:getExtraTargetNum(player, card_skill, card)
  return 0
end

---@param player Player
---@param to_select integer @ id of the target
---@param selected integer[] @ ids of selected targets
---@param selected_cards integer[] @ ids of selected cards
---@param card Card @ helper
---@param selectable boolean @can be selected
---@param extra_data? any @ extra_data
function TargetModSkill:getTargetTip(player, to_select, selected, selected_cards, card, selectable, extra_data) end

return TargetModSkill
