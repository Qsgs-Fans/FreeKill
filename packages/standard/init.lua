-- SPDX-License-Identifier: GPL-3.0-or-later

local extension = Package:new("standard")
extension.metadata = require "packages.standard.metadata"

local pkgprefix = "packages/"
if UsingNewCore then pkgprefix = "packages/freekill-core/" end
dofile(pkgprefix .. "standard/game_rule.lua")
dofile(pkgprefix .. "standard/aux_skills.lua")
dofile(pkgprefix .. "standard/aux_poxi.lua")

Fk:appendKingdomMap("god", {"wei", "shu", "wu", "qun"})

local jianxiong = fk.CreateTriggerSkill{
  name = "jianxiong",
  anim_type = "masochism",
  events = {fk.Damaged},
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(self) and data.card and player.room:getCardArea(data.card) == Card.Processing
  end,
  on_use = function(self, event, target, player, data)
    player.room:obtainCard(player.id, data.card, true, fk.ReasonJustMove)
  end,
}

local hujia = fk.CreateTriggerSkill{
  name = "hujia$",
  anim_type = "defensive",
  events = {fk.AskForCardUse, fk.AskForCardResponse},
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(self) and
      (data.cardName == "jink" or (data.pattern and Exppattern:Parse(data.pattern):matchExp("jink|0|nosuit|none"))) and
      (data.extraData == nil or data.extraData.hujia_ask == nil) and
      not table.every(player.room.alive_players, function(p)
        return p == player or p.kingdom ~= "wei"
      end)
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    for _, p in ipairs(room:getOtherPlayers(player)) do
      if p:isAlive() and p.kingdom == "wei" then
        local cardResponded = room:askForResponse(p, "jink", "jink", "#hujia-ask:" .. player.id, true, {hujia_ask = true})
        if cardResponded then
          room:responseCard({
            from = p.id,
            card = cardResponded,
            skipDrop = true,
          })

          if event == fk.AskForCardUse then
            data.result = {
              from = player.id,
              card = Fk:cloneCard('jink'),
            }
            data.result.card:addSubcards(room:getSubcardsByRule(cardResponded, { Card.Processing }))
            data.result.card.skillName = self.name

            if data.eventData then
              data.result.toCard = data.eventData.toCard
              data.result.responseToEvent = data.eventData.responseToEvent
            end
          else
            data.result = Fk:cloneCard('jink')
            data.result:addSubcards(room:getSubcardsByRule(cardResponded, { Card.Processing }))
            data.result.skillName = self.name
          end
          return true
        end
      end
    end
  end,
}

local caocao = General:new(extension, "caocao", "wei", 4)
caocao:addSkill(jianxiong)
caocao:addSkill(hujia)

