---@class TargetModSkill : StatusSkill
local TargetModSkill = StatusSkill:subclass("TargetModSkill")

---@param player Player
---@param card_skill ActiveSkill
function TargetModSkill:getResidueNum(player, card_skill, scope)
  return 0
end

---@param player Player
---@param card_skill ActiveSkill
function TargetModSkill:getDistanceLimit(player, card_skill)
  return 0
end

---@param player Player
---@param card_skill ActiveSkill
function TargetModSkill:getExtraTargetNum(player, card_skill)
  return 0
end

return TargetModSkill
