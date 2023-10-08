-- SPDX-License-Identifier: GPL-3.0-or-later

--[[
  关于SmartAI: 一款参考神杀基本AI架构的AI体系。
  该文件加载了AI常用的种种表以及实用函数等，并提供了可供拓展自定义AI逻辑的接口。

  AI的核心在于编程实现对各种交互的回应(或者说应付各种room:askForXXX)，
  所以本文件的直接目的是编写出合适的函数充实smart_cb表以实现合理的答复，
  但为了实现这个目的就还要去额外实现敌友判断、收益计算等等功能。
  为了便于各个拓展快速编写AI，还要封装一些AI判断时常用的函数。

  -- TODO: 优化底层逻辑，防止AI每次操作之前都要json.decode一下。
  -- TODO: 更加详细的文档
--]]

---@class SmartAI: AI
local SmartAI = AI:subclass("SmartAI")

--[[
  * 数据表准备部分 *
  这部分定义了各种以后决策、拓展等都会用到的表。
  这些表的内容只要加载完成后就不会改变，所以定义成了全局表的样子。
--]]

--- 用来应对Room:askForUseActiveSkill的表。
---@type table<string, fun(self: SmartAI, prompt: string, cancelable: bool, data: any)>
fk.ai_use_skill = {}

--- TOdo? Room:askForGeneral暂缺

--- 用来应对Room:askForSkillInvoke的表。
---@type table<string, fun(self: SmartAI, extra_data: any, prompt: string)>
fk.ai_skill_invoke = {}

--- 用来应对Room:askForAG的表。表的键是prompt的第一项。
---@type table<string, fun(self: SmartAI, id_list: integer[], cancelable: bool, prompt: string)>
fk.ai_ask_for_ag = {}

--- 用来应对出牌阶段空闲时间点如何出牌/使用技能的表。
---@type table<string, fun(self: SmartAI, card: Card|ActiveSkill|ViewAsSkill)>
fk.ai_use_play = {}

--- 用来应对Room:askForUseCard的表。表的键是prompt的第一项或者牌名，优先prompt。
---@type table<string, fun(self: SmartAI, pattern: string, prompt: string, cancelable: bool, extra_data: any)>
fk.ai_ask_usecard = {}

---[effect.card.name] = function(self, effect.card, room:getPlayerById(effect.to), room:getPlayerById(effect.from), positive)
---@type table<string, fun(self: SmartAI, card: Card, to: ServerPlayer, from: ServerPlayer, positive: bool)>
fk.ai_nullification = {}

---[card.name] = {intention = 0, value = 0, priority = 0}
---
---[skill.name] = {intention = 0, value = 0, priority = 0}
---@type table<string, {intention: number, value: number, priority: number}>
fk.ai_card = {}

---[card.id] = 0
---
---[skill.name] = 0
---@type table<string|number, number>
fk.cardValue = {}

---[prompt:split(":")[1]] = function(self, pattern, prompt, cancelable, extra_data)
---
---[card_name] = function(self, pattern, prompt, cancelable, extra_data)
---@type table<string, fun(self: SmartAI, pattern: string, prompt: string, cancelable: bool, extra_data: any)>
fk.ai_response_card = {}

---[reason] = function(self, to, flag)
---@type table<string, fun(self: SmartAI, to: ServerPlayer, flag: string)>
fk.ai_card_chosen = {}

---[reason] = function(self, to, min, max, flag)
fk.ai_cards_chosen = {}

---[skill_name] = function(self, choices, prompt, detailed, all_choices)
---@type table<string, fun(self: SmartAI, choices: string[], prompt: string, detailed: bool, all_choices: string[])>
fk.ai_ask_choice = {}

---[judge.reason] = {judge.pattern,isgood}
---@type table<string, {pattern: string,isgood: boolean}>
fk.ai_judge = {}

---[gameMode] = function(self, to)
---
---根据游戏模式定义目标敌友值
---
---返回的值大于0则为敌，小于0则为友，一般是值大于等于3才会杀目标，小于等于-2才会救目标
---@type table<string, fun(self: SmartAI, to: ServerPlayer)>
fk.ai_objective_level = {}

--[[
  * SmartAI类成员函数部分 *
--]]

--[[
  * command处理函数部分 *
  这部分就像RandomAI一样对各种请求类型返回相应的数据。
  当然了，SmartAI会尽可能做出合乎逻辑的决策。
--]]

---@type table<string, fun(self: SmartAI, jsonData: string): string>
local smart_cb = {}

--- 请求发动主动技
---
--- 总的请求技，从它分支出各种功能技
smart_cb["AskForUseActiveSkill"] = function(self, jsonData)
  local data = json.decode(jsonData)
  local skill = Fk.skills[data[1]]
  local prompt = data[2]
  local cancelable = data[3]
  self:updatePlayers()
  local extra_data = json.decode(data[4])
  for k, v in pairs(extra_data) do
    skill[k] = v
  end
  self.use_id = nil
  self.use_tos = {}
  local ask = fk.ai_use_skill[data[1]]
  if type(ask) == "function" then
    ask(self, prompt, cancelable, extra_data)
  end
  if self.use_id then
    return json.encode {
      card = self.use_id,
      targets = self.use_tos
    }
  end
  return ""
