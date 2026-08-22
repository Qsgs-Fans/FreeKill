-- SPDX-License-Identifier: GPL-3.0-or-later

---@class ViewAsSkill : ButtonSkill
---@field public pattern string @ cards that can be viewAs'ed by this skill
---@field public sub_data? string[] | fun(self: ViewAsSkill, player: Player, selected: integer[], selected_targets: Player[], interaction_data: any): Card[]? @ 用于泛转化技的二级选择
---@field public sub_prompt? string|fun(self: ViewAsSkill, player: Player, selected_cards: integer[], selected_targets: Player[], selected_sub_cards: Card[], selected_sub_targets: Player[], extradata?: UseExtraData|table): string @ 二级菜单提示信息
---@field public mute_card boolean? @ 是否不播放卡牌特效和语音
---@field public immediate_sub? boolean @ 是否在确认是否可发动时自动检测并展开二级选择
---@field public include_equip? boolean @ 选牌时是否展开装备区
local ViewAsSkill = ButtonSkill:subclass("ViewAsSkill")
function ViewAsSkill:initialize(name, frequency)
  ButtonSkill.initialize(self, name, frequency)
  self.pattern = ""
end

---@class ViewAsPattern
---@field public max_num number @ 推测转化底牌的最大数（subcards存在时将变成选fakesubcards）
---@field public min_num number @ 推测转化底牌的最小数（subcards存在时将变成选fakesubcards）
---@field public pattern string @ 推测参与转化的实体牌所满足的匹配器
---@field public subcards number[]? @ 转化底牌（用于实体牌已完全确定的情况）
---@field public skill_name string? @ 技能名称*泛转化技用
---@field public names string[]? @ 所有可转化的卡牌名*泛转化技用
---@field public ban_names string[]? @ 所有可转化的卡牌名中不可用的卡牌名*泛转化技用

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

    if self.interaction ~= nil and (self.interaction.spec or {}).type == "ToBeDecided" and
      filter_pattern.names then
      --预制模板的泛转化技，无法预先确定即将转化的牌名
      return true
    end

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

--[[
function ViewAsSkill:visible_pile(player)
  if self.interaction == nil then return end
  local spec = self.interaction.spec or {}
  if spec.type ~= "ToBeDecided" then return end

  -- FIXME(邪道实现): 通过设置visible_pile，使得点取消键触发的setup重置手牌！
  local req = spec.UIrequest
  if req then
    if req.elemType == "OptionBox" and req.option == "Cancel" then
      --注：这东西在req会处理两次，一次在update_interaction后，一次在refresh_interaction，因此不需要考虑恢复
      return { 0 }
    end
  elseif spec.result then
    --这里result已取值，代表已经进入expandItems阶段了，使UI手牌区的expandpile卡牌均不可见
    local handcards = player:getCardIds("h")
    if #handcards == 0 then
      --为空的话visible_cards会失效，这里随便传个不可能取到的逆天值即可
      return { 0 }
    end
    return handcards
  end
  return {}
end
]]

-- 技能的交互选项（如选项框、选项卡等）返回值self.interaction.data确定后，可使用这个预先进行一次修改
---@param player Player @ 使用者
---@param selected_targets Player[] @ 已选目标
---@param selected_cards integer[] @ 已选牌
function ViewAsSkill:update_interaction(player, selected_cards, selected_targets)
  if self.interaction == nil then return end
  local spec = self.interaction.spec or {}
  if spec.type ~= "ToBeDecided" then return end

  local dat = self.interaction.data
  spec.UIrequest = table.simpleClone(dat)
  if dat.elemType == "OptionBox" then
    if dat.option == "Cancel" then
      --FIXME(邪道实现): 直接修改req来取消self.pendings选牌
      local handler = ClientInstance.current_request_handler
      if handler then
        handler.pendings = {}
      end
      spec.result = nil
    else
      spec.result = { cards = table.simpleClone(selected_cards) }
    end
  elseif dat.elemType == "ExpandItem" then
    spec.result = spec.result or {}
    if spec.result.name == dat.name then
      spec.result.name = nil
      spec.pendings = {}
    else
      spec.result.name = dat.name
      spec.pendings = { dat.cid }
    end
  end
  self.interaction.data = (spec.result or {}).name
end

