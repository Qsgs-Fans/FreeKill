-- SPDX-License-Identifier: GPL-3.0-or-later

--[[
  此为主动发动技能。

  这样的技能通常以按钮的形式存在，通过点击按钮发动技能。
--]]-- SPDX-License-Identifier: GPL-3.0-or-later

---@class ButtonSkill : UsableSkill
---@field public min_target_num integer
---@field public max_target_num integer
---@field public target_num integer
---@field public min_card_num integer
---@field public max_card_num integer
---@field public card_num integer
---@field public interaction any
---@field public interaction_helper function
---@field public update_interaction function
---@field public refresh_interaction function
---@field public prompt string | function? @ 技能提示
---@field public expand_pile? string | integer[] | fun(self: ButtonSkill, player: Player): integer[]|string? @ 额外牌堆，牌堆名称或卡牌id表
---@field public visible_pile? integer[] | string | fun(self: ButtonSkill, player: Player): integer[] | string @ 可见的手牌id，同时筛选手牌和expand_pile
---@field public handly_pile boolean?  @ 是否能够选择“如手牌使用或打出”的牌
---@field public click_count? boolean @ 是否在点击按钮瞬间就计数并播放特效和语音
---@field public include_equip? boolean @ 选牌时是否展开装备区
local ButtonSkill = UsableSkill:subclass("ButtonSkill")

function ButtonSkill:initialize(name, frequency)
  UsableSkill.initialize(self, name, frequency)
  self.min_target_num = 0
  self.max_target_num = 999
  self.min_card_num = 0
  self.max_card_num = 999
end

---------
-- 注：客户端函数，AI也会调用以作主动技判断
------- {

--- 判断一张牌是否可被此技能选中
---@param player Player @ 使用者
---@param to_select integer @ 待选牌
---@param selected integer[] @ 已选牌
---@param selected_targets Player[] @ 已选目标
---@return boolean?
function ButtonSkill:cardFilter(player, to_select, selected, selected_targets)
  return self:getMaxCardNum(player) > 0
end

-- 判断一名角色是否可被此技能选中
---@param player Player @ 使用者
---@param to_select Player @ 待选目标
---@param selected Player[] @ 已选目标
---@param selected_cards integer[] @ 已选牌
---@param card? Card @ 牌
---@param extra_data? UseExtraData @ 额外数据
---@return boolean?
function ButtonSkill:targetFilter(player, to_select, selected, selected_cards, card, extra_data)
  return false
end

-- 获得技能的最小目标数
---@param player Player @ 使用者
---@return integer @ 最小目标数
function ButtonSkill:getMinTargetNum(player)
  local ret
  if self.target_num then ret = self.target_num
  else ret = self.min_target_num end

  if type(ret) == "function" then
    ret = ret(self, player)
  end
  return ret
end

-- 获得技能的最大目标数
---@param player? Player @ 使用者
---@return integer @ 最大目标数
function ButtonSkill:getMaxTargetNum(player)
  local ret
  if self.target_num then ret = self.target_num
  else ret = self.max_target_num end

  if type(ret) == "function" then
    ret = ret(self, player)
  end
  return ret
end

-- 获得技能的最小卡牌数
---@param player Player @ 使用者
---@return integer @ 最小卡牌数
function ButtonSkill:getMinCardNum(player)
  local ret
  if self.card_num then ret = self.card_num
  else ret = self.min_card_num end

  if type(ret) == "function" then
    ret = ret(self, player)
  end
  if type(ret) == "table" then
    return ret[1]
  else
    return ret
  end
end

-- 获得技能的最大卡牌数
---@param player Player @ 使用者
---@return integer @ 最大卡牌数
function ButtonSkill:getMaxCardNum(player)
  local ret
  if self.card_num then ret = self.card_num
  else ret = self.max_card_num end

  if type(ret) == "function" then
    ret = ret(self, player)
  end
  return ret
end

-- 判断一个技能是否可发动（也就是确认键是否可点击）。默认值为选择卡牌数和选择目标数均在允许范围内
-- 警告：没啥事别改
---@param player Player @ 使用者
---@param selected Player[] @ 已选目标
---@param selected_cards integer[] @ 已选牌
---@return boolean
function ButtonSkill:feasible(player, selected, selected_cards)
  if self.interaction_helper and self.interaction.data == nil then return false end
  return #selected >= self:getMinTargetNum(player) and #selected <= self:getMaxTargetNum(player)
    and #selected_cards >= self:getMinCardNum(player) and #selected_cards <= self:getMaxCardNum(player)
end

-- 使用技能时默认的烧条提示（一般会在主动使用时出现）
---@param player Player @ 使用者
---@param selected_cards integer[] @ 已选牌
---@param selected_targets Player[] @ 已选目标
---@param extra_data? any
---@return string?
function ButtonSkill:prompt(player, selected_cards, selected_targets, extra_data) return "" end

------- }

