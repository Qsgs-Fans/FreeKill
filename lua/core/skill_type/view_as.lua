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

--- 使用转换技使用/打出牌前执行的操作，注意此时牌未被使用/打出
---@param player Player
---@param cardUseStruct UseCardDataSpec
---@return any @ 若返回字符串，则取消本次使用
function ViewAsSkill:beforeUse(player, cardUseStruct) end

--- 使用转换技使用牌后执行的操作
---@param player Player
---@param cardUseStruct UseCardData
function ViewAsSkill:afterUse(player, cardUseStruct) end

--- 使用转换技打出牌后执行的操作
---@param player Player
---@param response RespondCardData
function ViewAsSkill:afterResponse(player, response) end


---@param player Player @ 使用者
---@param selected_cards integer[] @ ids of selected cards
---@param selected_targets Player[] @ selected players
---@param extra_data any
function ViewAsSkill:prompt(player, selected_cards, selected_targets, extra_data) return "" end

return ViewAsSkill
