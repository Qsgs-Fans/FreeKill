-- SPDX-License-Identifier: GPL-3.0-or-later

-- UI专用状态技 表示某张牌、某人身份等可能需要在界面上隐藏的元素是否能被某人看到
-- 默认情况参见client_util.lua: CardVisibility 和player.role_shown

---@class VisibilitySkill : StatusSkill
local VisibilitySkill = StatusSkill:subclass("VisibilitySkill")

---@param player Player
---@param card Card
---@return bool
function VisibilitySkill:cardVisible(player, card)
  return nil
end

---@param player Player
---@return bool
function VisibilitySkill:roleVisible(player, target)
  return nil
end

return VisibilitySkill
