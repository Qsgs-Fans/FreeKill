-- SPDX-License-Identifier: GPL-3.0-or-later

---@class ViewAsSkill : UsableSkill
---@field public pattern string @ cards that can be viewAs'ed by this skill
---@field public interaction any
---@field public handly_pile boolean? @ 能否选择“如手牌般使用或打出”的牌
---@field public mute_card boolean? @ 是否不播放卡牌特效和语音
---@field public click_count? boolean @ 是否在点击按钮瞬间就计数并播放特效和语音
local ViewAsSkill = UsableSkill:subclass("ViewAsSkill")

function ViewAsSkill:initialize(name, frequency)
  UsableSkill.initialize(self, name, frequency)
  self.pattern = ""
end

--- 判断一张牌是否可被此技能选中
---@param player Player @ 你自己
---@param to_select integer @ id of a card not selected
---@param selected integer[] @ ids of selected cards
---@param selected_targets Player[] @ 已选目标
---@return boolean
function ViewAsSkill:cardFilter(player, to_select, selected, selected_targets)
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
---@param cardResponsing? boolean @ 是否为打出事件
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

--- 转化无懈是否对特定的牌有效
---@param player Player
---@param data CardEffectData @ 被响应的牌的数据
---@return boolean?
function ViewAsSkill:enabledAtNullification(player, data)
  return false
end

return ViewAsSkill
