-- SPDX-License-Identifier: GPL-3.0-or-later

local extension = Package:new("standard")
extension.metadata = require "packages.standard.metadata"
dofile "packages/standard/game_rule.lua"
dofile "packages/standard/aux_skills.lua"

local jianxiong = fk.CreateTriggerSkill{
  name = "jianxiong",
  anim_type = "masochism",
  events = {fk.Damaged},
  can_trigger = function(self, event, target, player, data)
    if data.card then
      local room = player.room
      local subcards = data.card:isVirtual() and data.card.subcards or {data.card.id}
      return target == player and player:hasSkill(self.name) and #subcards>0
      and table.every(subcards, function(id) return room:getCardArea(id) == Card.Processing end)  
    end
  end,
  on_use = function(self, event, target, player, data)
    player.room:obtainCard(player.id, data.card, true, fk.ReasonJustMove)
  end,
}

local hujia = fk.CreateViewAsSkill{
  name = "hujia$",
  anim_type = "defensive",
  pattern = "jink",
  card_filter = function(self, to_select, selected)
    return false
  end,
  view_as = function(self, cards)
    if #cards ~= 0 then
      return nil
    end
    local c = Fk:cloneCard("jink")
    c.skillName = self.name
    return c
  end,
  enabled_at_play = function(self, player)
    return false
  end,
  enabled_at_response = function(self, player)
    return player:getMark("hujia-failed-phase") == 0 and not table.every(Fk:currentRoom().alive_players, function(p)
      return p == player or p.kingdom ~= "wei"
    end)
  end,
}
local hujiaResponse = fk.CreateTriggerSkill{
  name = "#hujiaResponse",
  events = {fk.PreCardUse, fk.PreCardRespond},
  mute = true,
  priority = 10,
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(self.name, true) and table.contains(data.card.skillNames, "hujia")
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    room:doIndicate(player.id, TargetGroup:getRealTargets(data.tos))
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    for _, p in ipairs(room:getOtherPlayers(player)) do
      if p.kingdom == "wei" then
        local cardResponded = room:askForResponse(p, "jink", "jink", "#hujia-ask:" .. player.id, true)
        if cardResponded then
          data.card = cardResponded.card
          return false
        end
      end
    end

    room:setPlayerMark(player, "hujia-failed-phase", 1)
    return true
  end,
  refresh_events = {fk.CardUsing, fk.CardResponding},
  can_refresh = function(self, event, target, player, data)
    return target == player and player:hasSkill(self.name, true) and player:getMark("hujia-failed-phase") > 0
  end,
  on_refresh = function(self, event, target, player, data)
    player.room:setPlayerMark(player, "hujia-failed-phase", 0)
  end,
}
hujia:addRelatedSkill(hujiaResponse)

local caocao = General:new(extension, "caocao", "wei", 4)
caocao:addSkill(jianxiong)
caocao:addSkill(hujia)

local guicai = fk.CreateTriggerSkill{
  name = "guicai",
  anim_type = "control",
  events = {fk.AskForRetrial},
  can_trigger = function(self, event, target, player, data)
    return player:hasSkill(self.name) and not player:isKongcheng()
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    local prompt = "#guicai-ask::" .. target.id
    local response = room:askForResponse(player, self.name, ".|.|.|hand", prompt, true, nil, nil, true)
    if response then
      self.cost_data = response.card
      return true
    end
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    room:retrial(self.cost_data, player, data, self.name)
  end,
}
local fankui = fk.CreateTriggerSkill{
  name = "fankui",
  anim_type = "masochism",
  events = {fk.Damaged},
  can_trigger = function(self, event, target, player, data)
    if target == player and player:hasSkill(self.name) and data.from and not data.from.dead then
      if data.from == player then
        return #player.player_cards[Player.Equip] > 0
      else
        return not data.from:isNude()
      end
    end
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local from = data.from
    local flag =  from == player and "e" or "he"
    local card = room:askForCardChosen(player, from, flag, self.name)
    room:obtainCard(player.id, card, false, fk.ReasonPrey)
  end
}
local simayi = General:new(extension, "simayi", "wei", 3)
simayi:addSkill(guicai)
simayi:addSkill(fankui)

local ganglie = fk.CreateTriggerSkill{
  name = "ganglie",
  anim_type = "masochism",
  events = {fk.Damaged},
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(self.name)
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local from = data.from
    if from and not from.dead then room:doIndicate(player.id, {from.id}) end
    local judge = {
      who = player,
      reason = self.name,
      good = false,
      negative = true,
      pattern = ".|.|heart"
    }
    room:judge(judge)
    if judge.card.suit ~= Card.Heart and from and not from.dead then
      local discards = room:askForDiscard(from, 2, 2, false, self.name, true)
      if #discards == 0 then
        room:damage{
          from = player,
          to = from,
          damage = 1,
          skillName = self.name,
        }
      end
    end
  end,
}
local xiahoudun = General:new(extension, "xiahoudun", "wei", 4)
xiahoudun:addSkill(ganglie)