end

--- 请求发动技能
smart_cb["AskForSkillInvoke"] = function(self, jsonData)
  local data = json.decode(jsonData)
  local prompt = data[2]
  local extra_data = data[3]
  local ask = fk.ai_skill_invoke[data[1]]
  self:updatePlayers()
  if type(ask) == "function" then
    return ask(self, extra_data, prompt) and "1" or ""
  elseif type(ask) == "boolean" then
    return ask and "1" or ""
  elseif Fk.skills[data[1]].frequency == 1 then
    return "1"
  else
    return table.random { "1", "" }
  end
end

--- 请求AG
smart_cb["AskForAG"] = function(self, jsonData)
  local data = json.decode(jsonData)
  local prompt = data[3]
  local cancelable = data[2]
  local id_list = data[1]
  self:updatePlayers()
  local ask = fk.ai_ask_for_ag[prompt:split(":")[1]]
  if type(ask) == "function" then
    ask = ask(self, id_list, cancelable, prompt)
  end
  if type(ask) ~= "number" then
    local cards = table.map(id_list, function(id)
        return Fk:getCardById(id)
      end
    )
    self:sortValue(cards)
    ask = cards[#cards].id
  end
  return ask
end

--- 使用阶段技或卡牌
---@param self SmartAI @ai系统
---@param skill ActiveSkill|Card|ViewAsSkill @输入可用的阶段技或卡牌
---@return string @json使用数据（包含了子卡和目标）
local function usePlaySkill(self, skill)
  self.use_id = nil
  self.use_tos = {}
  Self = self.player
  self.special_skill = nil
  if skill:isInstanceOf(Card) then
    local uc = fk.ai_use_play[skill.name]
    if type(uc) == "function" then
      uc(self, skill)
    end
    if self.use_id == nil then
      if type(skill.special_skills) == "table" then
        for _, sn in ipairs(skill.special_skills) do
          uc = fk.ai_use_play[sn]
          if type(uc) == "function" then
            uc(self, skill)
            if self.use_id then
              break
            end
          end
        end
      end
      if skill.type == 3 then
        if self.player:getEquipment(skill.sub_type) or #self.player:getCardIds("h") <= self.player.hp then
          return ""
        end
        self.use_id = skill.id
      elseif skill.is_damage_card and skill.multiple_targets then
        if #self.enemies < #self.friends_noself then
          return ""
        end
        self.use_id = skill.id
      end
    end
  elseif skill:isInstanceOf(ViewAsSkill) then
    local selected = {}
    local cards = table.map(self.player:getCardIds("&he"), function(id)
        return Fk:getCardById(id)
      end
    )
    self:sortValue(cards)
    for _, c in ipairs(cards) do
      if skill:cardFilter(c.id, selected) then
        table.insert(selected, c.id)
      end
    end
    local tc = skill:viewAs(selected)
    if tc then
      local uc = fk.ai_use_play[tc.name]
      if type(uc) == "function" then
        uc(self, tc)
        if self.use_id then
          self.use_id = selected
        end
      end
    end
  else
    local uc = fk.ai_use_play[skill.name]
    if type(uc) == "function" then
      uc(self, skill)
    end
  end
  if self.use_id then
    if not skill:isInstanceOf(Card) then
      self.use_id = json.encode {
        skill = skill.name,
        subcards = self.use_id
      }
    end
    return json.encode {
      card = self.use_id,
      targets = self.use_tos,
      special_skill = self.special_skill
    }
  end
  return ""
end

--- 请求使用
---
---优先由prompt进行下一级的决策，需要定义self.use_id，如果卡牌需要目标也需要给self.use_tos添加角色id为目标
---
---然后若没有定义self.use_id则由card_name再进行决策
smart_cb["AskForUseCard"] = function(self, jsonData)
  local data = json.decode(jsonData)
  local pattern = data[2]
  local prompt = data[3]
  local cancelable = data[4]
  local extra_data = data[5]
  self:updatePlayers()
  self.use_id = nil
  self.use_tos = {}
  local exp = Exppattern:Parse(data[2] or data[1])
  self.avail_cards = table.filter(self.player:getCardIds("&he"), function(id)
      return exp:match(Fk:getCardById(id)) and not self.player:prohibitUse(Fk:getCardById(id))
    end
  )
  Self = self.player
  local ask = fk.ai_ask_usecard[prompt:split(":")[1]]
  if type(ask) == "function" then
    ask(self, pattern, prompt, cancelable, extra_data)
  else
    local cards = table.map(self.player:getCardIds("&he"), function(id)
        return Fk:getCardById(id)
      end
    )
    self:sortValue(cards)
    for _, sth in ipairs(self:getActives(pattern)) do
      if sth:isInstanceOf(Card) then
        if sth.skill:canUse(self.player, sth) and not self.player:prohibitUse(sth) then
          local ret = usePlaySkill(self, sth)
          if ret ~= "" then
            return ret
          end
        end
      else
        local selected = {}
        for _, c in ipairs(cards) do
          if sth:cardFilter(c.id, selected) then
            table.insert(selected, c.id)
          end
        end
        local tc = sth:viewAs(selected)
        if tc and tc:matchPattern(pattern) then
          local uc = fk.ai_use_play[tc.name]
          if type(uc) == "function" then
            uc(self, tc)
            if self.use_id then
              self.use_id = json.encode {
                skill = sth.name,
                subcards = selected
              }
              break
            end
          end
        end
      end
    end
  end
  ask = fk.ai_ask_usecard[data[1]]
  if self.use_id == nil and type(ask) == "function" then
    ask(self, pattern, prompt, cancelable, extra_data)
  end
  if self.use_id == true then
    self.use_id = self.avail_cards[1]
  end
  if self.use_id then
    return json.encode {
      card = self.use_id,
      targets = self.use_tos
    }
  end
  return ""
end

---根据事件类型获取所有满足的事件的数据表
---@param game_event string @事件类型（字符串，省略GameEvent. 例如要获取生效事件数据就输入"CardEffect"）
---@param ge any|nil @可输入起始事件
---@return table @事件数据表
function SmartAI:eventsData(game_event, ge)
  local datas = {}
  local _ge = ge or self.room.logic:getCurrentEvent()
  while _ge do
    if _ge.event == GameEvent[game_event] then
      table.insert(datas, _ge.data[1])
    end
    _ge = _ge.parent
  end
  return datas
end

---请求无懈
---
---由锦囊牌名进行下一级决策，给self.use_id定义无懈id进行使用，同时参数包含positive（boolean）来区分正反无懈
---@param self SmartAI @ai系统
---@param pattern any
---@param prompt any
---@param cancelable any
---@param extra_data any
fk.ai_ask_usecard.nullification = function(self, pattern, prompt, cancelable, extra_data)
  local datas = self:eventsData("CardEffect")
  local effect = datas[#datas] --修改了无懈的请求，不用在room.lua里加记录了
  local positive = #datas % 2 == 1
  local ask = fk.ai_nullification[effect.card.name]
  if type(ask) == "function" then
    ask(self, effect.card, self.room:getPlayerById(effect.to), self.room:getPlayerById(effect.from), positive)
  end
end

---根据事件类型获取满足的事件的数据
---@param game_event string @事件类型（字符串，省略GameEvent. 例如要获取生效事件数据就输入"CardEffect"）
---@return any @事件数据
function SmartAI:eventData(game_event)
  local event = self.room.logic:getCurrentEvent():findParent(GameEvent[game_event], true)
  return event and event.data[1]
end

---请求桃
---@param self SmartAI @ai系统
---@param pattern any
---@param prompt any
---@param cancelable any
---@param extra_data any
fk.ai_ask_usecard["#AskForPeaches"] = function(self, pattern, prompt, cancelable, extra_data)
  local dying = self:eventData("Dying")
  local who = self.room:getPlayerById(dying.who)
  if who and self:objectiveLevel(who) < -1 then
    local cards = table.map(self.player:getCardIds("&he"), function(id)
        return Fk:getCardById(id)
      end
    )
    self:sortValue(cards)
    for _, sth in ipairs(self:getActives(pattern)) do
      if sth:isInstanceOf(Card) then
        self.use_id = sth.id
        break
      else
        local selected = {}
        for _, c in ipairs(cards) do
          if sth.cardFilter(sth, c.id, selected) then
            table.insert(selected, c.id)
          end
        end
        local tc = sth.viewAs(sth, selected)
        if tc and tc:matchPattern(pattern) then
          self.use_id = json.encode {
            skill = sth.name,
            subcards = selected
          }
          break
        end
      end
    end
  end
end

fk.ai_ask_usecard["#AskForPeachesSelf"] = fk.ai_ask_usecard["#AskForPeaches"]

---修正卡牌价值
---
---根据技能会转化的牌名修正卡牌的价值，例如有倾国时黑色手牌的价值会加上闪的价值
---@param assign string[]|nil @牌名表
function SmartAI:assignValue(assign)
  assign = assign or { "slash", "peach", "jink", "nullification" }
  for v, p in ipairs(assign) do
    local kept = {}
    v = fk.ai_card[p]
    v = v and v.value or 3
    for _, sth in ipairs(self:getActives(p)) do
      if sth:isInstanceOf(Card) then
        fk.cardValue[sth.id] = self:getValue(sth, kept)
      else
        fk.cardValue[sth.name] = self:getValue(sth, kept) + v
      end
      table.insert(kept, sth)
    end
    self.keptCv = nil
  end
end

---获取卡牌价值
---
---需要自己定义卡牌或阶段技的价值（直接看标包ai文件）
---
---当有输入kept时，就是对卡牌价值进行修正，同名卡牌的价值会逐渐递减，
---例如有多张闪时，最高价值的那一张价值保持不变，然后每多一张，多的这张的价值就会减少25%，会不断累积
---@param card Card @卡牌
---@param kept string[]|nil @已有同名卡牌表（用来配合修正卡牌价值使用）
---@return number @价值
function SmartAI:getValue(card, kept)
  local v = fk.ai_card[card.name]
  v = v and v.value or 0
  if kept then
    if card:isInstanceOf(Card) then
      if self.keptCv == nil then
        self.keptCv = v
      end
      return v - #kept * 0.25
    else
      return (self.keptCv or v) - #kept * 0.25
    end
  elseif card:isInstanceOf(Card) then
    return fk.cardValue[card.id] or v
  else
    return fk.cardValue[card.name] or v
  end
end

---获取优先度
---
---需要自己定义卡牌或阶段技的优先值（直接看标包ai文件）
---@param card Card @卡牌
---@return number @优先值
function SmartAI:getPriority(card)
  local v = card and fk.ai_card[card.name]
  v = v and v.priority or 0
  if card:isInstanceOf(Card) then
    if card:isInstanceOf(Armor) then
      v = v + 7
    elseif card:isInstanceOf(Weapon) then
      v = v + 3
    elseif card:isInstanceOf(OffensiveRide) then
      v = v + 6
    elseif card:isInstanceOf(DefensiveRide) then
      v = v + 4
    end
    v = v + (13 - card.number) / 100
    v = v + card.suit / 100
    if card:isVirtual() then
      v = v - #card.subcards * 0.25
    end
  end
  return v
end

fk.compareFunc = {
  hp = function(p)
    return p.hp
  end,
  maxHp = function(p)
    return p.maxHp
  end,
  hand = function(p)
    return #p:getHandlyIds(true)
  end,
  equip = function(p)
    return #p:getCardIds("e")
  end,
  maxcards = function(p)
    return p.hp
  end,
  skill = function(p)
    return #p:getAllSkills()
  end,
  defense = function(p)
    return p.hp + #p:getHandlyIds(true)
  end
}

---对角色表进行条件排序，由低到高
---@param players ServerPlayer[] @角色表
---@param key string|nil @条件（上面compareFunc列举的，默认是状态值）
---@param reverse boolean|nil @反向排序（由高到低）
function SmartAI:sort(players, key, reverse)
  key = key or "defense"
  local func = fk.compareFunc[key]
  if func == nil then
    func = fk.compareFunc.defense
  end
  local function compare_func(a, b)
    return func(a) < func(b)
  end
  table.sort(players, compare_func)
  if reverse then
    players = table.reverse(players)
  end
end

---排序卡牌表价值，由低到高
---@param cards Card[] @卡牌表
---@param reverse boolean|nil @反向排序（由高到低）
function SmartAI:sortValue(cards, reverse)
  local function compare_func(a, b)
    return self:getValue(a) < self:getValue(b)
  end
  table.sort(cards, compare_func)
  if reverse then
    cards = table.reverse(cards)
  end
end

---排序阶段技和卡牌表优先值，由高到低
---@param cards table @阶段技和卡牌表
---@param reverse boolean|nil @反向排序（由低到高）
function SmartAI:sortPriority(cards, reverse)
  local function compare_func(a, b)
    local va = a and self:getPriority(a) or 0
    local vb = b and self:getPriority(b) or 0
    if va == vb then
      va = a and self:getValue(a) or 0
      vb = b and self:getValue(b) or 0
    end
    return va > vb
  end
  table.sort(cards, compare_func)
  if reverse then
    cards = table.reverse(cards)
  end
end

---请求打出
---
---优先按照prompt提示信息进行下一级决策，需要定义self.use_id，然后可以根据card_name再进行决策
smart_cb["AskForResponseCard"] = function(self, jsonData)
  local data = json.decode(jsonData)
  local pattern = data[2]
  local prompt = data[3]
  local cancelable = data[4]
  local extra_data = data[5]
  self:updatePlayers()
  self.use_id = nil
  local ask = fk.ai_response_card[prompt:split(":")[1]]
  if type(ask) == "function" then
    ask(self, pattern, prompt, cancelable, extra_data)
  else
    ask = fk.ai_response_card[data[1]]
    if type(ask) == "function" then
      ask(self, pattern, prompt, cancelable, extra_data)
    else
      local effect = self:eventData("CardEffect")
      if effect and (effect.card.multiple_targets or self:isEnemie(effect.from, effect.to)) then
        self:setUseId(pattern)
      end
    end
  end
  if self.use_id then
    return json.encode {
      card = self.use_id,
      targets = {}
    }
  end
  return ""
end

---根据pattern获取可用的卡牌或转化技
---
---默认是按照优先度从高到低排序
---@param pattern string @可用条件
---@return table @可用卡牌和转化技表
function SmartAI:getActives(pattern)
  local cards = table.map(self.player:getCardIds("&he"), function(id)
      return Fk:getCardById(id)
    end
  )
  local exp = Exppattern:Parse(pattern)
  cards = table.filter(cards, function(c)
      return exp:match(c)
    end
  )
  table.insertTable(cards,
    table.filter(self.player:getAllSkills(), function(s)
        return s:isInstanceOf(ViewAsSkill) and s:enabledAtResponse(self.player, pattern)
      end
    )
  )
  self:sortPriority(cards)
  return cards
end

---根据pattern直接定义self.use_id
---
---默认是按照优先度从高到低排序且优先使用价值低的卡牌或转化技
---@param pattern string @可用条件
function SmartAI:setUseId(pattern)
  local cards = table.map(self.player:getCardIds("&he"), function(id)
      return Fk:getCardById(id)
    end
  )
  self:sortValue(cards)
  for _, sth in ipairs(self:getActives(pattern)) do
    if sth:isInstanceOf(Card) then
      self.use_id = sth.id
      break
    else
      local selected = {}
      for _, c in ipairs(cards) do
        if sth:cardFilter(c.id, selected) then
          table.insert(selected, c.id)
        end
      end
      local tc = sth:viewAs(selected)
      if tc and tc:matchPattern(pattern) then
        self.use_id = json.encode {
          skill = sth.name,
          subcards = selected
        }
        break
      end
    end
  end
end

---根据pattern获取可用的转化技
---@param pattern string @可用条件
---@return table @可用转化技表
function SmartAI:cardsView(pattern)
  local actives = table.filter(self.player:getAllSkills(), function(s)
      return s:isInstanceOf(ViewAsSkill) and s:enabledAtResponse(self.player, pattern)
    end
  )
  return actives
end

---空闲点使用
smart_cb["PlayCard"] = function(self, jsonData)
  local cards = table.map(self.player:getHandlyIds(true), function(id)
      return Fk:getCardById(id)
    end
  )
  cards = table.filter(cards, function(c)
      return c.skill:canUse(self.player, c) and not self.player:prohibitUse(c)
    end)
  table.insertTable(cards,
    table.filter(self.player:getAllSkills(), function(s)
        return s:isInstanceOf(ActiveSkill) and s:canUse(self.player)
        or s:isInstanceOf(ViewAsSkill) and s:enabledAtPlay(self.player)
      end
    )
  )
  if #cards < 1 then return "" end
  self:updatePlayers()
  self:sortPriority(cards)
  for _, sth in ipairs(cards) do
    local ret = usePlaySkill(self, sth)
    if ret ~= "" then
      return ret
    end
  end
  return ""
end

---请求选择角色区域牌
---
---按照reason原因进行下一级决策，需返回选择的牌id，同时设置有兜底决策
smart_cb["AskForCardChosen"] = function(self, jsonData)
  local data = json.decode(jsonData)
  local to = self.room:getPlayerById(data[1])
  local chosen = fk.ai_card_chosen[data[3]]
  if type(chosen) == "function" then
    return chosen(self, to, data[2]) or ""
  elseif table.contains(self.friends, to) then
    if string.find(data[2], "j") then
      local jc = to:getCardIds("j")
      if #jc > 0 then
        return table.random(jc)
      end
    end
  else
    if string.find(data[2], "h") then
      local hc = to:getCardIds("h")
      if #hc == 1 then
        return hc[1]
      end
    end
    if string.find(data[2], "e") then
      local ec = to:getCardIds("e")
      if #ec > 0 then
        return table.random(ec)
      end
    end
    if string.find(data[2], "h") then
      local hc = to:getCardIds("h")
      if #hc > 0 then
        return table.random(hc)
      end
    end
  end
  return ""
end

---请求选择角色区域多张牌
---
---按照reason原因进行下一级决策，需返回选择的牌id表，同时设置有兜底决策
smart_cb["AskForCardsChosen"] = function(self, jsonData)
  local data = json.decode(jsonData)
  local to = self.room:getPlayerById(data[1])
  local min = data[2]
  local max = data[3]
  local flag = data[4]
  local ids = {}
  local chosen = fk.ai_cards_chosen[data[5]]
  if type(chosen) == "function" then
    return chosen(self, to, min, max, flag)
  elseif table.contains(self.friends, to) then
    if string.find(flag, "j") then
      for _, id in ipairs(to:getCardIds("j")) do
        if #ids<max then
          table.insert(ids,id)
        end
      end
    end
  else
    if string.find(flag, "h") then
      local hc = to:getCardIds("h")
      if max - #ids >= #hc then
        for _, id in ipairs(hc) do
          table.insert(ids,id)
        end
      end
    end
    if string.find(flag, "e") then
      for _, id in ipairs(to:getCardIds("e")) do
        if #ids<max then
          table.insert(ids,id)
        end
      end
    end
    if string.find(flag, "h") then
      for _, id in ipairs(to:getCardIds("h")) do
        if #ids<max then
          table.insertIfNeed(ids,id)
        end
      end
    end
  end
  return #ids >= min and json.encode(ids) or ""
end

---请求选择选项
---
---按照skill_name进行下一级决策，需返回要选择的选项，兜底决策是随机选择
smart_cb["AskForChoice"] = function(self, jsonData)
  local data = json.decode(jsonData)
  local choices = data[1] ---@type string[]
  local all_choices = data[2]
  local prompt = data[4]
  local detailed = data[5]
  local chosen = fk.ai_ask_choice[data[3]]
  if type(chosen) == "function" then
    chosen = chosen(self, choices, prompt, detailed, all_choices)
  end
  return table.contains(choices,chosen) and chosen or table.random(choices)
end

fk.ai_judge.indulgence = { ".|.|heart", true }
fk.ai_judge.lightning = { ".|2~9|spade", false }
fk.ai_judge.supply_shortage = { ".|.|club", true }

---改判，输出要改判牌的id
---
---需要自己定义判定的好坏在fk.ai_judge，例如闪电fk.ai_judge.lightning = { ".|2~9|spade", false }，第一个值是满足的条件，第二个值是满足条件后的好坏
---@param cards Card[] @可用改判的卡牌表
---@param exchange boolean|nil @是否可交换（类似鬼道）
---@return number|nil @改判牌id
function SmartAI:getRetrialCardId(cards, exchange)
  local judge = self:eventData("Judge")
  local ai_judge = fk.ai_judge[judge.reason] or {judge.pattern,true}
  local isgood = judge.card:matchPattern(ai_judge[1])==ai_judge[2]
  local canRetrial = {}
  self:sortValue(cards)
  if exchange then
    for _, c in ipairs(cards) do
      if c:matchPattern(judge.pattern) == isgood then
        table.insert(canRetrial, c)
      end
    end
  else
    if isgood then
      if self:isFriend(judge.who) then
        return
      end
    elseif self:isEnemie(judge.who) then
      return
    end
  end
  for _, c in ipairs(cards) do
    if self:isFriend(judge.who) and c:matchPattern(ai_judge[1])==ai_judge[2]
    or self:isEnemie(judge.who) and c:matchPattern(ai_judge[1])~=ai_judge[2]
    then
      table.insert(canRetrial, c)
    end
  end
  if #canRetrial > 0 then
    return canRetrial[1].id
  end
end

---请求观星
---@param self SmartAI @ai系统
---@param jsonData any @总数据
---@return string @json放置顶和底的牌id表
smart_cb["AskForGuanxing"] = function(self, jsonData)
  local data = json.decode(jsonData)
  local cards = table.map(data.cards, function(id)
      return Fk:getCardById(id)
    end
  )
  self:sortValue(cards)
  local function table_clone(self)
    local t = {}
    for _, r in ipairs(self) do
      table.insert(t, r)
    end
    return t
  end
  local top = {}
  if self.room.current.phase < Player.Play then
    local jt = table.map(self.room.current:getCardIds("j"), function(id)
        return Fk:getCardById(id)
      end
    )
    if #jt > 0 then
      for _, j in ipairs(table.reverse(jt)) do
        local tj = fk.ai_judge[j.name]
        if tj then
          for _, c in ipairs(table_clone(cards)) do
            if tj[2] == c:matchPattern(tj[1]) and #top < data.max_top_cards then
              table.insert(top, c.id)
              table.removeOne(cards, c)
              tj = 1
              break
            end
          end
        end
        if tj ~= 1 and #cards > 0 and #top < data.max_top_cards then
          table.insert(top, cards[1].id)
          table.remove(cards, 1)
        end
      end
    end
    self:sortValue(cards, true)
    for _, c in ipairs(table_clone(cards)) do
      if #top < data.max_top_cards and c.skill:canUse(self.player, c) and usePlaySkill(self, c) ~= "" then
        table.insert(top, c.id)
        table.removeOne(cards, c)
        break
      end
    end
  end
  for _, c in ipairs(table_clone(cards)) do
    if #top < data.min_top_cards then
      table.insert(top, c.id)
      table.removeOne(cards, c)
      break
    end
  end
  return json.encode {
    top,
    table.map(cards, function(c)
        return c.id
      end
    )
  }
end

---更新存活身份数
---@param room Room
---@return table
local function aliveRoles(room)
  fk.alive_roles = {
    lord = 0,
    loyalist = 0,
    rebel = 0,
    renegade = 0
  }
  for _, ap in ipairs(room.players) do
    fk.alive_roles[ap.role] = 0
  end
  for _, ap in ipairs(room.alive_players) do
    fk.alive_roles[ap.role] = fk.alive_roles[ap.role] + 1
  end
  return fk.alive_roles
end

fk.ai_objective_level["aaa_role_mode"] = function(self, to)--身份局的目标敌友值定义
  local ars = aliveRoles(self.room)
  if self.role == "renegade" then
    if to.role == "lord" then
      return -1
    elseif ars.rebel < 1 then
      return 4
    elseif self.ai_role[to.id] == "loyalist" then
      return ars.lord + ars.loyalist - ars.rebel
    elseif self.ai_role[to.id] == "rebel" then
      local r = ars.rebel - ars.lord + ars.loyalist
      if r >= 0 then
        return 3
      else
        return r
      end
    end
  elseif self.role == "lord" or self.role == "loyalist" then
    if self.ai_role[to.id] == "rebel" then
      return 5
    elseif to.role == "lord" then
      return -4
    elseif ars.rebel < 1 then
      if self.role == "lord" then
        return self.explicit_renegade and self.ai_role[to.id] == "renegade" and 4 or to.hp > 1 and 2 or 0
      elseif self.explicit_renegade then
        return self.ai_role[to.id] == "renegade" and 4 or -1
      else
        return 3
      end
    elseif self.ai_role[to.id] == "loyalist" then
      return -2
    elseif self.ai_role[to.id] == "renegade" then
      local r = ars.lord + ars.loyalist - ars.rebel
      if r <= 0 then
        return r
      else
        return 3
      end
    end
  elseif self.role == "rebel" then
    if to.role == "lord" then
      return 5
    elseif self.ai_role[to.id] == "loyalist" then
      return 4
    elseif self.ai_role[to.id] == "rebel" then
      return -2
    elseif self.ai_role[to.id] == "renegade" then
      local r = ars.rebel - ars.lord + ars.loyalist
      if r > 0 then
        return 1
      else
        return r
      end
    end
  end
end

---判定目标敌友值
---
---大于0为敌方，小于0为友方
---@param to ServerPlayer @判断目标
---@return number
function SmartAI:objectiveLevel(to)
  if type(to) == "number" then
    to = self.room:getPlayerById(to)
  end
  if self.player.id == to.id then
    return -3
  elseif #self.room.alive_players < 3 then
    return 5
  end
  local level = fk.ai_objective_level[self.room.settings.gameMode]
  if type(level) == "function" then
    level = level(self, to)
  else
    if self.role == "renegade" or to.role == "renegade" then
      self.explicit_renegade = true
    end
    if to.role == self.role
    or to.role == "lord" and self.role == "loyalist"
    or to.role == "loyalist" and self.role == "lord" then
      level = -2
    else
      level = 3
    end
  end
  return level or 0
end

---更新场上敌友
function SmartAI:updatePlayers()
  self.role = self.player.role
  self.enemies = {}
  self.friends = {}
  self.friends_noself = {}

  local function compare_func(a, b)
    local v1 = self.role_value[a.id].rebel
    local v2 = self.role_value[b.id].rebel
    if v1 == v2 then
      v1 = self.role_value[a.id].renegade
      v2 = self.role_value[b.id].renegade
    end
    return v1 > v2
  end
  local aps = self.room.alive_players
  table.sort(aps, compare_func)
  self.explicit_renegade = false
  local ars = aliveRoles(self.room)
  local rebel, renegade, loyalist = 0, 0, 0
  for _, ap in ipairs(aps) do
    if ap.role == "lord" then
      self.ai_role[ap.id] = "loyalist"
    elseif self.role_value[ap.id].rebel > 50 and ars.rebel > rebel then
      rebel = rebel + 1
      self.ai_role[ap.id] = "rebel"
    elseif self.role_value[ap.id].renegade > 50 and ars.renegade > renegade then
      renegade = renegade + 1
      self.ai_role[ap.id] = "renegade"
      self.explicit_renegade = self.role_value[ap.id].renegade > 100
    elseif self.role_value[ap.id].rebel < -50 and ars.loyalist > loyalist then
      loyalist = loyalist + 1
      self.ai_role[ap.id] = "loyalist"
    else
      self.ai_role[ap.id] = "neutral"
    end
  end
  self.room:setTag("ai_role", self.ai_role)
  local neutrality = {}
  for n, p in ipairs(aps) do
    n = self:objectiveLevel(p)
    if n < 0 then
      table.insert(self.friends, p)
      if p.id ~= self.player.id then
        table.insert(self.friends_noself, p)
      end
    elseif n > 0 then
      table.insert(self.enemies, p)
    else
      table.insert(neutrality, p)
    end
  end
  self:assignValue()
  --[[
	if self.enemies<1 and #neutrality>0 and#self.toUse<3 and self:getOverflow()>0 then
		function compare_func(a,b)
			return sgs.getDefense(a)<sgs.getDefense(b)
		end
		table.sort(neutrality,compare_func)
		table.insert(self.enemies,neutrality[1])
	end-]]
end

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

---给来源附加身份值
---
---关于给卡牌或技能定义身份值直接看标包ai文件
---@param player ServerPlayer @来源
---@param to ServerPlayer @目标
---@param intention number @卡牌或技能身份值
local function updateIntention(player, to, intention)
  if player.id == to.id then return end
  local ai_role = player.room:getTag("ai_role")
  local role_value = player.room:getTag("role_value")
  if player.role == "lord" then
    if role_value[to.id].rebel ~= 0
    then
      role_value[to.id].rebel = role_value[to.id].rebel + intention * (200 - role_value[to.id].rebel) / 200
    end
  else
    if to.role == "lord" or ai_role[to.id] == "loyalist" then
      role_value[player.id].rebel = role_value[player.id].rebel + intention * (200 - role_value[player.id].rebel) / 200
    elseif ai_role[to.id] == "rebel" then
      role_value[player.id].rebel = role_value[player.id].rebel - intention * (role_value[player.id].rebel + 200) / 200
    end
    if role_value[player.id].rebel < 0 and intention > 0 or role_value[player.id].rebel > 0 and intention < 0 then
      role_value[player.id].renegade = role_value[player.id].renegade + intention * (100 - role_value[player.id].renegade) / 200
    end
    local function compare_func(a, b)
      local v1 = role_value[a.id].rebel
      local v2 = role_value[b.id].rebel
      if v1 == v2 then
        v1 = role_value[a.id].renegade
        v2 = role_value[b.id].renegade
      end
      return v1 > v2
    end
    local aps = player.room.alive_players
    table.sort(aps, compare_func)
    player.explicit_renegade = false
    local ars = aliveRoles(player.room)
    local rebel, renegade, loyalist = 0, 0, 0
    for _, ap in ipairs(aps) do
      if ap.role == "lord" then
        ai_role[ap.id] = "loyalist"
      elseif role_value[ap.id].rebel > 50 and ars.rebel > rebel then
        rebel = rebel + 1
        ai_role[ap.id] = "rebel"
      elseif role_value[ap.id].renegade > 50 and ars.renegade > renegade then
        renegade = renegade + 1
        ai_role[ap.id] = "renegade"
        player.explicit_renegade = role_value[ap.id].renegade > 100
      elseif role_value[ap.id].rebel < -50 and ars.loyalist > loyalist then
        loyalist = loyalist + 1
        ai_role[ap.id] = "loyalist"
      else
        ai_role[ap.id] = "neutral"
      end
    end --[[
    fk.qWarning(--提示身份值变化信息，消除注释后就会在调试框中显示
      player.general ..
      " " ..
      intention ..
      " " ..
      ai_role[player.id] ..
      " rebelValue:" .. role_value[player.id].rebel .. " renegadeValue:" .. role_value[player.id].renegade
    ) --]]
  end
  player.room:setTag("ai_role", ai_role)
  player.room:setTag("role_value", role_value)
end

--[[
function SmartAI:filterEvent(event, player, data)
end--]]
--增加全局触发技，这样就不用在gamelogic.lua里增加接口了
local filterEvent = fk.CreateTriggerSkill {
  name = "filter_event",
  events = {
    fk.TargetSpecified,
    --fk.GameStart,
    --fk.AfterCardsMove,
    fk.CardUsing
  },
  priority = -1,
  global = true,
  can_trigger = function(self, event, target, player, data)
    return target == nil or target == player
  end,
  on_trigger = function(self, event, target, player, data)
    local room = player.room
    if event == fk.TargetSpecified then
      local callback = fk.ai_card[data.card.name]
      callback = callback and callback.intention
      if type(callback) == "function" then
        for _, p in ipairs(TargetGroup:getRealTargets(data.tos)) do
          p = room:getPlayerById(p)
          local intention = callback(p.ai, data.card, room:getPlayerById(data.from))
          if type(intention) == "number" then
            updateIntention(room:getPlayerById(data.from), p, intention)
          end
        end
      elseif type(callback) == "number" then
        for _, p in ipairs(TargetGroup:getRealTargets(data.tos)) do
          p = room:getPlayerById(p)
          updateIntention(room:getPlayerById(data.from), p, callback)
        end
      end
    elseif event == fk.CardUsing then
      if data.card.name == "nullification" then
        local datas = player.ai:eventsData("CardEffect")
        local effect = datas[#datas]
        local to = room:getPlayerById(effect.to)
        local from = room:getPlayerById(data.from)
        local callback = fk.ai_card[effect.card.name]
        callback = callback and callback.intention
        if #datas % 2 == 1 then
          if type(callback) == "function" then
            callback = callback(to.ai, effect.card, from)
            if type(callback) == "number" then
              updateIntention(from, to, -callback)
            end
          elseif type(callback) == "number" then
            updateIntention(from, to, -callback)
          end
        else
          if type(callback) == "function" then
            callback = callback(to.ai, effect.card, from)
            if type(callback) == "number" then
              updateIntention(from, to, callback)
            end
          elseif type(callback) == "number" then
            updateIntention(from, to, callback)
          end
        end
      end
    elseif event == fk.AfterCardsMove then
    end
  end
}
Fk:addSkill(filterEvent)

---判断目标是否虚弱
---@param player ServerPlayer @目标，默认是自己
---@param getAP boolean|nil @默认包含目标可知的桃酒（未完成）
---@return boolean
function SmartAI:isWeak(player, getAP)
  player = player or self.player
  if type(player) == "number" then
    player = self.room:getPlayerById(player)
  end
  return player.hp < 2 or player.hp <= 2 and #player:getCardIds("&h") <= 2
end

---判断目标是否是友军
---
---如果有tp就判断p和tp之间是否是友军，否则就判断p是不是自己的友军
---@param p ServerPlayer @目标
---@param tp ServerPlayer|nil @比较目标
---@return boolean|nil @有时候需要nil来判断中立角色
function SmartAI:isFriend(p, tp)
  if tp then
    local bt = self:isFriend(p)
    return bt ~= nil and bt == self:isFriend(tp)
  end
  local ve = self:objectiveLevel(p)
  if ve < 0 then
    return true
  elseif ve > 0 then
    return false
  end
end

---判断目标是否是敌军
---
---如果有tp就判断p和tp之间是否是敌军，否则就判断p是不是自己的敌军
---@param p ServerPlayer @目标
---@param tp ServerPlayer|nil @比较目标
---@return boolean|nil @有时候需要nil来判断中立角色
function SmartAI:isEnemie(p, tp)
  if tp then
    local bt = self:isFriend(p)
    return bt ~= nil and bt ~= self:isFriend(tp)
  end
  local ve = self:objectiveLevel(p)
  if ve > 0 then
    return true
  elseif ve < 0 then
    return false
  end
end

return SmartAI
