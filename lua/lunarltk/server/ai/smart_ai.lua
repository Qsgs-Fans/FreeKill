-- SPDX-License-Identifier: GPL-3.0-or-later

--[[

一套基于收益论和简易收益预测的AI框架

--]]

--- 卡牌对于AI的价值
fk.ai_card_keep_value = {}

---@class SmartAI: TrustAI, AIUtil
---@field private _memory table<string, any> @ AI底层的空间换时间机制
---@field public friends ServerPlayer[] @ 队友
---@field public enemies ServerPlayer[] @ 敌人
local SmartAI = TrustAI:subclass("SmartAI")

local require_skill = require "lunarltk.server.ai.skill"
SkillAI, TriggerSkillAI = require_skill[1], require_skill[2]
local AIUtil = require 'lunarltk.server.ai.util'
SmartAI:include(AIUtil)

---@type table<string, AIGameEvent>
fk.ai_events = {}
AIGameLogic, AIGameEvent = require "lunarltk.server.ai.logic"

function SmartAI:initialize(player)
  TrustAI.initialize(self, player)
end

function SmartAI:makeReply()
  self._memory = setmetatable({}, { __mode = "k" })
  return TrustAI.makeReply(self)
end

function SmartAI:__index(k)
  if self._memory[k] then
    return self._memory[k]
  end
  local ret
  if k == "enemies" then
    ret = table.filter(self.room.alive_players, function(p)
      return self:isEnemy(p)
    end)
  elseif k == "friends" then
    ret = table.filter(self.room.alive_players, function(p)
      return self:isFriend(p)
    end)
  end
  self._memory[k] = ret
  return ret
end

-- 四面板交互，全部依赖skillAI:think
--===================================================


--@field ask_use_card? fun(skill: ActiveSkill, ai: SmartAI): any
--@field ask_response? fun(skill: ActiveSkill, ai: SmartAI): any

---@type table<string, SkillAI>
fk.ai_skills = {}

---@param key string
---@param spec? SkillAISpec
---@param inherit? string
function SmartAI.static:setSkillAI(key, spec, inherit)
  if not fk.ai_skills[key] then
    fk.ai_skills[key] = SkillAI:new(key)
  end
  local ai = fk.ai_skills[key]

  -- 神杀智慧之sgs_ex.lua: 致敬传奇靠造表创建对象写法
  local qsgs_wisdom_map = {
    estimated_benefit = "getEstimatedBenefit",
    think = "think",
    think_card_chosen = "thinkForCardChosen",
    think_skill_invoke = "thinkForSkillInvoke",
    think_choice = "thinkForChoice",
    choose_interaction = "chooseInteraction",
    choose_cards = "chooseCards",
    choose_targets = "chooseTargets",

    on_trigger_use = "onTriggerUse",
    on_use = "onUse",
    on_effect = "onEffect",
  }
  if inherit then
    local ai2 = fk.ai_skills[inherit]
    for _, k in pairs(qsgs_wisdom_map) do
      ai[k] = ai2[k]
    end
  end
  if not spec then return end
  for k, v in pairs(spec) do
    local key2 = qsgs_wisdom_map[k]
    if key2 == "think" then
      ai.think = function(_self, _ai)
        local ret, val = v(_self, _ai)
        if ret and type(ret) == "table" then
          if ret.cards then
            ret.card = { skill = _self.skill.name, subcards = ret.cards }
            ret.cards = nil
          end
          if not ret.card then
            ret.card = { skill = _self.skill.name, subcards = Util.DummyTable }
          end
          if ret.targets then
            if type(ret.targets[1]) == "table" then
              ret.targets = table.map(ret.targets, Util.IdMapper)
            end
          else
            ret.targets = Util.DummyTable
          end
        end
        return ret, val
      end
    elseif key2 then
      ai[key2] = type(v) == "function" and v or function() return v end
    end
  end
end