local tuxi = fk.CreateTriggerSkill{
  name = "tuxi",
  anim_type = "control",
  events = {fk.EventPhaseStart},
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(self.name) and player.phase == Player.Draw and
      table.find(player.room:getOtherPlayers(player), function(p) return not p:isKongcheng() end)
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    local targets = table.map(table.filter(room:getOtherPlayers(player), function(p)
      return not p:isKongcheng() end), function (p) return p.id end)

    local result = room:askForChoosePlayers(player, targets, 1, 2, "#tuxi-ask", self.name)
    if #result > 0 then
      self.cost_data = result
      return true
    end
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    for _, id in ipairs(self.cost_data) do
      if player.dead then return end
      local p = room:getPlayerById(id)
      if not p.dead then
        local c = room:askForCardChosen(player, p, "h", self.name)
        room:obtainCard(player.id, c, false, fk.ReasonPrey)
      end
    end
    return true
  end,
}
local zhangliao = General:new(extension, "zhangliao", "wei", 4)
zhangliao:addSkill(tuxi)

local luoyi = fk.CreateTriggerSkill{
  name = "luoyi",
  anim_type = "offensive",
  events = {fk.DrawNCards},
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(self.name) and data.n > 0
  end,
  on_use = function(self, event, target, player, data)
    data.n = data.n - 1
  end,
}
local luoyi_trigger = fk.CreateTriggerSkill{
  name = "#luoyi_trigger",
  mute = true,
  events = {fk.DamageCaused},
  can_trigger = function(self, event, target, player, data)
    return target == player and player:usedSkillTimes("luoyi", Player.HistoryTurn) > 0 and
      not data.chain and data.card and (data.card.trueName == "slash" or data.card.name == "duel")
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    player:broadcastSkillInvoke("luoyi")
    room:notifySkillInvoked(player, "luoyi")
    data.damage = data.damage + 1
  end,
}
local xuchu = General:new(extension, "xuchu", "wei", 4)
luoyi:addRelatedSkill(luoyi_trigger)
xuchu:addSkill(luoyi)

local tiandu = fk.CreateTriggerSkill{
  name = "tiandu",
  anim_type = "drawcard",
  events = {fk.FinishJudge},
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(self.name) and player.room:getCardArea(data.card) == Card.Processing
  end,
  on_use = function(self, event, target, player, data)
    player.room:obtainCard(player.id, data.card, true, fk.ReasonJustMove)
  end,
}
local yiji = fk.CreateTriggerSkill{
  name = "yiji",
  anim_type = "masochism",
  events = {fk.Damaged},
  on_trigger = function(self, event, target, player, data)
    self.cancel_cost = false
    for i = 1, data.damage do
      if self.cancel_cost then break end
      self:doCost(event, target, player, data)
    end
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    if room:askForSkillInvoke(player, self.name, data) then
      return true
    end
    self.cancel_cost = true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local ids = room:getNCards(2)
    local fakemove = {
      toArea = Card.PlayerHand,
      to = player.id,
      moveInfo = table.map(ids, function(id) return {cardId = id, fromArea = Card.Void} end),
      moveReason = fk.ReasonJustMove,
    }
    room:notifyMoveCards({player}, {fakemove})
    for _, id in ipairs(ids) do
      room:setCardMark(Fk:getCardById(id), "yiji", 1)
    end
    player.yiji_ids = ids --存储遗技卡牌表
    while table.find(ids, function(id) return Fk:getCardById(id):getMark("yiji") > 0 end) do
      if not room:askForUseActiveSkill(player, "yiji_active", "#yiji-give", true) then
        for _, id in ipairs(ids) do
          room:setCardMark(Fk:getCardById(id), "yiji", 0)
        end
        ids = table.filter(ids, function(id) return room:getCardArea(id) ~= Card.PlayerHand end)
        fakemove = {
          from = player.id,
          toArea = Card.Void,
          moveInfo = table.map(ids, function(id) return {cardId = id, fromArea = Card.PlayerHand} end),
          moveReason = fk.ReasonGive,
        }
        room:notifyMoveCards({player}, {fakemove})
        room:moveCards({
          fromArea = Card.Void,
          ids = ids,
          to = player.id,
          toArea = Card.PlayerHand,
          moveReason = fk.ReasonGive,
          skillName = self.name,
        })
      end
    end
  end,
}
local yiji_active = fk.CreateActiveSkill{
  name = "yiji_active",
  mute = true,
  min_card_num = 1,
  target_num = 1,
  card_filter = function(self, to_select, selected, targets)
    return Fk:getCardById(to_select):getMark("yiji") > 0
  end,
  target_filter = function(self, to_select, selected, selected_cards)
    return #selected == 0
  end,
  on_use = function(self, room, effect)
    local player = room:getPlayerById(effect.from)
    local target = room:getPlayerById(effect.tos[1])
    room:doIndicate(player.id, {target.id})
    for _, id in ipairs(effect.cards) do
      room:setCardMark(Fk:getCardById(id), "yiji", 0)
    end
    local fakemove = {
      from = player.id,
      toArea = Card.Void,
      moveInfo = table.map(effect.cards, function(id) return {cardId = id, fromArea = Card.PlayerHand} end),
      moveReason = fk.ReasonGive,
    }
    room:notifyMoveCards({player}, {fakemove})
    room:moveCards({
      fromArea = Card.Void,
      ids = effect.cards,
      to = target.id,
      toArea = Card.PlayerHand,
      moveReason = fk.ReasonGive,
      skillName = self.name,
    })
  end,
}
local guojia = General:new(extension, "guojia", "wei", 3)
Fk:addSkill(yiji_active)
guojia:addSkill(tiandu)
guojia:addSkill(yiji)