-- 刷新技能的交互选项（如选项框、选项卡等），返回一个表，表中每个元素为一个选项
---@param player Player @ 使用者
---@param selected_targets Player[] @ 已选目标
---@param selected_cards integer[] @ 已选牌
---@return table?
function ViewAsSkill:refresh_interaction(player, selected_cards, selected_targets)
  if self.interaction == nil then return end
  local spec = self.interaction.spec or {}
  if spec.type ~= "ToBeDecided" then return end

  --待定：需不需要输入card_name？
  local VSPattern = self:filterPattern(player, nil, selected_cards)
  if VSPattern == nil then return end

  local refresh_data = {}
  local req = spec.UIrequest or {}

  if spec.UIrequest == nil then
    if #selected_cards == VSPattern.max_num and spec.result == nil then
      spec.result = { cards = table.simpleClone(selected_cards) }
      req = {
        elemType = "OptionBox",
        option = "OK"
      }
    end
  end

  if req.elemType == "OptionBox" then
    if req.option == "Cancel" then
      --回归选牌步骤
      refresh_data.expandItems = {}
    else
      local items = {}
      local i = 1
      local subcards = VSPattern.subcards or spec.result.cards
      local ban_names = VSPattern.ban_names or {}
      for _, name in ipairs(VSPattern.names) do
        local card = Fk:cloneCard(name, nil, nil, VSPattern.skill_name, subcards)
        table.insert(items, {
          prop = {
            type = "card",
            card = card,
            additional_prop = { selectable = (not table.contains(ban_names, card.trueName) and player:canUseOrResponseInCurrent(card)) }
          },
          name = name,
          cid = i,
        })
        i = i + 1
      end
      refresh_data.expandItems = items
    end
  elseif req.elemType == "ExpandItem" then
    refresh_data.pendings = spec.pendings
  end

  if VSPattern.max_num > 0 then
    --可选牌时，需要重设手牌区按钮
    if spec.result == nil then
      local op_spec = {   ---@class OptionBoxParams
        options = {},
        all_options = { "OK" }
      }
      if #selected_cards >= VSPattern.min_num then
        op_spec.options = { "OK" }
      end
      refresh_data.optionBox = UI.OptionBox(op_spec)
    else
      local handler = ClientInstance.current_request_handler
      if handler and handler.class.name == "ReqActiveSkill" then
        --在读条中使用的情况直接使用自带的确定取消即可（因为可以反复操作）
        local op_spec = {   ---@class OptionBoxParams
          options = {},
          all_options = { "OK" },
          direct_send = true,
          cancelable = true
        }
        local card = self:viewAs(player, selected_cards)
        if card and card:getSkill(player):feasible(player, selected_targets, { }, card) then
          op_spec.options = { "OK" }
        end
        refresh_data.optionBox = UI.OptionBox(op_spec)
      end
    end
  end
  spec.UIrequest = nil
  return refresh_data
end

-- 该技能所实际使用/打出的虚拟牌
---@param player Player @ 使用者
---@param cards integer[] @ 实体牌ID数组
---@param sub_cards? Card[] @ 已选择的虚拟牌对象数组
---@return Card?
function ViewAsSkill:viewAs(player, cards, sub_cards)
  return nil
end

-- （二级菜单）判断一张二级菜单弹出的牌是否可被此技能选中
---@param player Player @ 使用者
---@param to_select Card @ 待选目标
---@param selected Card[] @ 已选目标
---@param selected_cards integer[] @ 进入二级菜单时的已选牌
---@param extra_data? UseExtraData @ 额外数据
---@return boolean?
function ViewAsSkill:subCardFilter(player, to_select, selected, selected_cards, extra_data)
  return #selected < 1
end

-- 获取使用此牌时的固定目标。注意，不需要进行任何合法性判断
---@param player Player @ 使用者
---@param selected_cards integer[] @ 已选牌
---@param c? Card @ 牌
---@param extra_data? UseExtraData @ 额外数据
---@return Player[]? @ 返回固定目标角色列表。若此牌可以选择目标，返回空表
function ViewAsSkill:fixTargets(player, selected_cards, c, extra_data)
  local card = self:viewAs(player, selected_cards)
  if card == nil or card:getFixedTargets(player, extra_data) then
    return {}
  end
  return nil
end

-- 判断一个转化技是否可发动（也就是确认键是否可点击）
-- 特别的，sub_data不为Nil的技能将屏蔽viewAs判断，并将此判断纳入考量。
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