--- 发动技能时实际执行的函数
---@param room Room @ 服务端房间
---@param cardUseEvent SkillUseData @ 技能使用数据
function ButtonSkill:onUse(room, cardUseEvent) end

--- 发动技能前确定cost_data的函数，注意和TriggerSkill的onCost不同，这里的参数不一样
---@param player ServerPlayer @ 使用者
---@param skillData SkillUseDataSpec @ 技能使用数据
---@param extra_data? UseExtraData|table @ 额外数据，请注意这不是skillData的extra_data
---@return CostData|table? @ cost_data，默认为空表，其中的from/cards/tos/extra_data会同步到skillData上。
function ButtonSkill:onCost(player, skillData, extra_data)
  return nil
end

-- 处理技能的发动信息（仅限服务端）
---@param player ServerPlayer @ 使用者
---@param use_spec SkillUseDataSpec @ 技能使用数据
---@param extra_data? UseExtraData|table @ 额外数据，请注意这不是use_data的extra_data
---@return SkillUseData @ 技能发动数据
function ButtonSkill:handleCostData(player, use_spec, extra_data)
  local use_data = SkillUseData:new(use_spec)
  use_data.cost_data = self:onCost(player, use_spec, extra_data)
  if type(use_data.cost_data) ~= "table" then
    use_data.cost_data = {}
  end
  if use_data.cost_data.from then
    use_data.from = use_data.cost_data.from
  end
  if use_data.cost_data.cards then
    use_data.cards = use_data.cost_data.cards
  end
  if use_data.cost_data.tos then
    use_data.tos = use_data.cost_data.tos
  end
  if use_data.cost_data.interaction_data then
    use_data.interaction_data = use_data.cost_data.interaction_data
  end
  if use_data.cost_data.extra_data then
    use_data.extra_data = use_data.cost_data.extra_data
  end
  if not use_data.cost_data.history_branch then
    local branch = self.history_branch
    if type(branch) == "function" then
      branch = self:history_branch(player, use_data, extra_data)
    end
    if type(branch) == "string" then
      use_data.cost_data.history_branch = branch
    end
  end
  return use_data
end

-- 获得技能的额外牌堆卡牌id表
---@param player Player @ 使用者
---@return integer[]
function ButtonSkill:getPile(player)
  if player == nil or self.expand_pile == nil then return {} end
  local pile = self.expand_pile
  if type(pile) == "function" then
    pile = pile(self, player)
  end
  if type(pile) == "string" then
    pile = player:getPile(pile)
  end
  return pile
end

--- 选择牌时产生的目标提示，贴在牌上
---@param player Player @ 使用者
---@param to_select integer @ 当前牌
---@param selected integer[] @ 已选角色目标
---@param selected_targets ServerPlayer[] @ 已选目标表
---@param card Card? @ (CardSkill?)所使用的牌
---@param selectable boolean? @ 当前牌是否可选择
---@param extra_data? table|UseExtraData @ 额外数据
---@return string|CardTipDataSpec?
function ButtonSkill:cardTip(player, to_select, selected, selected_targets, card, selectable, extra_data) end

--- 选择目标时产生的目标提示，贴在目标脸上
---@param player Player @ 使用者
---@param to_select Player @ 当前目标
---@param selected Player[] @ 已选角色目标
---@param selected_cards integer[] @ 已选卡牌ID表
---@param card Card? @ (CardSkill?)所使用的牌
---@param selectable boolean? @ 当前目标是否可选择
---@param extra_data? table|UseExtraData @ 额外数据
---@return string|TargetTipDataSpec?
function ButtonSkill:targetTip(player, to_select, selected, selected_cards, card, selectable, extra_data) end

return ButtonSkill