local luoshen = fk.CreateTriggerSkill{
  name = "luoshen",
  anim_type = "drawcard",
  events = {fk.EventPhaseStart},
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(self.name) and player.phase == Player.Start
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    while true do
      local judge = {
        who = player,
        reason = self.name,
        pattern = ".|.|spade,club",
      }
      room:judge(judge)
      if judge.card.color ~= Card.Black or player.dead or not room:askForSkillInvoke(player, self.name) then
        break
      end
    end
  end,
}
local luoshen_obtain = fk.CreateTriggerSkill{
  name = "#luoshen_obtain",
  mute = true,
  frequency = Skill.Compulsory,
  events = {fk.FinishJudge},
  can_trigger = function(self, event, target, player, data)
    return target == player and data.reason == "luoshen" and data.card.color == Card.Black end,
  on_use = function(self, event, target, player, data)
    player.room:obtainCard(player.id, data.card)
  end,
}
luoshen:addRelatedSkill(luoshen_obtain)
local qingguo = fk.CreateViewAsSkill{
  name = "qingguo",
  anim_type = "defensive",
  pattern = "jink",
  card_filter = function(self, to_select, selected)
    if #selected == 1 then return false end
    return Fk:getCardById(to_select).color == Card.Black
      and Fk:currentRoom():getCardArea(to_select) == Player.Hand
  end,
  view_as = function(self, cards)
    if #cards ~= 1 then
      return nil
    end
    local c = Fk:cloneCard("jink")
    c.skillName = self.name
    c:addSubcard(cards[1])
    return c
  end,
}
local zhenji = General:new(extension, "zhenji", "wei", 3, 3, General.Female)
zhenji:addSkill(luoshen)
zhenji:addSkill(qingguo)

