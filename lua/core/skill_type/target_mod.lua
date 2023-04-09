-- SPDX-License-Identifier: GPL-3.0-or-later

---@class TargetModSkill : StatusSkill
local TargetModSkill = StatusSkill:subclass("TargetModSkill")

---@param player Player
---@param card_skill ActiveSkill
function TargetModSkill:getResidueNum(player, card_skill, scope, card)
  return 0
end

---@param player Player
---@param card_skill ActiveSkill
function TargetModSkill:getDistanceLimit(player, card_skill, card)
  return 0
end

---@param player Player
---@param card_skill ActiveSkill
function TargetModSkill:getExtraTargetNum(player, card_skill, card)
  return 0
end

return TargetModSkill
