-- SPDX-License-Identifier: GPL-3.0-or-later

--[[

一套基于收益论和简易收益预测的AI框架

--]]

---@class SmartAI: TrustAI
---@field private _memory table<string, any> @ AI底层的空间换时间机制
---@field public friends ServerPlayer[] @ 队友
---@field public enemies ServerPlayer[] @ 敌人
local SmartAI = TrustAI:subclass("SmartAI") -- 哦，我懒得写出闪之类的，不得不继承一下，饶了我吧

AIParser = require 'lua.server.ai.parser'
SkillAI = require "lua.server.ai.skill"
TriggerSkillAI = require "lua.server.ai.trigger_skill"

---@type table<string, AIGameEvent>
fk.ai_events = {}
AIGameLogic, AIGameEvent = require "lua.server.ai.logic"

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

-- 面板相关交互：对应操控手牌区、技能面板、直接选择目标的交互
-- 对应UI中的"responding"状态和"playing"状态
-- AI代码需要像实际操作UI那样完成以下几个任务：
--   * 点击技能按钮，完成interaction与子卡选择；或者直接点可用手牌
--   * 选择目标
--   * 点确定
--===================================================

-- 考虑为triggerSkill设置收益修正函数

--@field ask_use_card? fun(skill: ActiveSkill, ai: SmartAI): any
--@field ask_response? fun(skill: ActiveSkill, ai: SmartAI): any

---@type table<string, SkillAI>
fk.ai_skills = {}

