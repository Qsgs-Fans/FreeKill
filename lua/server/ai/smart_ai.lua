-- SPDX-License-Identifier: GPL-3.0-or-later

--[[
  关于SmartAI: 一款参考神杀基本AI架构的AI体系。
  该文件加载了AI常用的种种表以及实用函数等，并提供了可供拓展自定义AI逻辑的接口。

  AI的核心在于编程实现对各种交互的回应(或者说应付各种room:askForXXX)，
  所以本文件的直接目的是编写出合适的函数充实smart_cb表以实现合理的答复，
  但为了实现这个目的就还要去额外实现敌友判断、收益计算等等功能。
  为了便于各个拓展快速编写AI，还要封装一些AI判断时常用的函数。

  本文件包含以下内容：
  1. 基本策略代码：定义各种全局表，以及smart_cb表
  2. 敌我相关代码：关于如何判断敌我以及更新意向值等
  3. 十分常用的各种函数（？）

  -- TODO: 优化底层逻辑，防止AI每次操作之前都要json.decode一下。
  -- TODO: 更加详细的文档
--]]

---@class SmartAI: AI
local SmartAI = AI:subclass("SmartAI")

---@type table<string, fun(self: SmartAI, jsonData: string): string>
local smart_cb = {}

function SmartAI:initialize(player)
  AI.initialize(self, player)
  self.cb_table = smart_cb
  self.player = player
  if self.room:getTag("ai_role") == nil then
    local ai_role = {}
    local role_value = {}
    for _, ap in ipairs(self.room.players) do
      ai_role[ap.id] = "neutral"
      role_value[ap.id] = {
        rebel = 0,
        renegade = 0
      }
    end
    self.room:setTag("ai_role", ai_role)
    self.room:setTag("role_value", role_value)
  end
  self.ai_role = self.room:getTag("ai_role")
  self.role_value = self.room:getTag("role_value")
end

-- AI框架中常用的模式化函数。
-- 先从表中选函数，若无则调用默认的。点点点是参数
function SmartAI:callFromTable(func_table, default_func, key, ...)
  local f = func_table[key]
  if type(f) == "function" then
    return f(...)
  elseif type(default_func) == "function" then
    return default_func(...)
  else
    return nil
  end
end

-- 面板相关交互：对应操控手牌区、技能面板、直接选择目标的交互
-- 对应UI中的"responding"状态和"playing"状态
-- AI代码需要像实际操作UI那样完成以下几个任务：
--   * 点击技能按钮（出牌阶段或者打算使用ViewAsSkill）
--   * 技能如果带有interaction，则选择interaction
--   * 如果需要的话点选手牌
--   * 选择目标
--   * 点确定
-- 这些步骤归结起来，就是让AI想办法返回如下定义的UseReply
-- 或者返回nil表示点取消
--===================================================

---@class UseReply
---@field card integer|string|nil @ string情况下是json.encode后
---@field targets integer[]|nil
---@field special_skill string @ 出牌阶段空闲点使用实体卡特有
---@field interaction_data any @ 因技能而异，一般都是nil

---@param card integer|table|nil
---@param targets integer[]|nil
---@param special_skill string|nil
---@param interaction_data any
function SmartAI:buildUseReply(card, targets, special_skill, interaction_data)
  if type(card) == "table" then card = json.encode(card) end
  return {
    card = card,
    targets = targets or {},
    special_skill = special_skill,
    interaction_data = interaction_data,
  }
end

-- AskForUseActiveSkill: 询问发动主动技/视为技
-- * 此处 UseReply.card 必定由 json.encode 而来
-- * 且原型为 { skill = skillName, subcards = integer[] }
----------------------------------------------------------

---@type table<string, fun(self: SmartAI, prompt: string, cancelable: bool, data: any): UseReply | nil>
fk.ai_active_skill = {}

smart_cb["AskForUseActiveSkill"] = function(self, jsonData)
  local data = json.decode(jsonData)
  local skillName, prompt, cancelable, extra_data = table.unpack(data)

  local skill = Fk.skills[skillName]
  for k, v in pairs(extra_data) do
    skill[k] = v
  end

  local ret = self:callFromTable(fk.ai_active_skill, nil, skillName,
    self, prompt, cancelable, extra_data)

  if ret then return json.encode(ret) end
  if cancelable then return "" end
  return RandomAI.cb_table["AskForUseActiveSkill"](self, jsonData)
end

-- AskForUseCard: 询问使用卡牌
-- 判断函数一样返回UseReply，此时卡牌可能是integer或者string
-- 为string的话肯定是由ViewAsSkill转化而来
-- 真的要考虑ViewAsSkill吗，害怕
---------------------------------------------------------