local rende = fk.CreateActiveSkill{
  name = "rende",
  anim_type = "support",
  card_filter = function(self, to_select, selected)
    return Fk:currentRoom():getCardArea(to_select) == Card.PlayerHand
  end,
  target_filter = function(self, to_select, selected)
    return #selected == 0 and to_select ~= Self.id
  end,
  target_num = 1,
  min_card_num = 1,
  on_use = function(self, room, effect)
    local target = room:getPlayerById(effect.tos[1])
    local player = room:getPlayerById(effect.from)
    local cards = effect.cards
    local marks = player:getMark("_rende_cards-phase")
    room:moveCardTo(cards, Player.Hand, target, fk.ReasonGive, self.name, nil, false, player.id)
    room:addPlayerMark(player, "_rende_cards-phase", #cards)
    if marks < 2 and marks + #cards >= 2 and player:isWounded() then
      room:recover{
        who = player,
        num = 1,
        recoverBy = player,
        skillName = self.name
      }
    end
  end,
}

local jijiang = fk.CreateViewAsSkill{
  name = "jijiang$",
  anim_type = "offensive",
  pattern = "slash",
  card_filter = function(self, to_select, selected)
    return false
  end,
  view_as = function(self, cards)
    if #cards ~= 0 then
      return nil
    end
    local c = Fk:cloneCard("slash")
    c.skillName = self.name
    return c
  end,
  enabled_at_play = function(self, player)
    return player:getMark("jijiang-failed-phase") == 0 and not table.every(Fk:currentRoom().alive_players, function(p)
      return p == player or p.kingdom ~= "shu"
    end)
  end,
  enabled_at_response = function(self, player)
    return player:getMark("jijiang-failed-phase") == 0 and not table.every(Fk:currentRoom().alive_players, function(p)
      return p == player or p.kingdom ~= "shu"
    end)
  end,
}
local jijiangResponse = fk.CreateTriggerSkill{
  name = "#jijiangResponse",
  events = {fk.PreCardUse, fk.PreCardRespond},
  mute = true,
  priority = 10,
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(self.name, true) and table.contains(data.card.skillNames, "jijiang")
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    room:doIndicate(player.id, TargetGroup:getRealTargets(data.tos))
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    for _, p in ipairs(room:getOtherPlayers(player)) do
      if p.kingdom == "shu" then
        local cardResponded = room:askForResponse(p, "slash", "slash", "#jijiang-ask:" .. player.id, true)
        if cardResponded then
          data.card = cardResponded.card
          return false
        end
      end
    end

    room:setPlayerMark(player, "jijiang-failed-phase", 1)
    return true
  end,
  refresh_events = {fk.CardUsing, fk.CardResponding},
  can_refresh = function(self, event, target, player, data)
    return target == player and player:hasSkill(self.name, true) and player:getMark("jijiang-failed-phase") > 0
  end,
  on_refresh = function(self, event, target, player, data)
    player.room:setPlayerMark(player, "jijiang-failed-phase", 0)
  end,
}
jijiang:addRelatedSkill(jijiangResponse)

local liubei = General:new(extension, "liubei", "shu", 4)
liubei:addSkill(rende)
liubei:addSkill(jijiang)

local wusheng = fk.CreateViewAsSkill{
  name = "wusheng",
  anim_type = "offensive",
  pattern = "slash",
  card_filter = function(self, to_select, selected)
    if #selected == 1 then return false end
    return Fk:getCardById(to_select).color == Card.Red
  end,
  view_as = function(self, cards)
    if #cards ~= 1 then
      return nil
    end
    local c = Fk:cloneCard("slash")
    c.skillName = self.name
    c:addSubcard(cards[1])
    return c
  end,
}
local guanyu = General:new(extension, "guanyu", "shu", 4)
guanyu:addSkill(wusheng)

local paoxiaoAudio = fk.CreateTriggerSkill{
  name = "#paoxiaoAudio",
  visible = false,
  refresh_events = {fk.CardUsing},
  can_refresh = function(self, event, target, player, data)
    return target == player and player:hasSkill(self.name) and
      data.card.trueName == "slash" and
      player:usedCardTimes("slash") > 1
  end,
  on_refresh = function(self, event, target, player, data)
    player:broadcastSkillInvoke("paoxiao")
    player.room:doAnimate("InvokeSkill", {
      name = "paoxiao",
      player = player.id,
      skill_type = "offensive",
    })
  end,
}
local paoxiao = fk.CreateTargetModSkill{
  name = "paoxiao",
  frequency = Skill.Compulsory,
  bypass_times = function(self, player, skill, scope)
    if player:hasSkill(self.name) and skill.trueName == "slash_skill"
      and scope == Player.HistoryPhase then
      return true
    end
  end,
}
paoxiao:addRelatedSkill(paoxiaoAudio)
local zhangfei = General:new(extension, "zhangfei", "shu", 4)
zhangfei:addSkill(paoxiao)

local guanxing = fk.CreateTriggerSkill{
  name = "guanxing",
  anim_type = "control",
  events = {fk.EventPhaseStart},
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(self.name) and
      player.phase == Player.Start
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    room:askForGuanxing(player, room:getNCards(math.min(5, #room.alive_players)))
  end,
}
local kongchengAudio = fk.CreateTriggerSkill{
  name = "#kongchengAudio",
  refresh_events = {fk.AfterCardsMove},
  can_refresh = function(self, event, target, player, data)
    if not player:hasSkill(self.name) then return end
    if not player:isKongcheng() then return end
    for _, move in ipairs(data) do
      if move.from == player.id then
        for _, info in ipairs(move.moveInfo) do
          if info.fromArea == Card.PlayerHand then
            return true
          end
        end
      end
    end
  end,
  on_refresh = function(self, event, target, player, data)
    player:broadcastSkillInvoke("kongcheng")
    player.room:notifySkillInvoked(player, "kongcheng", "defensive")
  end,
}
local kongcheng = fk.CreateProhibitSkill{
  name = "kongcheng",
  frequency = Skill.Compulsory,
  is_prohibited = function(self, from, to, card)
    if to:hasSkill(self.name) and to:isKongcheng() then
      return card.trueName == "slash" or card.trueName == "duel"
    end
  end,
}
kongcheng:addRelatedSkill(kongchengAudio)
local zhugeliang = General:new(extension, "zhugeliang", "shu", 3)
zhugeliang:addSkill(guanxing)
zhugeliang:addSkill(kongcheng)

local longdan = fk.CreateViewAsSkill{
  name = "longdan",
  pattern = "slash,jink",
  card_filter = function(self, to_select, selected)
    if #selected == 1 then return false end
    local _c = Fk:getCardById(to_select)
    local c
    if _c.trueName == "slash" then
      c = Fk:cloneCard("jink")
    elseif _c.name == "jink" then
      c = Fk:cloneCard("slash")
    else
      return false
    end
    return (Fk.currentResponsePattern == nil and Self:canUse(c)) or (Fk.currentResponsePattern and Exppattern:Parse(Fk.currentResponsePattern):match(c))
  end,
  view_as = function(self, cards)
    if #cards ~= 1 then
      return nil
    end
    local _c = Fk:getCardById(cards[1])
    local c
    if _c.trueName == "slash" then
      c = Fk:cloneCard("jink")
    elseif _c.name == "jink" then
      c = Fk:cloneCard("slash")
    end
    c.skillName = self.name
    c:addSubcard(cards[1])
    return c
  end,
}
local zhaoyun = General:new(extension, "zhaoyun", "shu", 4)
zhaoyun:addSkill(longdan)

local mashu = fk.CreateDistanceSkill{
  name = "mashu",
  frequency = Skill.Compulsory,
  correct_func = function(self, from, to)
    if from:hasSkill(self.name) then
      return -1
    end
  end,
}
local tieqi = fk.CreateTriggerSkill{
  name = "tieqi",
  anim_type = "offensive",
  events = {fk.TargetSpecified},
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(self.name) and
      data.card.trueName == "slash"
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local judge = {
      who = player,
      reason = self.name,
      pattern = ".|.|heart,diamond",
    }
    room:judge(judge)
    if judge.card.color == Card.Red then
      data.disresponsive = true
    end
  end,
}
local machao = General:new(extension, "machao", "shu", 4)
machao:addSkill(mashu)
machao:addSkill(tieqi)

local jizhi = fk.CreateTriggerSkill{
  name = "jizhi",
  anim_type = "drawcard",
  events = {fk.CardUsing},
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(self.name) and data.card:isCommonTrick() and
      (not data.card:isVirtual() or #data.card.subcards == 0)
  end,
  on_use = function(self, event, target, player, data)
    player:drawCards(1, self.name)
  end,
}
local qicai = fk.CreateTargetModSkill{
  name = "qicai",
  frequency = Skill.Compulsory,
  bypass_distances = function(self, player, skill, card)
    return player:hasSkill(self.name) and card and card.type == Card.TypeTrick
  end,
}
local huangyueying = General:new(extension, "huangyueying", "shu", 3, 3, General.Female)
huangyueying:addSkill(jizhi)
huangyueying:addSkill(qicai)

local zhiheng = fk.CreateActiveSkill{
  name = "zhiheng",
  anim_type = "drawcard",
  can_use = function(self, player)
    return player:usedSkillTimes(self.name, Player.HistoryPhase) == 0
  end,
  target_num = 0,
  min_card_num = 1,
  on_use = function(self, room, effect)
    local from = room:getPlayerById(effect.from)
    room:throwCard(effect.cards, self.name, from, from)
    from:drawCards(#effect.cards, self.name)
  end
}

local jiuyuan = fk.CreateTriggerSkill{
  name = "jiuyuan$",
  anim_type = "support",
  frequency = Skill.Compulsory,
  events = {fk.PreHpRecover},
  can_trigger = function(self, event, target, player, data)
    return
      target == player and
      player:hasSkill(self.name) and
      data.card and
      data.card.trueName == "peach" and
      data.recoverBy and
      data.recoverBy.kingdom == "wu" and
      data.recoverBy ~= player
  end,
  on_use = function(self, event, target, player, data)
    data.num = data.num + 1
  end,
}

local sunquan = General:new(extension, "sunquan", "wu", 4)
sunquan:addSkill(zhiheng)
sunquan:addSkill(jiuyuan)

local qixi = fk.CreateViewAsSkill{
  name = "qixi",
  anim_type = "control",
  pattern = "dismantlement",
  card_filter = function(self, to_select, selected)
    if #selected == 1 then return false end
    return Fk:getCardById(to_select).color == Card.Black
  end,
  view_as = function(self, cards)
    if #cards ~= 1 then
      return nil
    end
    local c = Fk:cloneCard("dismantlement")
    c.skillName = self.name
    c:addSubcard(cards[1])
    return c
  end,
}
local ganning = General:new(extension, "ganning", "wu", 4)
ganning:addSkill(qixi)

local keji = fk.CreateTriggerSkill{
  name = "keji",
  anim_type = "defensive",
  events = {fk.EventPhaseChanging},
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(self.name) and
      data.to == Player.Discard and
      player:usedCardTimes("slash") < 1 and
      player:getMark("_keji_played_slash") == 0
  end,
  on_use = function(self, event, target, player, data)
    return true
  end,

  refresh_events = {fk.CardResponding, fk.EventPhaseStart},
  can_refresh = function(self, event, target, player, data)
    if not (target == player and player:hasSkill(self.name)) then
      return false
    end
    if event == fk.CardResponding then
      return player.phase == Player.Play and data.card.trueName == "slash"
    elseif event == fk.EventPhaseStart then
      return player.phase == Player.NotActive
    end
  end,
  on_refresh = function(self, event, target, player, data)
    local room = player.room
    if event == fk.CardResponding then
      room:addPlayerMark(player, "_keji_played_slash", 1)
    elseif event == fk.EventPhaseStart then
      room:setPlayerMark(player, "_keji_played_slash", 0)
    end
  end
}
local lvmeng = General:new(extension, "lvmeng", "wu", 4)
lvmeng:addSkill(keji)

local kurou = fk.CreateActiveSkill{
  name = "kurou",
  anim_type = "drawcard",
  card_filter = function(self, to_select, selected, selected_targets)
    return false
  end,
  on_use = function(self, room, effect)
    local from = room:getPlayerById(effect.from)
    room:loseHp(from, 1, self.name)
    if from:isAlive() then
      from:drawCards(2, self.name)
    end
  end
}
local huanggai = General:new(extension, "huanggai", "wu", 4)
huanggai:addSkill(kurou)

local yingzi = fk.CreateTriggerSkill{
  name = "yingzi",
  anim_type = "drawcard",
  events = {fk.DrawNCards},
  on_use = function(self, event, target, player, data)
    data.n = data.n + 1
  end,
}
local fanjian = fk.CreateActiveSkill{
  name = "fanjian",
  can_use = function(self, player)
    return player:usedSkillTimes(self.name, Player.HistoryPhase) == 0 and not player:isKongcheng()
  end,
  card_filter = function() return false end,
  target_filter = function(self, to_select, selected)
    return #selected == 0 and to_select ~= Self.id
  end,
  target_num = 1,
  on_use = function(self, room, effect)
    local player = room:getPlayerById(effect.from)
    local target = room:getPlayerById(effect.tos[1])
    local choice = room:askForChoice(target, {"spade", "heart", "club", "diamond"}, self.name)
    local card = room:askForCardChosen(target, player, 'h', self.name)
    room:obtainCard(target.id, card, true, fk.ReasonPrey)
    if Fk:getCardById(card):getSuitString() ~= choice then
      room:damage{
        from = player,
        to = target,
        damage = 1,
        skillName = self.name,
      }
    end
  end,
}
local zhouyu = General:new(extension, "zhouyu", "wu", 3)
zhouyu:addSkill(yingzi)
zhouyu:addSkill(fanjian)

local guose = fk.CreateViewAsSkill{
  name = "guose",
  anim_type = "control",
  pattern = "indulgence",
  card_filter = function(self, to_select, selected)
    if #selected == 1 then return false end
    return Fk:getCardById(to_select).suit == Card.Diamond
  end,
  view_as = function(self, cards)
    if #cards ~= 1 then
      return nil
    end
    local c = Fk:cloneCard("indulgence")
    c.skillName = self.name
    c:addSubcard(cards[1])
    return c
  end,
}
local liuli = fk.CreateTriggerSkill{
  name = "liuli",
  anim_type = "defensive",
  events = {fk.TargetConfirming},
  can_trigger = function(self, event, target, player, data)
    local ret = target == player and player:hasSkill(self.name) and
      data.card.trueName == "slash"
    if ret then
      local room = player.room
      local from = room:getPlayerById(data.from)
      for _, p in ipairs(room.alive_players) do
        if p ~= player and p.id ~= data.from and player:inMyAttackRange(p) and not from:isProhibited(p, data.card) then
          return true
        end
      end
    end
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    local prompt = "#liuli-target"
    local targets = {}
    local from = room:getPlayerById(data.from)
    for _, p in ipairs(room.alive_players) do
      if p ~= player and p.id ~= data.from and player:inMyAttackRange(p) and not from:isProhibited(p, data.card) then
        table.insert(targets, p.id)
      end
    end
    if #targets == 0 then return false end
    local plist, cid = room:askForChooseCardAndPlayers(player, targets, 1, 1, nil, prompt, self.name, true)
    if #plist > 0 then
      self.cost_data = {plist[1], cid}
      return true
    end
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local to = self.cost_data[1]
    room:doIndicate(player.id, { to })
    room:throwCard(self.cost_data[2], self.name, player, player)
    TargetGroup:removeTarget(data.targetGroup, player.id)
    TargetGroup:pushTargets(data.targetGroup, to)
  end,
}
local daqiao = General:new(extension, "daqiao", "wu", 3, 3, General.Female)
daqiao:addSkill(guose)
daqiao:addSkill(liuli)

local qianxun = fk.CreateProhibitSkill{
  name = "qianxun",
  frequency = Skill.Compulsory,
  is_prohibited = function(self, from, to, card)
    if to:hasSkill(self.name) then
      return card.name == "indulgence" or card.name == "snatch"
    end
  end,
}
local lianying = fk.CreateTriggerSkill{
  name = "lianying",
  anim_type = "drawcard",
  events = {fk.AfterCardsMove},
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(self.name) then return end
    if not player:isKongcheng() then return end
    for _, move in ipairs(data) do
      if move.from == player.id then
        for _, info in ipairs(move.moveInfo) do
          if info.fromArea == Card.PlayerHand then
            return true
          end
        end
      end
    end
  end,
  on_use = function(self, event, target, player, data)
    player:drawCards(1, self.name)
  end,
}
local luxun = General:new(extension, "luxun", "wu", 3)
luxun:addSkill(qianxun)
luxun:addSkill(lianying)

local xiaoji = fk.CreateTriggerSkill{
  name = "xiaoji",
  anim_type = "drawcard",
  events = {fk.AfterCardsMove},
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(self.name) then return end
    for _, move in ipairs(data) do
      if move.from == player.id then
        for _, info in ipairs(move.moveInfo) do
          if info.fromArea == Card.PlayerEquip then
            return true
          end
        end
      end
    end
  end,
  on_trigger = function(self, event, target, player, data)
    local i = 0
    for _, move in ipairs(data) do
      if move.from == player.id then
        for _, info in ipairs(move.moveInfo) do
          if info.fromArea == Card.PlayerEquip then
            i = i + 1
          end
        end
      end
    end
    self.cancel_cost = false
    for i = 1, i do
      if self.cancel_cost or not player:hasSkill(self.name) then break end
      self:doCost(event, target, player, data)
    end
  end,
  on_cost = function(self, event, target, player, data)
    if player.room:askForSkillInvoke(player, self.name) then
      return true
    end
    self.cancel_cost = true
  end,
  on_use = function(self, event, target, player, data)
    player:drawCards(2, self.name)
  end,
}
local jieyin = fk.CreateActiveSkill{
  name = "jieyin",
  anim_type = "support",
  can_use = function(self, player)
    return player:usedSkillTimes(self.name, Player.HistoryPhase) == 0
  end,
  card_filter = function(self, to_select, selected)
    return #selected < 2 and Fk:currentRoom():getCardArea(to_select) == Player.Hand
  end,
  target_filter = function(self, to_select, selected)
    local target = Fk:currentRoom():getPlayerById(to_select)
    return target:isWounded() and
      target.gender == General.Male
      and #selected < 1 and to_select ~= Self.id
  end,
  target_num = 1,
  card_num = 2,
  on_use = function(self, room, effect)
    local from = room:getPlayerById(effect.from)
    room:throwCard(effect.cards, self.name, from, from)
    room:recover({
      who = room:getPlayerById(effect.tos[1]),
      num = 1,
      recoverBy = from,
      skillName = self.name
    })
    if from:isWounded() then
      room:recover({
        who = from,
        num = 1,
        recoverBy = from,
        skillName = self.name
      })
    end
  end
}
local sunshangxiang = General:new(extension, "sunshangxiang", "wu", 3, 3, General.Female)
sunshangxiang:addSkill(xiaoji)
sunshangxiang:addSkill(jieyin)

local qingnang = fk.CreateActiveSkill{
  name = "qingnang",
  anim_type = "support",
  can_use = function(self, player)
    return player:usedSkillTimes(self.name, Player.HistoryPhase) == 0
  end,
  card_filter = function(self, to_select, selected, targets)
    return #selected == 0 and Fk:currentRoom():getCardArea(to_select) == Player.Hand
  end,
  target_filter = function(self, to_select, selected, cards)
    return #selected == 0 and Fk:currentRoom():getPlayerById(to_select):isWounded()
  end,
  target_num = 1,
  card_num = 1,
  on_use = function(self, room, effect)
    local from = room:getPlayerById(effect.from)
    room:throwCard(effect.cards, self.name, from, from)
    room:recover({
      who = room:getPlayerById(effect.tos[1]),
      num = 1,
      recoverBy = from,
      skillName = self.name
    })
  end,
}
local jijiu = fk.CreateViewAsSkill{
  name = "jijiu",
  anim_type = "support",
  pattern = "peach",
  card_filter = function(self, to_select, selected)
    if #selected == 1 then return false end
    return Fk:getCardById(to_select).color == Card.Red
  end,
  view_as = function(self, cards)
    if #cards ~= 1 then
      return nil
    end
    local c = Fk:cloneCard("peach")
    c.skillName = self.name
    c:addSubcard(cards[1])
    return c
  end,
  enabled_at_play = function(self, player)
    return false
  end,
  enabled_at_response = function(self, player)
    return player.phase == Player.NotActive
  end,
}
local huatuo = General:new(extension, "huatuo", "qun", 3)
huatuo:addSkill(qingnang)
huatuo:addSkill(jijiu)

local wushuang = fk.CreateTriggerSkill{
  name = "wushuang",
  anim_type = "offensive",
  frequency = Skill.Compulsory,
  events = {fk.TargetSpecified, fk.TargetConfirmed},
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(self.name) then
      return false
    end

    if event == fk.TargetSpecified then
      return target == player and table.contains({ "slash", "duel" }, data.card.trueName)
    else
      return data.to == player.id and data.card.trueName == "duel"
    end
  end,
  on_use = function(self, event, target, player, data)
    data.fixedResponseTimes = data.fixedResponseTimes or {}
    if data.card.trueName == "slash" then
      data.fixedResponseTimes["jink"] = 2
    else
      data.fixedResponseTimes["slash"] = 2
      data.fixedAddTimesResponsors = data.fixedAddTimesResponsors or {}
      table.insert(data.fixedAddTimesResponsors, (event == fk.TargetSpecified and data.to or data.from))
    end
  end,
}
local lvbu = General:new(extension, "lvbu", "qun", 4)
lvbu:addSkill(wushuang)

local lijian = fk.CreateActiveSkill{
  name = "lijian",
  anim_type = "offensive",
  can_use = function(self, player)
    return player:usedSkillTimes(self.name, Player.HistoryPhase) == 0
  end,
  card_filter = function(self, to_select, selected)
    return #selected == 0
  end,
  target_filter = function(self, to_select, selected)
    return #selected < 2 and to_select ~= Self.id and
      Fk:currentRoom():getPlayerById(to_select).gender == General.Male
  end,
  target_num = 2,
  min_card_num = 1,
  on_use = function(self, room, use)
    local player = room:getPlayerById(use.from)
    room:throwCard(use.cards, self.name, player, player)
    local duel = Fk:cloneCard("duel")
    duel.skillName = self.name
    local new_use = { ---@type CardUseStruct
      from = use.tos[2],
      tos = { { use.tos[1] } },
      card = duel,
      prohibitedCardNames = { "nullification" },
    }
    room:useCard(new_use)
  end,
}
local biyue = fk.CreateTriggerSkill{
  name = "biyue",
  anim_type = "drawcard",
  events = {fk.EventPhaseStart},
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(self.name)
      and player.phase == Player.Finish
  end,
  on_use = function(self, event, target, player, data)
    player:drawCards(1, self.name)
  end,
}
local diaochan = General:new(extension, "diaochan", "qun", 3, 3, General.Female)
diaochan:addSkill(lijian)
diaochan:addSkill(biyue)

local role_getlogic = function()
  local role_logic = GameLogic:subclass("role_logic")

  function role_logic:chooseGenerals()
    local room = self.room ---@class Room
    local generalNum = room.settings.generalNum
    local n = room.settings.enableDeputy and 2 or 1
    local lord = room:getLord()
    local lord_generals = {}
    local lord_num = 3

    if lord ~= nil then
      room.current = lord
      local generals = table.connect(room:findGenerals(function(g)
        return table.find(Fk.generals[g].skills, function(s) return s.lordSkill end)
      end, lord_num), room:getNGenerals(generalNum))
      if #room.general_pile < (#room.players - 1) * generalNum then
        room:gameOver("")
      end
      lord_generals = room:askForGeneral(lord, generals, n)
      local lord_general, deputy
      if type(lord_generals) == "table" then
        deputy = lord_generals[2]
        lord_general = lord_generals[1]
      else
        lord_general = lord_generals
        lord_generals = {lord_general}
      end

      generals = table.filter(generals, function(g) return not table.contains(lord_generals, g) end)
      room:returnToGeneralPile(generals)

      room:setPlayerGeneral(lord, lord_general, true)
      room:askForChooseKingdom({lord})
      room:broadcastProperty(lord, "general")
      room:broadcastProperty(lord, "kingdom")
      room:setDeputyGeneral(lord, deputy)
      room:broadcastProperty(lord, "deputyGeneral")
    end

    local nonlord = room:getOtherPlayers(lord, true)
    local generals = room:getNGenerals(#nonlord * generalNum)
    table.shuffle(generals)
    for i, p in ipairs(nonlord) do
      local arg = table.slice(generals, (i - 1) * generalNum + 1, i * generalNum + 1)
      p.request_data = json.encode{ arg, n }
      p.default_reply = table.random(arg, n)
    end

    room:notifyMoveFocus(nonlord, "AskForGeneral")
    room:doBroadcastRequest("AskForGeneral", nonlord)

    local selected = {}
    for _, p in ipairs(nonlord) do
      if p.general == "" and p.reply_ready then
        local general_ret = json.decode(p.client_reply)
        local general = general_ret[1]
        local deputy = general_ret[2]
        table.insertTableIfNeed(selected, general_ret)
        room:setPlayerGeneral(p, general, true, true)
        room:setDeputyGeneral(p, deputy)
      else
        room:setPlayerGeneral(p, p.default_reply[1], true, true)
        room:setDeputyGeneral(p, p.default_reply[2])
      end
      p.default_reply = ""
    end

    generals = table.filter(generals, function(g) return not table.contains(selected, g) end)
    room:returnToGeneralPile(generals)

    room:askForChooseKingdom(nonlord)
  end

  return role_logic
end

local role_mode = fk.CreateGameMode{
  name = "aaa_role_mode", -- just to let it at the top of list
  minPlayer = 2,
  maxPlayer = 8,
  logic = role_getlogic,
  is_counted = function(self, room)
    return #room.players >= 5
  end,
  surrender_func = function(self, playedTime)
    local roleCheck = false
    local roleText = ""
    local roleTable = {
      { "lord" },
      { "lord", "rebel" },
      { "lord", "rebel", "renegade" },
      { "lord", "loyalist", "rebel", "renegade" },
      { "lord", "loyalist", "rebel", "rebel", "renegade" },
      { "lord", "loyalist", "rebel", "rebel", "rebel", "renegade" },
      { "lord", "loyalist", "loyalist", "rebel", "rebel", "rebel", "renegade" },
      { "lord", "loyalist", "loyalist", "rebel", "rebel", "rebel", "rebel", "renegade" },
    }

    roleTable = roleTable[#Fk:currentRoom().players]

    if Self.role == "renegade" then
      local rebelNum = #table.filter(roleTable, function(role)
        return role == "rebel"
      end)

      for _, p in ipairs(Fk:currentRoom().players) do
        if p.role == "rebel" then
          if not p.dead then
            break
          else
            rebelNum = rebelNum - 1
          end
        end
      end

      roleCheck = rebelNum == 0
      roleText = "left lord and loyalist alive"
    elseif Self.role == "rebel" then
      local rebelNum = #table.filter(roleTable, function(role)
        return role == "rebel"
      end)

      local renegadeDead = not table.find(roleTable, function(role)
        return role == "renegade"
      end)
      for _, p in ipairs(Fk:currentRoom().players) do
        if p.role == "renegade" and p.dead then
          renegadeDead = true
        end

        if p ~= Self and p.role == "rebel" then
          if not p.dead then
            break
          else
            rebelNum = rebelNum - 1
          end
        end
      end

      roleCheck = renegadeDead and rebelNum == 1
      roleText = "left one rebel alive"
    else
      if Self.role == "loyalist" then
        return { { text = "loyalist never surrender", passed = false } }
      else
        if #Fk:currentRoom().alive_players == 2 then
          roleCheck = true
        else
          local lordNum = #table.filter(roleTable, function(role)
            return role == "lord" or role == "loyalist"
          end)

          local renegadeDead = not table.find(roleTable, function(role)
            return role == "renegade"
          end)
          for _, p in ipairs(Fk:currentRoom().players) do
            if p.role == "renegade" and p.dead then
              renegadeDead = true
            end

            if p ~= Self and (p.role == "lord" or p.role == "loyalist") then
              if not p.dead then
                break
              else
                lordNum = lordNum - 1
              end
            end
          end

          roleCheck = renegadeDead and lordNum == 1
        end
      end

      roleText = "left you alive"
    end

    return {
      { text = "time limitation: 5 min", passed = playedTime >= 300 },
      { text = roleText, passed = roleCheck },
    }
  end,
}
extension:addGameMode(role_mode)
Fk:loadTranslationTable{
  ["time limitation: 5 sec"] = "游戏时长达到5秒（测试用）",
  ["left lord and loyalist alive"] = "仅剩你和主忠方存活",
  ["left one rebel alive"] = "反贼仅剩你存活且不存在存活内奸",
  ["left you alive"] = "主忠方仅剩你存活且其他阵营仅剩一方",
  ["loyalist never surrender"] = "忠臣永不投降！",
}

local anjiang = General(extension, "anjiang", "unknown", 5)
anjiang.gender = General.Agender
anjiang.total_hidden = true

Fk:loadTranslationTable{
  ["anjiang"] = "暗将",
}

-- load translations of this package
dofile "packages/standard/i18n/init.lua"

return extension
