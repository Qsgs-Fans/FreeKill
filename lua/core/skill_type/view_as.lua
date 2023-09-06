-- SPDX-License-Identifier: GPL-3.0-or-later

---@class ViewAsSkill : UsableSkill
---@field public pattern string @ cards that can be viewAs'ed by this skill
---@field public interaction any
local ViewAsSkill = UsableSkill:subclass("ViewAsSkill")

function ViewAsSkill:initialize(name, frequency)
  UsableSkill.initialize(self, name, frequency)
  self.pattern = ""
end

---@param to_select integer @ id of a card not selected
---@param selected integer[] @ ids of selected cards
---@return boolean
function ViewAsSkill:cardFilter(to_select, selected)
  return false
end

---@param cards integer[] @ ids of cards
---@return Card|nil
function ViewAsSkill:viewAs(cards)
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
---@param cardUseStruct CardUseStruct
function ViewAsSkill:beforeUse(player, cardUseStruct) end

---@param selected integer[] @ ids of selected players
---@param selected_cards integer[] @ ids of selected cards
function ViewAsSkill:prompt(selected, selected_cards) return "" end

return ViewAsSkill
