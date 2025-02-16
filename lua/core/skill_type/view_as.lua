-- SPDX-License-Identifier: GPL-3.0-or-later

---@class ViewAsSkill : UsableSkill
---@field public pattern string @ cards that can be viewAs'ed by this skill
---@field public interaction any
---@field public handly_pile boolean? @ 能否选择“如手牌般使用或打出”的牌
local ViewAsSkill = UsableSkill:subclass("ViewAsSkill")

function ViewAsSkill:initialize(name, frequency)
  UsableSkill.initialize(self, name, frequency)
  self.pattern = ""
end

---@param player Player @ 你自己
---@param to_select integer @ id of a card not selected
---@param selected integer[] @ ids of selected cards
---@return boolean
function ViewAsSkill:cardFilter(player, to_select, selected)
  return false
end

---@param player Player @ the user
---@param cards integer[] @ ids of cards
---@return Card?
function ViewAsSkill:viewAs(player, cards)
  return nil
end

-- For extra judgement, like mark or HP

---@param player Player
function ViewAsSkill:enabledAtPlay(player)
  return self:isEffectable(player)
end

---@param player Player
function ViewAsSkill:enabledAtResponse(player, cardResponsing)
  return self:isEffectable(player)
end

---@param player Player
---@param cardUseStruct UseCardDataSpec
function ViewAsSkill:beforeUse(player, cardUseStruct) end

---@param player Player
---@param cardUseStruct UseCardData
function ViewAsSkill:afterUse(player, cardUseStruct) end

---@param player Player @ 你自己
---@param selected_cards integer[] @ ids of selected cards
---@param selected_targets Player[] @ ids of selected players
function ViewAsSkill:prompt(player, selected_cards, selected_targets) return "" end

return ViewAsSkill