local guicai = fk.CreateTriggerSkill{
  name = "guicai",
  anim_type = "control",
  events = {fk.AskForRetrial},
  can_trigger = function(self, event, target, player, data)
    return player:hasSkill(self) and not player:isKongcheng()
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    local prompt = "#guicai-ask::" .. target.id
    local card = room:askForCard(player, 1, 1, false, self.name, true, ".|.|.|hand", prompt)
    if #card > 0 then
      self.cost_data = card[1]
      return true
    end
  end,
  on_use = function(self, event, target, player, data)
    player.room:retrial(Fk:getCardById(self.cost_data), player, data, self.name)
  end,
}
local fankui = fk.CreateTriggerSkill{
  name = "fankui",
  anim_type = "masochism",
  events = {fk.Damaged},
  can_trigger = function(self, event, target, player, data)
    if target == player and player:hasSkill(self) and data.from and not data.from.dead then
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
  on_use = function(self, event, target, player, data)
    local room = player.room
    local from = data.from
    if from and not from.dead then room:doIndicate(player.id, {from.id}) end
    local judge = {
      who = player,
      reason = self.name,
      pattern = ".|.|^heart",
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
    return target == player and player:hasSkill(self) and player.phase == Player.Draw and
      table.find(player.room:getOtherPlayers(player, false), function(p) return not p:isKongcheng() end)
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    local targets = table.map(table.filter(room:getOtherPlayers(player, false), function(p)
      return not p:isKongcheng() end), Util.IdMapper)

    local result = room:askForChoosePlayers(player, targets, 1, 2, "#tuxi-ask", self.name)
    if #result > 0 then
      room:sortPlayersByAction(result)
      self.cost_data = {tos = result}
      return true
    end
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    for _, id in ipairs(self.cost_data.tos) do
      if player.dead then break end
      local p = room:getPlayerById(id)
      if not p.dead and not p:isKongcheng() then
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
    return target == player and player:hasSkill(self) and data.n > 0
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
      data.card and (data.card.trueName == "slash" or data.card.name == "duel") and data.by_user
  end,
  on_cost = Util.TrueFunc,
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
    return target == player and player:hasSkill(self) and player.room:getCardArea(data.card) == Card.Processing
  end,
  on_use = function(self, event, target, player, data)
    player.room:obtainCard(player.id, data.card, true, fk.ReasonJustMove)
  end,
}
local yiji_active = fk.CreateActiveSkill{
  name = "yiji_active",
  expand_pile = function(self)
    return type(Self:getMark("yiji_cards")) == "table" and Self:getMark("yiji_cards") or {}
  end,
  min_card_num = 1,
  target_num = 1,
  card_filter = function(self, to_select, selected, targets)
    local ids = Self:getMark("yiji_cards")
      return type(ids) == "table" and table.contains(ids, to_select)
  end,
  target_filter = function(self, to_select, selected, selected_cards)
    return #selected == 0 and to_select ~= Self.id
  end,
}
local yiji = fk.CreateTriggerSkill{
  name = "yiji",
  anim_type = "masochism",
  events = {fk.Damaged},
  on_trigger = function(self, event, target, player, data)
    self.cancel_cost = false
    for _ = 1, data.damage do
      if self.cancel_cost or not player:hasSkill(self) then break end
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
    while true do
      room:setPlayerMark(player, "yiji_cards", ids)
      local _, ret = room:askForUseActiveSkill(player, "yiji_active", "#yiji-give", true, nil, true)
      room:setPlayerMark(player, "yiji_cards", 0)
      if ret then
        for _, id in ipairs(ret.cards) do
          table.removeOne(ids, id)
        end
        room:moveCardTo(ret.cards, Card.PlayerHand, room:getPlayerById(ret.targets[1]), fk.ReasonGive,
        self.name, nil, false, player.id, nil, player.id)
        if #ids == 0 then break end
        if player.dead then
          room:moveCards({
            ids = ids,
            toArea = Card.DiscardPile,
            moveReason = fk.ReasonJustMove,
            skillName = self.name,
          })
          break
        end
      else
        room:moveCardTo(ids, Player.Hand, player, fk.ReasonGive, self.name, nil, false, player.id)
        break
      end
    end
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
    return target == player and player:hasSkill(self) and player.phase == Player.Start
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
    return target == player and not player.dead and data.reason == "luoshen" and data.card.color == Card.Black and
    player.room:getCardArea(data.card) == Card.Processing
  end,
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
  prompt = "#rende-active",
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
    if marks < 2 and marks + #cards >= 2 and not player.dead and player:isWounded() then
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
  card_filter = Util.FalseFunc,
  view_as = function(self, cards)
    if #cards ~= 0 then
      return nil
    end
    local c = Fk:cloneCard("slash")
    c.skillName = self.name
    return c
  end,
  before_use = function(self, player, use)
    local room = player.room
    if use.tos then
      room:doIndicate(player.id, TargetGroup:getRealTargets(use.tos))
    end

    for _, p in ipairs(room:getOtherPlayers(player)) do
      if p.kingdom == "shu" then
        local cardResponded = room:askForResponse(p, "slash", "slash", "#jijiang-ask:" .. player.id, true)
        if cardResponded then
          room:responseCard({
            from = p.id,
            card = cardResponded,
            skipDrop = true,
          })

          use.card = cardResponded
          return
        end
      end
    end

    room:setPlayerMark(player, "jijiang-failed-phase", 1)
    return self.name
  end,
  enabled_at_play = function(self, player)
    return player:getMark("jijiang-failed-phase") == 0 and not table.every(Fk:currentRoom().alive_players, function(p)
      return p == player or p.kingdom ~= "shu"
    end)
  end,
  enabled_at_response = function(self, player)
    return not table.every(Fk:currentRoom().alive_players, function(p)
      return p == player or p.kingdom ~= "shu"
    end)
  end,
}

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
    return target == player and player:hasSkill(self) and
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
    if player:hasSkill(self) and skill.trueName == "slash_skill"
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
    return target == player and player:hasSkill(self) and
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
    if not player:hasSkill(self) then return end
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
    if to:hasSkill(self) and to:isKongcheng() then
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
    if from:hasSkill(self) then
      return -1
    end
  end,
}
local tieqi = fk.CreateTriggerSkill{
  name = "tieqi",
  anim_type = "offensive",
  events = {fk.TargetSpecified},
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(self) and
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
    return target == player and player:hasSkill(self) and data.card:isCommonTrick() and
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
    return player:hasSkill(self) and card and card.type == Card.TypeTrick
  end,
}
local huangyueying = General:new(extension, "huangyueying", "shu", 3, 3, General.Female)
huangyueying:addSkill(jizhi)
huangyueying:addSkill(qicai)