---@param key string
---@param spec SkillAISpec
---@param inherit? string
function SmartAI.static:setSkillAI(key, spec, inherit)
  if not fk.ai_skills[key] then
    fk.ai_skills[key] = SkillAI:new(key)
  end
  local ai = fk.ai_skills[key]
  local qsgs_wisdom_map = {
    estimated_benefit = "getEstimatedBenefit",
    think = "think",
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
  for k, v in pairs(spec) do
    local key2 = qsgs_wisdom_map[k]
    if key2 then ai[key2] = type(v) == "function" and v or function() return v end end
  end
end

--- 将spec中的键值保存到这个技能的ai中
---@param key string
---@param spec SkillAISpec 表
---@param inherit? string 可以直接复用某个技能已有的函数 自然spec中更加优先
---@diagnostic disable-next-line
function SmartAI:setSkillAI(key, spec, inherit)
  error("This is a static method. Please use SmartAI:setSkillAI(...)")
end

SmartAI:setSkillAI("__card_skill", {
  choose_targets = function(self, ai)
    local targets = ai:getEnabledTargets()
    local logic = AIGameLogic:new(ai)
    local val_func = function(p)
      logic.benefit = 0
      logic:useCard({
        from = ai.player.id,
        tos = { { p.id } },
        card = ai:getSelectedCard(),
      })
      verbose("目前状况下，对%s的预测收益为%d", tostring(p), logic.benefit)
      return logic.benefit
    end
    for _, p, val in fk.sorted_pairs(targets, val_func) do
      if val > 0 then
        ai:selectTarget(p, true)
        return ai:doOKButton(), val
      else
        break
      end
    end
  end,

  think = function(self, ai)
    local skill_name = self.skill.name
    local pattern = skill_name:sub(1, #skill_name - 6)
    local cards = ai:getEnabledCards(pattern)
    cards = table.random(cards, math.min(#cards, 5)) --[[@as integer[] ]]
    -- local cid = table.random(cards)

    local best_ret, best_val = nil, -100000
    for _, cid in ipairs(cards) do
      ai:selectCard(cid, true)
      local ret, val = self:chooseTargets(ai)
      val = val or -100000
      if not best_ret or (best_val < val) then
        best_ret, best_val = ret, val
      end
      ai:unSelectAll()
    end

    return best_ret, best_val
  end,
})

function SmartAI.static:setCardSkillAI(key, spec)
  SmartAI:setSkillAI(key, spec, "__card_skill")
end

-- 等价于SmartAI:setCardSkillAI(key, spec, "__card_skill")
---@param key string
---@param spec SkillAISpec 表
function SmartAI:setCardSkillAI(key, spec)
  error("This is a static method. Please use SmartAI:setCardSkillAI(...)")
end

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

---@param cid_or_skill integer|string
function SmartAI:getBasicBenefit(cid_or_skill)
end

local function hasKey(t1, t2, key)
  if (t1 and t1[key]) or (t2 and t2[key]) then return true end
end

local function callFromTables(tab, backup, key, ...)
  local fn
  if tab and tab[key] then
    fn = tab[key]
  elseif backup and backup[key] then
    fn = backup[key]
  end
  if not fn then return end
  return fn(...)
end

function SmartAI:handleAskForUseActiveSkill()
  local name = self.handler.skill_name
  local current_skill = self:currentSkill()

  local ai
  if current_skill then ai = fk.ai_skills[current_skill.name] end
  if not ai then ai = fk.ai_skills[name] end
  if not ai then return "" end
  return ai:think(self)
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
  verbose("======== %s: 开始计算出牌阶段 ========", tostring(self))
  verbose("待选技能：[%s]", table.concat(table.map(skill_ai_list, function(ai) return ai.skill.name end), ", "))

  local value_func = function(ai)
    if not ai then return -500 end
    local val = ai:getEstimatedBenefit(self)
    return val or 0
  end

  local cancel_val = math.min(-90 * (self.player:getMaxCards() - self.player:getHandcardNum()), 0)

  local best_ret, best_val
  for _, ai, val in fk.sorted_pairs(skill_ai_list, value_func) do
    verbose("[*] 考虑 %s (预估收益%d)", ai.skill.name, val)
    if val < cancel_val then
      verbose("由于预估收益小于取消的收益，不再思考")
      break
    end
    local ret, real_val = ai:think(self)
    -- if ret and ret ~= "" then return ret end
    if not best_ret or (best_val < real_val) then
      best_ret, best_val = ret, real_val
    end
    self:unSelectAll()
  end

  if best_ret and best_ret ~= "" then return best_ret end
  return ""
end

---------------------------------------------------------------------

-- 其他交互：不涉及面板而是基于弹窗式的交互
-- 这块就灵活变通了，没啥非常通用的回复格式
-- ========================================

-- AskForSkillInvoke
-- 只能选择确定或者取消的交互。
-- 函数返回true或者false即可。
-----------------------------

--[[
---@type table<string, boolean | fun(self: SmartAI, prompt: string): bool>
fk.ai_skill_invoke = { AskForLuckCard = false }

function SmartAI:handleAskForSkillInvoke(data)
  local skillName, prompt = data[1], data[2]
  local skill = Fk.skills[skillName]
  local spec = fk.ai_skills[skillName]
  local ask
  if spec then
    ask = spec.skill_invoke
  else
    ask = fk.ai_skill_invoke[skillName]
  end


  if type(ask) == "function" then
    return ask(skill, self) and "1" or ""
  elseif type(ask) == "boolean" then
    return ask and "1" or ""
  elseif Fk.skills[skillName].frequency == Skill.Frequent then
    return "1"
  else
    return math.random() < 0.5 and "1" or ""
  end
end
--]]

-- 敌友判断相关。
-- 目前才开始，做个明身份打牌的就行了。
--========================================

---@param target ServerPlayer
function SmartAI:isFriend(target)
  if Self.role == target.role then return true end
  local t = { "lord", "loyalist" }
  if table.contains(t, Self.role) and table.contains(t, target.role) then return true end
  if Self.role == "renegade" or target.role == "renegade" then return math.random() < 0.6 end
  return false
end

---@param target ServerPlayer
function SmartAI:isEnemy(target)
  return not self:isFriend(target)
end

-- 排序相关函数。
-- 众所周知AI要排序，再选出尽可能最佳的选项。
-- 这里提供了常见的完整排序和效率更高的不完整排序。
--=================================================

-- sorted_pairs 见 core/util.lua

-- 基于事件的收益推理；内置事件
--=================================================

return SmartAI