--- 键是prompt的第一项或者牌名，优先prompt，其次name，实在不行trueName。
---@type table<string, fun(self: SmartAI, pattern: string, prompt: string, cancelable: bool, extra_data: any): UseReply|nil>
fk.ai_use_card = {}

--- 请求使用，先试图使用prompt，再试图使用card_name，最后交给随机AI
smart_cb["AskForUseCard"] = function(self, jsonData)
  local data = json.decode(jsonData)
  local card_name, pattern, prompt, cancelable, extra_data = table.unpack(data)

  local prompt_prefix = prompt:split(":")[1]
  local key
  if fk.ai_use_card[prompt_prefix] then
    key = prompt_prefix
  elseif fk.ai_use_card[card_name] then
    key = card_name
  else
    local tmp = card_name:split("__")
    key = tmp[#tmp]
  end
  local ret = self:callFromTable(fk.ai_use_card, nil, key,
    self, pattern, prompt, cancelable, extra_data)

  if ret then return json.encode(ret) end
  if cancelable then return "" end
  return RandomAI.cb_table["AskForUseCard"](self, jsonData)
end

-- AskForResponseCard: 询问打出卡牌
-- 注意事项同前
-------------------------------------

-- 一样的牌名或者prompt做键优先prompt
---@type table<string, fun(self: SmartAI, pattern: string, prompt: string, cancelable: bool, extra_data: any): UseReply|nil>
fk.ai_response_card = {}

-- 同前
smart_cb["AskForResponseCard"] = function(self, jsonData)
  local data = json.decode(jsonData)
  local card_name, pattern, prompt, cancelable, extra_data = table.unpack(data)

  local prompt_prefix = prompt:split(":")[1]
  local key
  if fk.ai_response_card[prompt_prefix] then
    key = prompt_prefix
  elseif fk.ai_response_card[card_name] then
    key = card_name
  else
    local tmp = card_name:split("__")
    key = tmp[#tmp]
  end
  local ret = self:callFromTable(fk.ai_response_card, nil, key,
    self, pattern, prompt, cancelable, extra_data)

  if ret then return json.encode(ret) end
  if cancelable then return "" end
  return RandomAI.cb_table["AskForResponseCard"](self, jsonData)
end

-- PlayCard: 出牌阶段空闲时间点使用牌/技能
-- 老规矩得丢一个UseReply回来，但是自由度就高得多了
-- 需要完成的任务：从众多亮着的卡、技能中选一个
-- 考虑要不要用？用的话就用，否则选下个
-- 至于如何使用，可以复用askFor中的函数
-----------------------------------------------
smart_cb["PlayCard"] = function(self)
  -- 第一步：找到所有“亮着”的卡牌和技能
  local cards = table.map(Self:getHandlyIds(true), Util.Id2CardMapper)
  cards = table.filter(cards, function(c)
    return Self:canUse(c) and not Self:prohibitUse(c)
  end)

  -- FIXME: 此处只使用牌名或有不妥
  local card_names = {}
  for _, cd in ipairs(cards) do
    table.insertIfNeed(card_names, cd.name)
  end
  -- TODO: skill

  -- 第二步：考虑使用其中之一
  local value_func = function(str) return #str end
  for _, name in fk.sorted_pairs(card_names, value_func) do
    if true then
      local ret = self:callFromTable(fk.ai_use_card, nil,
        fk.ai_use_card[name] and name or name:split("__")[2],
        self, "", "", true, Util.DummyTable)
      if ret then return json.encode(ret) end
      break
    end
  end

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

---@type table<string, boolean | fun(self: SmartAI, extra_data: any, prompt: string): bool>
fk.ai_skill_invoke = {}

smart_cb["AskForSkillInvoke"] = function(self, jsonData)
  local data = json.decode(jsonData)
  local skillName, prompt = data[1], data[2]
  local ask = fk.ai_skill_invoke[skillName]

  if type(ask) == "function" then
    return ask(self, prompt) and "1" or ""
  elseif type(ask) == "boolean" then
    return ask and "1" or ""
  elseif Fk.skills[skillName].frequency == Skill.Frequent then
    return "1"
  else
    return RandomAI.cb_table["AskForSkillInvoke"](self, jsonData)
  end
end

-- 敌友判断相关。
-- 目前才开始，做个明身份打牌的就行了。
--========================================

---@param target ServerPlayer
function SmartAI:isFriend(target)
  if Self.role == target.role then return true end
  local t = { "lord", "loyalist" }
  if table.contains(t, Self.role) and table.contains(t, target.role) then return true end
  if Self.role == "renegade" or target.role == "renegade" then return math.random() < 0.5 end
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

return SmartAI