local zhiheng = fk.CreateActiveSkill{
  name = "zhiheng",
  prompt = "#zhiheng-active",
  anim_type = "drawcard",
  can_use = function(self, player)
    return player:usedSkillTimes(self.name, Player.HistoryPhase) == 0
  end,
  target_num = 0,
  min_card_num = 1,
  card_filter = function(self, to_select)
    return not Self:prohibitDiscard(Fk:getCardById(to_select))
  end,
  on_use = function(self, room, effect)
    local from = room:getPlayerById(effect.from)
    room:throwCard(effect.cards, self.name, from, from)
    if from:isAlive() then
      from:drawCards(#effect.cards, self.name)
    end
  end,
}

local jiuyuan = fk.CreateTriggerSkill{
  name = "jiuyuan$",
  anim_type = "support",
  frequency = Skill.Compulsory,
  events = {fk.PreHpRecover},
  can_trigger = function(self, event, target, player, data)
    return
      target == player and
      player:hasSkill(self) and
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
  enabled_at_response = function (self, player, response)
    return not response
  end
}
local ganning = General:new(extension, "ganning", "wu", 4)
ganning:addSkill(qixi)

local keji = fk.CreateTriggerSkill{
  name = "keji",
  anim_type = "defensive",
  events = {fk.EventPhaseChanging},
  can_trigger = function(self, event, target, player, data)
    if target == player and player:hasSkill(self) and data.to == Player.Discard then
      local room = player.room
      local play_ids = {}
      player.room.logic:getEventsOfScope(GameEvent.Phase, 1, function (e)
        if e.data[2] == Player.Play and e.end_id then
          table.insert(play_ids, {e.id, e.end_id})
        end
        return false
      end, Player.HistoryTurn)
      if #play_ids == 0 then return true end
      local function PlayCheck (e)
        local in_play = false
        for _, ids in ipairs(play_ids) do
          if e.id > ids[1] and e.id < ids[2] then
            in_play = true
            break
          end
        end
        return in_play and e.data[1].from == player.id and e.data[1].card.trueName == "slash"
      end
      return #player.room.logic:getEventsOfScope(GameEvent.UseCard, 1, PlayCheck, Player.HistoryTurn) == 0
      and #player.room.logic:getEventsOfScope(GameEvent.RespondCard, 1, PlayCheck, Player.HistoryTurn) == 0
    end
  end,
  on_use = function(self, event, target, player, data)
    return true
  end
}
local lvmeng = General:new(extension, "lvmeng", "wu", 4)
lvmeng:addSkill(keji)

local kurou = fk.CreateActiveSkill{
  name = "kurou",
  prompt = "#kurou-active",
  anim_type = "drawcard",
  card_filter = Util.FalseFunc,
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
  prompt = "#fanjian-active",
  can_use = function(self, player)
    return player:usedSkillTimes(self.name, Player.HistoryPhase) == 0
  end,
  card_filter = Util.FalseFunc,
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
    if Fk:getCardById(card):getSuitString() ~= choice and target:isAlive() then
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
  enabled_at_response = function (self, player, response)
    return not response
  end
}
local liuli = fk.CreateTriggerSkill{
  name = "liuli",
  anim_type = "defensive",
  events = {fk.TargetConfirming},
  can_trigger = function(self, event, target, player, data)
    local ret = target == player and player:hasSkill(self) and
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
    AimGroup:cancelTarget(data, player.id)
    AimGroup:addTargets(room, data, to)
  end,
}
local daqiao = General:new(extension, "daqiao", "wu", 3, 3, General.Female)
daqiao:addSkill(guose)
daqiao:addSkill(liuli)

local qianxun = fk.CreateProhibitSkill{
  name = "qianxun",
  frequency = Skill.Compulsory,
  is_prohibited = function(self, from, to, card)
    if to:hasSkill(self) then
      return card.name == "indulgence" or card.name == "snatch"
    end
  end,
}
local lianying = fk.CreateTriggerSkill{
  name = "lianying",
  anim_type = "drawcard",
  events = {fk.AfterCardsMove},
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(self) then return end
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
    if not player:hasSkill(self) then return end
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
    for _ = 1, i do
      if self.cancel_cost or not player:hasSkill(self) then break end
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
  prompt = "#jieyin-active",
  anim_type = "support",
  can_use = function(self, player)
    return player:usedSkillTimes(self.name, Player.HistoryPhase) == 0
  end,
  card_filter = function(self, to_select, selected)
    return #selected < 2 and Fk:currentRoom():getCardArea(to_select) == Player.Hand and not Self:prohibitDiscard(Fk:getCardById(to_select))
  end,
  target_filter = function(self, to_select, selected)
    local target = Fk:currentRoom():getPlayerById(to_select)
    return target:isWounded() and target:isMale() and #selected < 1 and to_select ~= Self.id
  end,
  target_num = 1,
  card_num = 2,
  on_use = function(self, room, effect)
    local from = room:getPlayerById(effect.from)
    local target = room:getPlayerById(effect.tos[1])
    room:throwCard(effect.cards, self.name, from, from)
    if target:isAlive() and target:isWounded() then
      room:recover({
        who = room:getPlayerById(effect.tos[1]),
        num = 1,
        recoverBy = from,
        skillName = self.name
      })
    end
    if from:isAlive() and from:isWounded() then
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
  prompt = "#qingnang-active",
  anim_type = "support",
  can_use = function(self, player)
    return player:usedSkillTimes(self.name, Player.HistoryPhase) == 0
  end,
  card_filter = function(self, to_select, selected, targets)
    return #selected == 0 and Fk:currentRoom():getCardArea(to_select) == Player.Hand and
    not Self:prohibitDiscard(Fk:getCardById(to_select))
  end,
  target_filter = function(self, to_select, selected, cards)
    return #selected == 0 and Fk:currentRoom():getPlayerById(to_select):isWounded()
  end,
  target_num = 1,
  card_num = 1,
  on_use = function(self, room, effect)
    local from = room:getPlayerById(effect.from)
    local to = room:getPlayerById(effect.tos[1])
    room:throwCard(effect.cards, self.name, from, from)
    if to:isAlive() and to:isWounded() then
      room:recover({
        who = to,
        num = 1,
        recoverBy = from,
        skillName = self.name
      })
    end
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
  enabled_at_play = Util.FalseFunc,
  enabled_at_response = function(self, player, res)
    return player.phase == Player.NotActive and not res
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
    if not player:hasSkill(self) then
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
  prompt = "#lijian-active",
  anim_type = "offensive",
  can_use = function(self, player)
    return player:usedSkillTimes(self.name, Player.HistoryPhase) == 0
  end,
  card_filter = function(self, to_select, selected)
    return #selected == 0 and not Self:prohibitDiscard(Fk:getCardById(to_select))
  end,
  target_filter = function(self, to_select, selected)
    if #selected < 2 and to_select ~= Self.id then
      local target = Fk:currentRoom():getPlayerById(to_select)
      return target:isMale() and (#selected == 0 or
      target:canUseTo(Fk:cloneCard("duel"), Fk:currentRoom():getPlayerById(selected[1])))
    end
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
    return target == player and player:hasSkill(self)
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
      local a1 = #room.general_pile
      local a2 = #room.players * generalNum
      if a1 < a2 then
        room:sendLog{
          type = "#NoEnoughGeneralDraw",
          arg = a1,
          arg2 = a2,
          toast = true,
        }
        room:gameOver("")
      end
      lord_num = math.min(a1 - a2, lord_num)
      local generals = table.connect(room:findGenerals(function(g)
        return table.contains(Fk.lords, g)
      end, lord_num), room:getNGenerals(generalNum))
      lord_generals = room:askForGeneral(lord, generals, n)
      local lord_general, deputy
      if type(lord_generals) == "table" then
        deputy = lord_generals[2]
        lord_general = lord_generals[1]
      else
        lord_general = lord_generals
        lord_generals = {lord_general}
      end
      generals = table.filter(generals, function(g)
        return not table.find(lord_generals, function(lg)
          return Fk.generals[lg].trueName == Fk.generals[g].trueName
        end)
      end)
      room:returnToGeneralPile(generals)

      room:prepareGeneral(lord, lord_general, deputy, true)

      room:askForChooseKingdom({lord})
      room:broadcastProperty(lord, "kingdom")

      -- 显示技能
      local canAttachSkill = function(player, skillName)
        local skill = Fk.skills[skillName]
        if not skill then
          fk.qCritical("Skill: "..skillName.." doesn't exist!")
          return false
        end
        if skill.lordSkill and (player.role ~= "lord" or #room.players < 5) then
          return false
        end

        if #skill.attachedKingdom > 0 and not table.contains(skill.attachedKingdom, player.kingdom) then
          return false
        end

        return true
      end

      local lord_skills = {}
      for _, s in ipairs(Fk.generals[lord.general].skills) do
        if canAttachSkill(lord, s.name) then
          table.insertIfNeed(lord_skills, s.name)
        end
      end
      for _, sname in ipairs(Fk.generals[lord.general].other_skills) do
        if canAttachSkill(lord, sname) then
          table.insertIfNeed(lord_skills, sname)
        end
      end

      local deputyGeneral = Fk.generals[lord.deputyGeneral]
      if deputyGeneral then
        for _, s in ipairs(deputyGeneral.skills) do
          if canAttachSkill(lord, s.name) then
            table.insertIfNeed(lord_skills, s.name)
          end
        end
        for _, sname in ipairs(deputyGeneral.other_skills) do
          if canAttachSkill(lord, sname) then
            table.insertIfNeed(lord_skills, sname)
          end
        end
      end
      for _, skill in ipairs(lord_skills) do
        room:doBroadcastNotify("AddSkill", json.encode{
          lord.id,
          skill
        })
      end
    end

    local nonlord = room:getOtherPlayers(lord, true)
    local generals = table.random(room.general_pile, #nonlord * generalNum)
    for i, p in ipairs(nonlord) do
      local arg = table.slice(generals, (i - 1) * generalNum + 1, i * generalNum + 1)
      p.request_data = json.encode{ arg, n }
      p.default_reply = table.random(arg, n)
    end

    room:notifyMoveFocus(nonlord, "AskForGeneral")
    room:doBroadcastRequest("AskForGeneral", nonlord)

    for _, p in ipairs(nonlord) do
      local general, deputy
      if p.general == "" and p.reply_ready then
        local general_ret = json.decode(p.client_reply)
        general = general_ret[1]
        deputy = general_ret[2]
      else
        general = p.default_reply[1]
        deputy = p.default_reply[2]
      end
      room:findGeneral(general)
      room:findGeneral(deputy)
      room:prepareGeneral(p, general, deputy)
      p.default_reply = ""
    end

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
  ["time limitation: 5 min"] = "游戏时长达到5分钟",
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
dofile(pkgprefix .. "standard/i18n/init.lua")

return extension
