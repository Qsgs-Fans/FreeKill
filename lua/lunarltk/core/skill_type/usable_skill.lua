-- SPDX-License-Identifier: GPL-3.0-or-later

--[[
  此为可发动技能。

  技能发动时，会产生SkillEffect事件，负责技能的计数，以及实际执行效果等。
--]]

---@class UsableSkill : Skill
---@field public max_use_time table<integer, integer?> @ 一个效果的最大可用次数
---@field public history_branch? string | fun(self: UsableSkill, player: ServerPlayer, data: SkillUseData, extra_data?: UseExtraData|table):string? @ 发动时是否将技能发动历史归类到某个分支
---@field public expand_pile? string | integer[] | fun(self: UsableSkill, player: Player): integer[]|string? @ 额外牌堆，牌堆名称或卡牌id表
---@field public derived_piles? string | string[] @deprecated @ 与某效果联系起来的私人牌堆名，失去该效果时将之置入弃牌堆
---@field public times? fun(self: UsableSkill, player: Player): integer
local UsableSkill = Skill:subclass("UsableSkill")

function UsableSkill:initialize(name, frequency)
  frequency = frequency or Skill.NotFrequent
  Skill.initialize(self, name, frequency)

  self.max_use_time = { nil, nil, nil, nil }
end

-- 获得技能的最大使用次数
---@param player Player @ 使用者
---@param scope? integer @ 查询历史范围（默认为回合）
---@param card? Card @ 卡牌
---@param to? Player @ 目标
---@return number? @ 最大使用次数，nil就是无限
function UsableSkill:getMaxUseTime(player, scope, card, to)
  scope = scope or Player.HistoryTurn
  local ret = self.max_use_time[scope]
  if not ret then return nil end
  if card then
    local status_skills = Fk:currentRoom().status_skills[TargetModSkill] or Util.DummyTable
    for _, skill in ipairs(status_skills) do
      local fix = skill:getFixedNum(player, self, scope, card, to)
      if fix ~= nil then -- 典中典之先到先得
        ret = fix
        break
      end
      local correct = skill:getResidueNum(player, self, scope, card, to)
      if correct == nil then correct = 0 end
      ret = ret + correct
    end
  end
  return ret
end

-- 判断一个角色是否在技能的次数限制内
---@param player Player @ 使用者
---@param scope? integer @ 查询历史范围（默认为回合）
---@param card? Card @ 牌，若没有牌，则尝试制造一张虚拟牌
---@param card_name? string @ 牌名
---@param to? Player @ 目标
---@return boolean?
function UsableSkill:withinTimesLimit(player, scope, card, card_name, to)
  if to and to.dead then return false end -- 一般情况不会对死人使用技能的……
  scope = scope or Player.HistoryTurn
  local status_skills = Fk:currentRoom().status_skills[TargetModSkill] or Util.DummyTable
  if not card then
    if card_name then
      card = Fk:cloneCard(card_name)
    elseif self.name:endsWith("_skill") then
      card = Fk:cloneCard(self.name:sub(1, #self.name - 6))
    end
  end

  local limit = self:getMaxUseTime(player, scope, card, to)
  if not limit then return true end

  if not card_name then
    if card then
      card_name = card.trueName
    else ---坏了，不是卡的技能
      return player:usedEffectTimes(self.name, scope) < limit
    end
  end

  for _, skill in ipairs(status_skills) do
    if skill:bypassTimesCheck(player, self, scope, card, to) then return true end
  end

  return player:usedCardTimes(card_name, scope) < limit or
  (card and not not card:hasMark(MarkEnum.BypassTimesLimit)) or
  not not player:hasMark(MarkEnum.BypassTimesLimit) or
  (to and not not to:hasMark(MarkEnum.BypassTimesLimitTo))
end

-- 获得技能的额外牌堆卡牌id表
---@param player Player @ 使用者
---@return integer[]
function UsableSkill:getPile(player)
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

--- 发动技能前确定cost_data的函数
---@param player ServerPlayer @ 使用者
---@param skillData SkillUseDataSpec @ 技能使用数据
---@param extra_data? UseExtraData|table @ 额外数据，请注意这不是skillData的extra_data
---@return CostData|table? @ cost_data，默认为空表，其中的from/cards/tos/extra_data会同步到skillData上。
function UsableSkill:onCost(player, skillData, extra_data)
  return nil
end

-- 处理技能的发动信息（仅限服务端）
---@param player ServerPlayer @ 使用者
---@param use_spec SkillUseDataSpec @ 技能使用数据
---@param extra_data? UseExtraData|table @ 额外数据，请注意这不是use_data的extra_data
---@return SkillUseData @ 技能发动数据
function UsableSkill:handleCostData(player, use_spec, extra_data)
  local use_data = SkillUseData:new(use_spec)
  use_data.cost_data = self:onCost(player, use_spec, extra_data) or {}
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

return UsableSkill