--- 将spec中的键值保存到这个技能的ai中
---@param key string
---@param spec? SkillAISpec 表
---@param inherit? string 可以直接复用某个技能已有的函数 自然spec中更加优先
---@diagnostic disable-next-line
function SmartAI:setSkillAI(key, spec, inherit)
  error("This is a static method. Please use SmartAI:setSkillAI(...)")
end

SmartAI:setSkillAI("__card_skill", {
  choose_targets = function(self, ai)
    -- local targets = ai:getEnabledTargets()
    local logic = AIGameLogic:new(ai)
    local estimate_val = self:getEstimatedBenefit(ai)
    local val_func = function(targets)
      logic.benefit = 0
      logic:useCard({
        from = ai.player,
        tos = targets,
        card = ai:getSelectedCard(),
      })
      verbose(1, "目前状况下，对[%s]的预测收益为%g", table.concat(table.map(targets, function(p)return tostring(p)end), "+"), logic.benefit)
      return logic.benefit
    end
    local best_targets, best_val = nil, -100000
    for targets in self:searchTargetSelections(ai) do
      local val = val_func(targets)
      if (not best_targets) or (best_val < val) then
        best_targets, best_val = targets, val
      end
      -- if best_val > estimate_val then break end
    end
    return best_targets or {}, best_val
  end,

  think = function(self, ai)
    local skill_name = self.skill.name
    local pattern = ".|.|.|.|" .. skill_name:sub(1, #skill_name - 6)
    local estimate_val = self:getEstimatedBenefit(ai)
    local cards = ai:getEnabledCards(pattern)
    cards = table.random(cards, math.min(#cards, 5)) --[[@as integer[] ]]
    -- local cid = table.random(cards)

    local best_ret, best_val = "", -100000
    for _, cid in ipairs(cards) do
      ai:selectCard(cid, true)
      local ret, val = self:chooseTargets(ai)
      verbose(1, "就目前选择的这张牌，考虑[%s]，收益为%g", table.concat(table.map(ret, function(p)return tostring(p)end), "+"), val)
      val = val or -100000
      if best_val < val then
        best_ret, best_val = ret, val
      end
      if best_val >= estimate_val then break end
      ai:unSelectAll()
    end

    if best_ret and best_ret ~= "" then
      if best_val < 0 then
        return "", best_val
      end

      best_ret = { card = ai:getSelectedCard().id, targets = best_ret }
    end

    return best_ret, best_val
  end,
})

function SmartAI.static:setCardSkillAI(key, spec, key2)
  SmartAI:setSkillAI(key, spec, "__card_skill")
  if key2 then
    SmartAI:setSkillAI(key, spec, key2)
  end
end

-- 等价于SmartAI:setSkillAI(key, spec, "__card_skill")
---@param key string
---@param spec? SkillAISpec 表
---@param key2? string 要继承的
function SmartAI:setCardSkillAI(key, spec, key2)
  error("This is a static method. Please use SmartAI:setCardSkillAI(...)")
end

SmartAI:setCardSkillAI("default_card_skill", {
  on_use = function(self, logic, effect)
    self.skill:onUse(logic, effect)
  end,
  on_effect = function(self, logic, effect)
    self.skill:onEffect(logic, effect)
  end,
})

SmartAI:setSkillAI("vs_skill", {
  choose_targets = function(self, ai)
    local logic = AIGameLogic:new(ai)
    local card = self.skill:viewAs(ai.player, ai:getSelectedCards())
    if card == nil then
      return {}, -100000
    end
    local val_func = function(targets)
      logic.benefit = 0
      logic:useCard{
        from = ai.player,
        tos = targets,
        card = card,
      }
      verbose(1, "目前状况下，对[%s]的预测收益为%g", table.concat(table.map(targets, function(p)return tostring(p)end), "+"), logic.benefit)
      return logic.benefit
    end
    local best_targets, best_val = nil, -100000
    for targets in self:searchTargetSelections(ai) do
      local val = val_func(targets)
      if (not best_targets) or (best_val < val) then
        best_targets, best_val = targets, val
      end
    end
    return best_targets or {}, best_val
  end,
  think = function(self, ai)
    local best_ret
    local best_cards, best_targets, best_interaction, best_val = {}, "", nil, -100000
    if self.skill.interaction ~= nil then
      best_interaction = self.skill.interaction.data
    end
    for cards in self:searchCardSelections(ai) do
      local targets, val = self:chooseTargets(ai)
      verbose(1, "就目前选择的这张牌，考虑[%s]，收益为%g", table.concat(table.map(targets, function(p) return tostring(p)end), "+"), val)
      val = val or -100000
      if val > best_val then
        best_cards, best_targets, best_val = cards, targets, val
        best_ret = { cards = best_cards, targets = best_targets, interaction_data = best_interaction }
      end
    end
    if best_ret ~= nil then
      if best_val < 0 then
        return "", best_val
      end
    end
    return best_ret, best_val
  end,
})

---@type table<string, TriggerSkillAI>
fk.ai_trigger_skills = {}

---@param spec TriggerSkillAISpec
function SmartAI.static:setTriggerSkillAI(key, spec)
  if not fk.ai_trigger_skills[key] then
    fk.ai_trigger_skills[key] = TriggerSkillAI:new(key)
  end
  local ai = fk.ai_trigger_skills[key]
  if spec.correct_func then
    ai.getCorrect = spec.correct_func
  end
end

--- 将spec中的键值保存到这个技能的ai中
---@param key string
---@param spec TriggerSkillAISpec
---@diagnostic disable-next-line
function SmartAI:setTriggerSkillAI(key, spec)
  error("This is a static method. Please use SmartAI:setTriggerSkillAI(...)")
end

function SmartAI:handleAskForUseActiveSkill()
  local name = self.handler.skill_name
  local current_skill = self:currentSkill()

  local ai
  if current_skill then ai = fk.ai_skills[current_skill.name] end
  if not ai then ai = fk.ai_skills[name] end
  if not ai then return "" end
  verbose(1, "正在询问技能：%s", ai.skill.name)
  local ret, real_val = ai:think(self)
  verbose(1, "%s: 思考结果是%s, 收益是%s", ai.skill.name, json.encode(ret), json.encode(real_val))
  return ret, real_val
end

function SmartAI:handlePlayCard()
  local card_ids = self:getEnabledCards()
  local skill_ai_list = {}
  for _, id in ipairs(card_ids) do
    local cd = Fk:getCardById(id)
    local ai = fk.ai_skills[cd.skill.name]
    if ai then
      table.insertIfNeed(skill_ai_list, ai)
    end
  end
  for _, sname in ipairs(self:getEnabledSkills()) do
    local ai = fk.ai_skills[sname]
    if ai then
      table.insertIfNeed(skill_ai_list, ai)
    end
  end
  verbose(1, "======== %s: 开始计算出牌阶段 ========", tostring(self))
  verbose(1, "待选技能：[%s]", table.concat(table.map(skill_ai_list, function(ai) return ai.skill.name end), ", "))

  local value_func = function(ai)
    if not ai then return -500 end
    local val = ai:getEstimatedBenefit(self)
    return val or 0
  end

  local cancel_val = math.min(90 * (self.player:getMaxCards() - self.player:getHandcardNum()), -1)

  local best_ret, best_val = "", cancel_val
  verbose(1, "目前的决策：直接取消(收益%g)", best_val)
  for _, ai, val in fk.sorted_pairs(skill_ai_list, value_func) do
    verbose(1, "[*] 考虑 %s (预估收益%g)", ai.skill.name, val)
    if val < cancel_val then
      verbose(1, "由于预估收益小于取消的收益，不再思考")
      break
    end
    self:selectSkill(ai.skill.name, true)
    local ret, real_val = ai:think(self)
    verbose(1, "%s: 思考结果是%s, 收益是%s", ai.skill.name, json.encode(ret), json.encode(real_val))
    real_val = real_val or -100000
    -- if ret and ret ~= "" then return ret end
    if best_val < real_val then
      verbose(1, "将决策%s换成更好的%s (收益%g => %g)", json.encode(best_ret), json.encode(ret), best_val, real_val)
      best_ret, best_val = ret, real_val
    end
    self:unSelectAll()
  end
  verbose(1, "推测出最佳决策是%s", json.encode(best_ret))
  if best_ret and best_ret ~= "" then return best_ret end
  return ""
end

---------------------------------------------------------------------

-- 其他交互：不涉及面板而是基于弹窗式的交互
-- SkillAI里面每个command给个方法
-- ========================================

function SmartAI:handleAskForCardChosen(data)
  local target_id, flag, reason, prompt = table.unpack(data)
  local target = self.room:getPlayerById(target_id)
  local ai = fk.ai_skills[reason]
  if ai then
    local ret = ai:thinkForCardChosen(self, target, flag, prompt)
    return ret
  end
end

function SmartAI:handleAskForSkillInvoke(data)
  local skillName, prompt = data[1], data[2]
  local ai = fk.ai_skills[skillName]
  if ai then
    local ret = ai:thinkForSkillInvoke(self, skillName, prompt)
    return ret and "1" or ""
  else
    local skill = Fk.skills[skillName]
    if skill then
      return "1"
    end
  end
end

function SmartAI:handleAskForChoice(data)
  local choices, allChoices, skillName, prompt = table.unpack(data)
  local ai = fk.ai_skills[skillName]
  if ai then
    local ret = ai:thinkForChoice(self, choices, prompt, allChoices)
    return ret
  else
    return choices[1]
  end
end

function SmartAI:handleAskForUseCard(data)
  local card_ids = self:getEnabledCards()
  local pattern = data[2]
  local prompt = data[3]
  if pattern == "jink" then
    for _, cd in ipairs(card_ids) do
      self:selectCard(cd, true) -- 默认按下卡牌后直接可确定 懒得管了
      return self:doOKButton()
    end
  elseif pattern == "nullification" then
    if data[5] and data[5].effectFrom and self:isFriend(self.room:getPlayerById(data[5].effectFrom)) then
      return ""
    end
    local to = prompt:startsWith("#AskForNullificationWithoutTo") and prompt:split(":")[2] or prompt:split(":")[3]
    if to then
      to = self.room:getPlayerById(tonumber(to))
      if prompt:startsWith("#AskForNullificationWithoutTo") and self:isEnemy(to) or self:isFriend(to) then
        for _, cd in ipairs(card_ids) do
          self:selectCard(cd, true)
          return self:doOKButton()
        end
      end
    end
    return ""
  elseif pattern == "peach" or pattern == "peach,analeptic" then
    local to = prompt:startsWith("#AskForPeachesSelf") and self.player.id or prompt:split(":")[2]
    if to then
      to = self.room:getPlayerById(tonumber(to))
      if self:isFriend(to) then
        for _, cd in ipairs(card_ids) do
          self:selectCard(cd, true)
          return self:doOKButton()
        end
      end
    end
    return ""
  end

  local skill_ai_list = {}
  for _, id in ipairs(card_ids) do
    local cd = Fk:getCardById(id)
    local ai = fk.ai_skills[cd.skill.name]
    if ai then
      table.insertIfNeed(skill_ai_list, ai)
    end
  end
  for _, sname in ipairs(self:getEnabledSkills()) do
    local ai = fk.ai_skills[sname]
    if ai then
      table.insertIfNeed(skill_ai_list, ai)
    end
  end
  verbose(1, "======== %s: 开始计算出牌阶段 ========", tostring(self))
  verbose(1, "待选技能：[%s]", table.concat(table.map(skill_ai_list, function(ai) return ai.skill.name end), ", "))

  local value_func = function(ai)
    if not ai then return -500 end
    local val = ai:getEstimatedBenefit(self)
    return val or 0
  end

  local best_ret, best_val = "", -100000
  for _, ai, val in fk.sorted_pairs(skill_ai_list, value_func) do
    verbose(1, "[*] 考虑 %s (预估收益%g)", ai.skill.name, val)
    self:selectSkill(ai.skill.name, true)
    local ret, real_val = ai:think(self)
    verbose(1, "%s: 思考结果是%s, 收益是%s", ai.skill.name, json.encode(ret), json.encode(real_val))
    real_val = real_val or -100000
    -- if ret and ret ~= "" then return ret end
    if best_val < real_val then
      verbose(1, "将决策%s换成更好的%s (收益%g => %g)", json.encode(best_ret), json.encode(ret), best_val, real_val)
      best_ret, best_val = ret, real_val
    end
    self:unSelectAll()
  end
  verbose(1, "推测出最佳决策是%s", json.encode(best_ret))
  if best_ret and best_ret ~= "" then return best_ret end
  return ""
end

-- 敌友判断相关。
-- 目前才开始，做个明身份打牌的就行了。
--========================================

---@param target ServerPlayer
function SmartAI:isFriend(target)
  return self.player:isFriend(target)
end

---@param target ServerPlayer
function SmartAI:isEnemy(target)
  return not self.player:isFriend(target)
end

-- 排序相关函数。
-- 众所周知AI要排序，再选出尽可能最佳的选项。
-- 这里提供了常见的完整排序和效率更高的不完整排序。
--=================================================

-- sorted_pairs 见 core/util.lua

-- 基于事件的收益推理；内置事件
--=================================================

--- 传一个函数，函数里面模拟操作，返回一系列模拟操作后的收益
---@param fn fun(logic: AIGameLogic) 此函数放置想要的事件
function SmartAI:getBenefitOfEvents(fn)
  local logic = AIGameLogic:new(self)
  fn(logic)
  return logic.benefit
end

---------------------------------------------------------------------

-- 封装一些简单策略
-- ========================================

---@class AIAskToDiscardParams: AskToUseActiveSkillParams
---@field skill_name string @ 技能名
---@field min_num integer @ 最小值
---@field max_num integer @ 最大值

--- 弃牌
---@param params AIAskToDiscardParams @ 各种变量
---@return integer[], integer @ 本次弃牌收益最大的一种情况，返回选择的卡牌和收益
function SmartAI:askToDiscard(params)
  local cards = self:getEnabledCards()
  params.skill_name = params.skill_name or ""
  params.max_num = math.min(params.max_num, #cards)
  local benefit, ret = -100000, {}
  if #cards < params.min_num then
    ret = cards
    benefit = self:getBenefitOfEvents(function(logic)
      logic:throwCard(cards, params.skill_name, self.player, self.player)
    end)
  else
    cards = self:getChoiceCardsByKeepValue(cards, math.min(params.max_num, #cards))
    for i = params.min_num, params.max_num do
      local ids = table.slice(cards, 1, i + 1)
      local discard_val = self:getBenefitOfEvents(function(logic)
        logic:throwCard(ids, params.skill_name, self.player, self.player)
      end)
      if discard_val > benefit then
        benefit = discard_val
        ret = ids
      end
    end
  end
  return ret, benefit
end

---@class AIAskToChooseCardsParams
---@field cards integer[] @ 被选择的牌
---@field skill_name string @ 请求发动的技能名
---@field data table @ 用moveCardTo的参数表示这些牌即将被用来做什么操作

--- 选牌
---@param params AIAskToChooseCardsParams @ 各种变量
---@return integer[], integer @ 返回本次选牌收益最大的一种情况，选择的卡牌和收益
function SmartAI:askToChooseCards(params)
  local skill_name, data = params.skill_name, params.data
  local ret, benefit = { -1 }, -100000
  for _, id in ipairs(params.cards) do
    local v = self:getBenefitOfEvents(function(logic)
      logic:moveCardTo(id, data.to_place, data.target, data.reason, skill_name, nil, false, data.proposer)
    end)
    if v > benefit then
      ret, benefit = { id }, v
    end
  end
  return ret, benefit
end

return SmartAI
