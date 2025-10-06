-- SPDX-License-Identifier: GPL-3.0-or-later

---@class ViewAsSkill : UsableSkill
---@field public pattern string @ cards that can be viewAs'ed by this skill
---@field public interaction any
---@field public handly_pile boolean? @ 能否选择“如手牌般使用或打出”的牌
---@field public mute_card boolean? @ 是否不播放卡牌特效和语音
---@field public click_count? boolean @ 是否在点击按钮瞬间就计数并播放特效和语音
---@field public include_equip? boolean @ 选牌时是否展开装备区
local ViewAsSkill = UsableSkill:subclass("ViewAsSkill")

function ViewAsSkill:initialize(name, frequency)
  UsableSkill.initialize(self, name, frequency)
  self.pattern = ""
end

---@class ViewAsPattern
---@field public max_num number @ 推测转化底牌的最大数
---@field public min_num number @ 推测转化底牌的最小数
---@field public pattern string @ 推测参与转化的实体牌所满足的匹配器
---@field public subcards number[]? @ 转化底牌（用于实体牌已完全确定的情况）

--- 判断一个视为技会印什么样的牌
---@param player Player @ 使用者
---@param name? string @ 牌名
---@param selected? integer[] @ 已选牌ID表
---@return ViewAsPattern?
function ViewAsSkill:filterPattern(player, name, selected)
  return nil
end

--- 判断一张牌是否可被此技能选中
---@param player Player @ 你自己
---@param to_select integer @ 等待判断的牌ID
---@param selected integer[] @ 已选牌ID表
---@param selected_targets Player[] @ 已选目标
---@return boolean
function ViewAsSkill:cardFilter(player, to_select, selected, selected_targets)
  local card = self:viewAs(player, table.connect(selected, {to_select}))
  local filter_pattern = self:filterPattern(player, card and card.name, selected)
  if filter_pattern then
    if filter_pattern.subcards then return false end
    if #selected >= filter_pattern.max_num then return false end
    if not Fk:getCardById(to_select):matchPattern(filter_pattern.pattern) then return false end

    if #selected == filter_pattern.max_num - 1 then
      return card ~= nil and player:canUseOrResponseInCurrent(card)
    elseif card then
      if card:isVirtual() then
        card:setVSPattern(self.name, player)
      end
      return player:canUseOrResponseInCurrent(card)
    else
      --无法判断当前转化的卡牌，故作估计处理（很可能会误判，特殊情况请根据实际情况重写cardFilter）
      local card_names = {}
      if self.interaction and Fk.all_card_types[self.interaction.data] ~= nil then
        --优先判interaction结果（泛转化技）
        table.insert(card_names, self.interaction.data)
      elseif self.pattern then
        --分析技能的pattern，仅考虑卡名的情况（单卡名，及以逗号分隔的多卡名）
        local t = self.pattern:split(";")
        for _, v in ipairs(t) do
          local names = v:split("|")[1]:split(",")
          for _, name in ipairs(names) do
            if Fk.all_card_types[name] ~= nil then
              table.insertIfNeed(card_names, name)
            end
          end
        end
      end
      if #card_names > 0 then
        for _, name in ipairs(card_names) do
          filter_pattern = self:filterPattern(player, name, selected)
          if filter_pattern and Fk:getCardById(to_select):matchPattern(filter_pattern.pattern) then
            local c = Fk:cloneCard(name)
            c:addSubcards(table.connect(selected, {to_select}))
            c:setVSPattern(self.name, player)
            if player:canUseOrResponseInCurrent(c) then
              return true
            end
          end
        end
        return false
      end
    end
    return true
  end
  return false
end

---@param player Player @ the user
---@param cards integer[] @ ids of cards
---@return Card?
function ViewAsSkill:viewAs(player, cards)
  return nil
end

-- 判断一名角色是否可被此转化技选中
---@param player Player @ 使用者
---@param to_select Player @ 待选目标
---@param selected Player[] @ 已选目标
---@param selected_cards integer[] @ 已选牌
---@param card? Card @ 牌
---@param extra_data? UseExtraData @ 额外数据
---@return boolean?
function ViewAsSkill:targetFilter(player, to_select, selected, selected_cards, card, extra_data)
  return false
end

-- 判断一个转化技是否可发动（也就是确认键是否可点击）
-- 警告：没啥事别改
---@param player Player @ 使用者
---@param targets Player[] @ 已选目标
---@param selected_cards integer[] @ 已选牌
---@param card? Card @ 牌
---@return boolean
function ViewAsSkill:feasible(player, targets, selected_cards, card)
  return false
end

--- 发动技能时实际执行的函数
-- 警告：建议别改
---@param room Room @ 服务端房间
---@param cardUseEvent SkillUseData @ 技能使用数据
---@param params? handleUseCardParams @ 使用/打出牌的具体数据
---@return UseCardDataSpec|string? @ 若为字符串，则禁止某些技能被发动，否则
function ViewAsSkill:onUse(room, cardUseEvent, card, params)
  if card == nil then return "" end
  ---@type UseCardDataSpec
  local use = {
    from = cardUseEvent.from,
    tos = cardUseEvent.tos,
    card = card,
  }

  local rejectSkillName = self:beforeUse(cardUseEvent.from, use)

  if type(rejectSkillName) == "string" then
    return rejectSkillName
  end

  return use
end

-- For extra judgement, like mark or HP

--- 空闲时间点内是否可以使用转化技
---@param player Player @ 想发动技能的角色
function ViewAsSkill:enabledAtPlay(player)
  return self:isEffectable(player)
end

--- 需要响应时是否可以使用转化技
---@param player Player @ 想发动技能的角色
---@param cardResponsing? boolean @ 是否为打出事件
function ViewAsSkill:enabledAtResponse(player, cardResponsing)
  return self:isEffectable(player)
end

--- 使用转化技使用/打出牌前执行的操作，注意此时牌未被使用/打出
---@param player Player @ 想发动技能的角色
---@param cardUseStruct UseCardDataSpec|RespondCardDataSpec @ 使用/打出牌的数据
---@return any @ 若返回字符串，则取消本次使用
function ViewAsSkill:beforeUse(player, cardUseStruct) end

--- 使用转化技使用牌后执行的操作
---@param player Player @ 想发动技能的角色
---@param cardUseStruct UseCardData @ 使用牌的数据
function ViewAsSkill:afterUse(player, cardUseStruct) end

--- 使用转化技打出牌后执行的操作
---@param player Player @ 想发动技能的角色
---@param response RespondCardData @ 打出牌的数据
function ViewAsSkill:afterResponse(player, response) end


---@param player Player @ 使用者
---@param selected_cards integer[] @ ids of selected cards
---@param selected_targets Player[] @ selected players
---@param extra_data any
function ViewAsSkill:prompt(player, selected_cards, selected_targets, extra_data) return "" end

--- 转化无懈是否对特定的牌有效
---@param player Player @ 想发动技能的角色
---@param data CardEffectData @ 被响应的牌的数据
---@return boolean?
function ViewAsSkill:enabledAtNullification(player, data)
  return self:enabledAtResponse(player, false)
end

return ViewAsSkill
