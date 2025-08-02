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

---@class ViewAsPattern
---@field public max_num number @ 推测转化底牌的最大数
---@field public min_num number @ 推测转化底牌的最小数
---@field public pattern string @ 推测参与转化的实体牌所满足的匹配器

---@param player Player @ the user
---@return ViewAsPattern?
function ViewAsSkill:filterPattern(player)
  return nil
end

--- 判断一张牌是否可被此技能选中
---@param player Player @ 你自己
---@param to_select integer @ id of a card not selected
---@param selected integer[] @ ids of selected cards
---@param selected_targets Player[] @ 已选目标
---@return boolean
function ViewAsSkill:cardFilter(player, to_select, selected, selected_targets)
  local filter_pattern = self:filterPattern(player)
  if filter_pattern then
    if filter_pattern.max_num == 0 or not Fk:getCardById(to_select):matchPattern(filter_pattern.pattern) then return false end
    if #selected == filter_pattern.max_num - 1 then
      local card = self:viewAs(player, table.connect(selected, {to_select}))
      if card == nil then return false end
      if Fk.currentResponsePattern == nil then
        return player:canUse(card)
      else
        --FIXME: 无法判断当前是使用还是打出，暂且搁置
        return true
      end
    end
  end
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
