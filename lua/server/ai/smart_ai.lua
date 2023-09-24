-- SPDX-License-Identifier: GPL-3.0-or-later

---@class SmartAI: AI
local SmartAI = AI:subclass("SmartAI")

---@param self SmartAI
---@param skill ActiveSkill|ViewAsSkill|Card
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
    local cards =
        table.map(
          self.player:getCardIds("&he"),
          function(id)
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
      self.use_id =
          json.encode {
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

fk.ai_use_play = {}

local trust_cb = {}

trust_cb.AskForUseActiveSkill = function(self, jsonData)
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

fk.ai_use_skill = {}

fk.ai_use_skill.choose_players_skill = function(self, prompt, cancelable, data)
  local ask = fk.ai_choose_players[data.skillName]
  if type(ask) == "function" then
    ask(self, data.targets, data.min_num, data.num, cancelable)
  end
  if #self.use_tos > 0 then
    if self.use_id then
      self.use_id =
          json.encode {
            skill = data.skillName,
            subcards = self.use_id
          }
    else
      self.use_id =
          json.encode {
            skill = data.skillName,
            subcards = {}
          }
    end
  end
end

fk.ai_choose_players = {}

fk.ai_use_skill.discard_skill = function(self, prompt, cancelable, data)
  local ask = fk.ai_dis_card[data.skillName]
  self:assignValue()
  if type(ask) == "function" then
    ask = ask(self, data.min_num, data.num, data.include_equip, cancelable, data.pattern, prompt)
  end
  if type(ask) ~= "table" and not cancelable then
    local flag = "h"
    if data.include_equip then
      flag = "he"
    end
    ask = {}
    local cards =
        table.map(
          self.player:getCardIds(flag),
          function(id)
            return Fk:getCardById(id)
          end
        )
    self:sortValue(cards)
    for _, c in ipairs(cards) do
      table.insert(ask, c.id)
      if #ask >= data.min_num then
        break
      end
    end
  end
  if type(ask) == "table" and #ask >= data.min_num then
    self.use_id =
        json.encode {
          skill = data.skillName,
          subcards = ask
        }
  end
end

fk.ai_dis_card = {}

trust_cb.AskForSkillInvoke = function(self, jsonData)
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

fk.ai_skill_invoke = {}

trust_cb.AskForAG = function(self, jsonData)
  local data = json.decode(jsonData)
  local prompt = data[3]
  local cancelable = data[2]
  local id_list = data[1]
  local ask = fk.ai_askfor_ag[prompt:split(":")[1]]
  self:updatePlayers()
  if type(ask) == "function" then
    ask = ask(self, id_list, cancelable, prompt)
  end
  if type(ask) ~= "number" then
    local cards =
        table.map(
          id_list,
          function(id)
            return Fk:getCardById(id)
          end
        )
    self:sortValue(cards)
    ask = cards[#cards].id
  end
  return ask
end

fk.ai_askfor_ag = {}

trust_cb.AskForUseCard = function(self, jsonData)
  local data = json.decode(jsonData)
  local pattern = data[2]
  local prompt = data[3]
  local cancelable = data[4]
  local extra_data = data[5]
  self:updatePlayers()
  self.use_id = nil
  self.use_tos = {}
  local exp = Exppattern:Parse(data[2] or data[1])
  self.avail_cards =
      table.filter(
        self.player:getCardIds("&he"),
        function(id)
          return exp:match(Fk:getCardById(id)) and not self.player:prohibitUse(Fk:getCardById(id))
        end
      )
  Self = self.player
  local ask = fk.ai_askuse_card[prompt:split(":")[1]]
  if type(ask) == "function" then
    ask(self, pattern, prompt, cancelable, extra_data)
  else
    local cards =
        table.map(
          self.player:getCardIds("&he"),
          function(id)
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
              self.use_id =
                  json.encode {
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
  ask = fk.ai_askuse_card[data[1]]
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

fk.ai_askuse_card = {}
fk.ai_nullification = {}

fk.ai_askuse_card.nullification = function(self, pattern, prompt, cancelable, extra_data)
  local datas = self:eventsData("CardEffect")
  local effect = datas[#datas] --修改了无懈的请求，不用在room.lua里加记录了
  local positive = #datas % 2 == 1
  local ask = fk.ai_nullification[effect.card.name]
  if type(ask) == "function" then
    ask(self, effect.card, self.room:getPlayerById(effect.to), self.room:getPlayerById(effect.from), positive)
  end
end

fk.ai_askuse_card["#AskForPeaches"] = function(self, pattern, prompt, cancelable, extra_data)
  local dying = self:eventData("Dying")
  local who = self.room:getPlayerById(dying.who)
  if who and self:isFriend(who) then
    local cards =
        table.map(
          self.player:getCardIds("&he"),
          function(id)
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
          self.use_id =
              json.encode {
                skill = sth.name,
                subcards = selected
              }
          break
        end
      end
    end
  end
end

fk.ai_askuse_card["#AskForPeachesSelf"] = fk.ai_askuse_card["#AskForPeaches"]

fk.ai_card = {}
fk.cardValue = {}

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
  return v
end

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
    if card:isVirtual()
    then
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

function SmartAI:sort(players, key, inverse)
  key = key or "defense"
  local func = fk.compareFunc[key]
  if func == nil then
    func = fk.compareFunc.defense
  end
  local function compare_func(a, b)
    return func(a) < func(b)
  end
  table.sort(players, compare_func)
  if inverse then
    players = table.reverse(players)
  end
end

function SmartAI:sortValue(cards, inverse)
  local function compare_func(a, b)
    return self:getValue(a) < self:getValue(b)
  end
  table.sort(cards, compare_func)
  if inverse then
    cards = table.reverse(cards)
  end
end

function SmartAI:sortPriority(cards, inverse)
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
  if inverse then
    cards = table.reverse(cards)
  end
end

---@param self SmartAI
trust_cb.AskForResponseCard = function(self, jsonData)
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

fk.ai_response_card = {}

function SmartAI:getRetrialCardId(cards, exchange)
  local judge = self:eventData("Judge")
  local isgood = judge.good == judge.card:matchPattern(judge.pattern)
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
    if self:isFriend(judge.who) and c:matchPattern(judge.pattern)==judge.good
    or self:isEnemie(judge.who) and c:matchPattern(judge.pattern)~=judge.good
    then
      table.insert(canRetrial, c)
    end
  end
  if #canRetrial > 0 then
    return canRetrial[1].id
  end
end

function SmartAI:getActives(pattern)
  local cards =
      table.map(
        self.player:getCardIds("&he"),
        function(id)
          return Fk:getCardById(id)
        end
      )
  local exp = Exppattern:Parse(pattern)
  cards =
      table.filter(
        cards,
        function(c)
          return exp:match(c)
        end
      )
  table.insertTable(
    cards,
    table.filter(
      self.player:getAllSkills(),
      function(s)
        return s:isInstanceOf(ViewAsSkill) and s:enabledAtResponse(self.player, pattern)
      end
    )
  )
  self:sortPriority(cards)
  return cards
end

function SmartAI:setUseId(pattern)
  local cards =
      table.map(
        self.player:getCardIds("&he"),
        function(id)
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
        self.use_id =
            json.encode {
              skill = sth.name,
              subcards = selected
            }
        break
      end
    end
  end
end

function SmartAI:cardsView(pattern)
  local actives =
      table.filter(
        self.player:getAllSkills(),
        function(s)
          return s:isInstanceOf(ViewAsSkill) and s:enabledAtResponse(self.player, pattern)
        end
      )
  return actives
end

---@param self SmartAI
trust_cb.PlayCard = function(self, jsonData)
  local cards =
      table.map(
        self.player:getHandlyIds(true),
        function(id)
          return Fk:getCardById(id)
        end
      )
  cards =
      table.filter(
        cards,
        function(c)
          return c.skill:canUse(self.player, c) and not self.player:prohibitUse(c)
        end
      )
  table.insertTable(
    cards,
    table.filter(
      self.player:getAllSkills(),
      function(s)
        return s:isInstanceOf(ActiveSkill) and s:canUse(self.player) or
            s:isInstanceOf(ViewAsSkill) and s:enabledAtPlay(self.player)
      end
    )
  )
  if #cards < 1 then
    return
  end
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

fk.ai_card_chosen = {}

trust_cb.AskForCardChosen = function(self, jsonData)
  local data = json.decode(jsonData)
  local to = self.room:getPlayerById(data[1])
  local chosen = fk.ai_card_chosen[data[3]]
  if type(chosen) == "function" then
    return chosen(self, to, data[2])
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
      for c, id in ipairs(to:getCardIds("e")) do
        --c = Fk:getCardById(id)
        return id
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

fk.ai_role = {}
fk.roleValue = {}

fk.trick_judge = {}

fk.trick_judge.indulgence = { ".|.|heart", true }
fk.trick_judge.lightning = { ".|2~9|spade", false }
fk.trick_judge.supply_shortage = { ".|.|club", true }

local function table_clone(self)
  local t = {}
  for _, r in ipairs(self) do
    table.insert(t, r)
  end
  return t
end

trust_cb.AskForGuanxing = function(self, jsonData)
  local data = json.decode(jsonData)
  local cards =
      table.map(
        data.cards,
        function(id)
          return Fk:getCardById(id)
        end
      )
  self:sortValue(cards)
  local top = {}
  if self.room.current.phase < Player.Play then
    local jt =
        table.map(
          self.room.current:getCardIds("j"),
          function(id)
            return Fk:getCardById(id)
          end
        )
    if #jt > 0 then
      for i, j in ipairs(table.reverse(jt)) do
        local tj = fk.trick_judge[j.name]
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
    table.map(
      cards,
      function(c)
        return c.id
      end
    )
  }
end

function SmartAI:initialize(player)
  AI.initialize(self, player)
  self.cb_table = trust_cb
  self.player = player
  self.room = RoomInstance or ClientInstance

  fk.ai_role[player.id] = "neutral"
  fk.roleValue[player.id] = {
    lord = 0,
    loyalist = 0,
    rebel = 0,
    renegade = 0
  }
  self:updatePlayers()
end

function SmartAI:isRolePredictable()
  return self.room.settings.gameMode ~= "aaa_role_mode"
end

local function aliveRoles(room)
  fk.alive_roles = {
    lord = 0,
    loyalist = 0,
    rebel = 0,
    renegade = 0
  }
  for _, ap in ipairs(room:getAllPlayers(false)) do
    fk.alive_roles[ap.role] = 0
  end
  for _, ap in ipairs(room:getAlivePlayers(false)) do
    fk.alive_roles[ap.role] = fk.alive_roles[ap.role] + 1
  end
  return fk.alive_roles
end

function SmartAI:objectiveLevel(to)
  if self.player.id == to.id then
    return -2
  elseif #self.room:getAlivePlayers(false) < 3 then
    return 5
  end
  local ars = aliveRoles(self.room)
  if self:isRolePredictable() then
    fk.ai_role[self.player.id] = self.role
    fk.roleValue[self.player.id][self.role] = 666
    if self.role == "renegade" then
      fk.explicit_renegade = true
    end
    for _, p in ipairs(self.room:getAlivePlayers()) do
      if
          p.role == self.role or p.role == "lord" and self.role == "loyalist" or
          p.role == "loyalist" and self.role == "lord"
      then
        table.insert(self.friends, p)
        if p.id ~= self.player.id then
          table.insert(self.friends_noself, p)
        end
      else
        table.insert(self.enemies, p)
      end
    end
  elseif self.role == "renegade" then
    if to.role == "lord" then
      return -1
    elseif ars.rebel < 1 then
      return 4
    elseif fk.ai_role[to.id] == "loyalist" then
      return ars.lord + ars.loyalist - ars.rebel
    elseif fk.ai_role[to.id] == "rebel" then
      local r = ars.rebel - ars.lord + ars.loyalist
      if r >= 0 then
        return 3
      else
        return r
      end
    end
  elseif self.role == "lord" or self.role == "loyalist" then
    if fk.ai_role[to.id] == "rebel" then
      return 5
    elseif to.role == "lord" then
      return -2
    elseif ars.rebel < 1 then
      if self.role == "lord" then
        return fk.explicit_renegade and fk.ai_role[to.id] == "renegade" and 4 or to.hp > 1 and 2 or 0
      elseif fk.explicit_renegade then
        return fk.ai_role[to.id] == "renegade" and 4 or -1
      else
        return 3
      end
    elseif fk.ai_role[to.id] == "loyalist" then
      return -2
    elseif fk.ai_role[to.id] == "renegade" then
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
    elseif fk.ai_role[to.id] == "loyalist" then
      return 4
    elseif fk.ai_role[to.id] == "rebel" then
      return -2
    elseif fk.ai_role[to.id] == "renegade" then
      local r = ars.rebel - ars.lord + ars.loyalist
      if r > 0 then
        return 1
      else
        return r
      end
    end
  end
  return 0
end

function SmartAI:updatePlayers(update)
  self.role = self.player.role
  local neutrality = {}
  self.enemies = {}
  self.friends = {}
  self.friends_noself = {}

  local aps = self.room:getAlivePlayers()
  local function compare_func(a, b)
    local v1 = fk.roleValue[a.id].rebel
    local v2 = fk.roleValue[b.id].rebel
    if v1 == v2 then
      v1 = fk.roleValue[a.id].renegade
      v2 = fk.roleValue[b.id].renegade
    end
    return v1 > v2
  end
  table.sort(aps, compare_func)
  fk.explicit_renegade = false
  local ars = aliveRoles(self.room)
  local rebel, renegade, loyalist = 0, 0, 0
  for _, ap in ipairs(aps) do
    if ap.role == "lord" then
      fk.ai_role[ap.id] = "loyalist"
    elseif fk.roleValue[ap.id].rebel > 50 and ars.rebel > rebel then
      rebel = rebel + 1
      fk.ai_role[ap.id] = "rebel"
    elseif fk.roleValue[ap.id].renegade > 50 and ars.renegade > renegade then
      renegade = renegade + 1
      fk.ai_role[ap.id] = "renegade"
      fk.explicit_renegade = fk.roleValue[ap.id].renegade > 100
    elseif fk.roleValue[ap.id].rebel < -50 and ars.loyalist > loyalist then
      loyalist = loyalist + 1
      fk.ai_role[ap.id] = "loyalist"
    else
      fk.ai_role[ap.id] = "neutral"
    end
  end

  for n, p in ipairs(self.room:getAlivePlayers(false)) do
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
		if self.enemies<1 and #neutrality>0
		and#self.toUse<3 and self:getOverflow()>0
		then
		function compare_func(a,b)
			return sgs.getDefense(a)<sgs.getDefense(b)
		end
		table.sort(neutrality,compare_func)
		table.insert(self.enemies,neutrality[1])
		end-]]
end

local function updateIntention(player, to, intention)
  if player.id == to.id then
    return
  elseif player.role == "lord" then
    if fk.roleValue[to.id].rebel ~= 0
    then
      fk.roleValue[to.id].rebel = fk.roleValue[to.id].rebel + intention * (200 - fk.roleValue[to.id].rebel) / 200
    end
  else
    if to.role == "lord" or fk.ai_role[to.id] == "loyalist" then
      fk.roleValue[player.id].rebel = fk.roleValue[player.id].rebel +
          intention * (200 - fk.roleValue[player.id].rebel) / 200
    elseif fk.ai_role[to.id] == "rebel" then
      fk.roleValue[player.id].rebel = fk.roleValue[player.id].rebel -
          intention * (fk.roleValue[player.id].rebel + 200) / 200
    end
    if fk.roleValue[player.id].rebel < 0 and intention > 0 or fk.roleValue[player.id].rebel > 0 and intention < 0 then
      fk.roleValue[player.id].renegade = fk.roleValue[player.id].renegade +
          intention * (100 - fk.roleValue[player.id].renegade) / 200
    end
    local aps = player.room:getAlivePlayers()
    local function compare_func(a, b)
      local v1 = fk.roleValue[a.id].rebel
      local v2 = fk.roleValue[b.id].rebel
      if v1 == v2 then
        v1 = fk.roleValue[a.id].renegade
        v2 = fk.roleValue[b.id].renegade
      end
      return v1 > v2
    end
    table.sort(aps, compare_func)
    fk.explicit_renegade = false
    local ars = aliveRoles(player.room)
    local rebel, renegade, loyalist = 0, 0, 0
    for _, ap in ipairs(aps) do
      if ap.role == "lord" then
        fk.ai_role[ap.id] = "loyalist"
      elseif fk.roleValue[ap.id].rebel > 50 and ars.rebel > rebel then
        rebel = rebel + 1
        fk.ai_role[ap.id] = "rebel"
      elseif fk.roleValue[ap.id].renegade > 50 and ars.renegade > renegade then
        renegade = renegade + 1
        fk.ai_role[ap.id] = "renegade"
        fk.explicit_renegade = fk.roleValue[ap.id].renegade > 100
      elseif fk.roleValue[ap.id].rebel < -50 and ars.loyalist > loyalist then
        loyalist = loyalist + 1
        fk.ai_role[ap.id] = "loyalist"
      else
        fk.ai_role[ap.id] = "neutral"
      end
    end --[[
      fk.qWarning(
      player.general ..
      " " ..
      intention ..
      " " ..
      fk.ai_role[player.id] ..
      " rebelValue:" .. fk.roleValue[player.id].rebel .. " renegadeValue:" .. fk.roleValue[player.id].renegade
    ) --]]
  end
end

--[[
function SmartAI:filterEvent(event, player, data)
end--]]
--增加全局触发技，这样就不用在gamelogic.lua里增加接口了
local filterEvent = fk.CreateTriggerSkill {
  name = "filter_event",
  events = {
    fk.TargetSpecified,
    fk.StartJudge,
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
    elseif event == fk.StartJudge then
      fk.trick_judge[data.reason] = { data.pattern, data.good }
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

function SmartAI:isWeak(player, getAP)
  player = player or self.player
  if type(player) == "number" then
    player = self.room:getPlayerById(player)
  end
  return player.hp < 2 or player.hp <= 2 and #player:getCardIds("&h") <= 2
end

function SmartAI:isFriend(pid, tid)
  if tid then
    local bt = self:isFriend(pid)
    return bt ~= nil and bt == self:isFriend(tid)
  end
  if type(pid) == "number" then
    pid = self.room:getPlayerById(pid)
  end
  local ve = self:objectiveLevel(pid)
  if ve < 0 then
    return true
  elseif ve > 0 then
    return false
  end
end

function SmartAI:isEnemie(pid, tid)
  if tid then
    local bt = self:isFriend(pid)
    return bt ~= nil and bt ~= self:isFriend(tid)
  end
  if type(pid) == "number" then
    pid = self.room:getPlayerById(pid)
  end
  local ve = self:objectiveLevel(pid)
  if ve > 0 then
    return true
  elseif ve < 0 then
    return false
  end
end

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

function SmartAI:eventData(game_event)
  local event = self.room.logic:getCurrentEvent():findParent(GameEvent[game_event], true)
  return event and event.data[1]
end

for _, n in ipairs(FileIO.ls("packages")) do
  if FileIO.isDir("packages/" .. n .. "/ai") and FileIO.exists("packages/" .. n .. "/ai/init.lua") then
    dofile("packages/" .. n .. "/ai/init.lua")
  end
end
-- 加载两次拓展ai文件是为了能够保证引用，例如属性杀的使用直接套入普通杀的使用
for _, n in ipairs(FileIO.ls("packages")) do
  if FileIO.isDir("packages/" .. n .. "/ai") and FileIO.exists("packages/" .. n .. "/ai/init.lua") then
    dofile("packages/" .. n .. "/ai/init.lua")
  end
end

return SmartAI
