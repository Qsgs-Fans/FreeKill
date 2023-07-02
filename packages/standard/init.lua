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
    local room = target.room
    return data.card ~= nil and
      target == player and
      target:hasSkill(self.name) and not target.dead and
      table.find(data.card:isVirtual() and data.card.subcards or {data.card.id}, function(id) return room:getCardArea(id) == Card.Processing end)
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local dummy = Fk:cloneCard("jueying")
    dummy:addSubcards(table.filter(data.card:isVirtual() and data.card.subcards or {data.card.id}, function(id) return room:getCardArea(id) == Card.Processing end))
    room:obtainCard(player.id, dummy, false)
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
    return not table.every(Fk:currentRoom().alive_players, function(p)
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
        local cardResponded = room:askForResponse(p, "jink", "jink", "#hujia-ask:%s", player.id)
        if cardResponded then
          room:responseCard({
            from = p.id,
            card = cardResponded,
            skipDrop = true,
          })

          data.card = cardResponded
          return false
        end
      end
    end

    if event == fk.PreCardUse and player.phase == Player.Play then
      room:setPlayerMark(player, "hujia-failed-phase", 1)
    end
    return true
  end,
  refresh_events = {fk.CardUsing},
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
    local card = room:askForResponse(player, self.name, ".|.|.|hand", prompt, true)
    if card ~= nil then
      self.cost_data = card
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
  frequency = Skill.NotFrequent,
  can_trigger = function(self, event, target, player, data)
    local room = target.room
    local from = data.from
    return from ~= nil and
      target == player and
      target:hasSkill(self.name) and
      (not from:isNude()) and
      not target.dead
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local from = data.from
    local card = room:askForCardChosen(player, from, "he", self.name)
    room:obtainCard(player.id, card, false)
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
    return target == player and
      target:hasSkill(self.name) and
      not target.dead
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local from = data.from
    if from then room:doIndicate(player.id, {from.id}) end
    local judge = {
      who = player,
      reason = self.name,
      pattern = ".|.|^heart",
    }
    room:judge(judge)
    if judge.card.suit ~= Card.Heart and from then
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
    local ret = (target == player and player:hasSkill(self.name) and player.phase == Player.Draw)
    if ret then
      local room = player.room
      for _, p in ipairs(room:getOtherPlayers(player)) do
        if not p:isKongcheng() then
          return true
        end
      end
    end
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    local other = room:getOtherPlayers(player)
    local targets = {}
    for _, p in ipairs(other) do
      if not p:isKongcheng() then
        table.insert(targets, p.id)
      end
    end

    local result = room:askForChoosePlayers(player, targets, 1, 2, "#tuxi-ask", self.name)
    if #result > 0 then
      self.cost_data = result
      return true
    end
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    for _, id in ipairs(self.cost_data) do
      local p = room:getPlayerById(id)
      local c = room:askForCardChosen(player, p, "h", self.name)
      room:obtainCard(player.id, c, false)
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

  refresh_events = {fk.DamageCaused},
  can_refresh = function(self, event, target, player, data)
    if target ~= player or player:usedSkillTimes(self.name) == 0 then
      return
    end

    if data.chain then return end

    local c = data.card
    return c and c.trueName == "slash" or c.name == "duel"
  end,
  on_refresh = function(self, event, target, player, data)
    local room = player.room
    room:broadcastSkillInvoke(self.name)
    room:notifySkillInvoked(player, self.name)
    data.damage = data.damage + 1
  end,
}
local xuchu = General:new(extension, "xuchu", "wei", 4)
xuchu:addSkill(luoyi)

local tiandu = fk.CreateTriggerSkill{
  name = "tiandu",
  events = {fk.FinishJudge},
  on_use = function(self, event, target, player, data)
    local room = player.room
    room:obtainCard(player.id, data.card)
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
    -- TODO: yiji logic
    player:drawCards(2)
  end,
}
local guojia = General:new(extension, "guojia", "wei", 3)
guojia:addSkill(tiandu)
guojia:addSkill(yiji)

local luoshen = fk.CreateTriggerSkill{
  name = "luoshen",
  anim_type = "drawcard",
  events = {fk.EventPhaseStart},
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(self.name) and
      player.phase == Player.Start
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    while true do
      local judge = {
        who = player,
        reason = self.name,
        pattern = ".|A~K|spade,club",
      }
      room:judge(judge)
      if judge.card.color ~= Card.Black then
        break
      end

      if not room:askForSkillInvoke(player, self.name) then
        break
      end
    end
  end,

  refresh_events = {fk.FinishJudge},
  can_refresh = function(self, event, target, player, data)
    return target == player and player:hasSkill(self.name) and
      data.reason == self.name and data.card.color == Card.Black
  end,
  on_refresh = function(self, event, target, player, data)
    local room = player.room
    room:obtainCard(player.id, data.card)
  end,
}
local qingguo = fk.CreateViewAsSkill{
  name = "qingguo",
  anim_type = "defensive",
  pattern = "jink",
  card_filter = function(self, to_select, selected)
    if #selected == 1 then return false end
    return Fk:getCardById(to_select).color == Card.Black
      and Fk:currentRoom():getCardArea(to_select) ~= Player.Equip
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

local rendetrig = fk.CreateTriggerSkill{
  name = "#rendetrig",
  mute = true,
  refresh_events = {fk.EventPhaseStart},
  can_refresh = function(self, event, target, player, data)
    return target == player and player:hasSkill(self.name) and player.phase == Player.NotActive
  end,
  on_refresh = function(self, event, target, player, data)
    local room = player.room
    room:setPlayerMark(player, "_rende_cards", 0)
  end,
}
local rende = fk.CreateActiveSkill{
  name = "rende",
  anim_type = "support",
  card_filter = function(self, to_select, selected)
    return Fk:currentRoom():getCardArea(to_select) ~= Card.PlayerEquip
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
    local marks = player:getMark("_rende_cards")
    local dummy = Fk:cloneCard'slash'
    dummy:addSubcards(cards)
    room:obtainCard(target.id, dummy, false, fk.ReasonGive)
    room:addPlayerMark(player, "_rende_cards", #cards)
    if marks < 2 and marks + #cards >= 2 and player:isWounded() then
      room:recover{
        who = player,
        num = 1,
        skillName = self.name
      }
    end
  end,
}
rende:addRelatedSkill(rendetrig)

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
    return not table.every(Fk:currentRoom().alive_players, function(p)
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
        local cardResponded = room:askForResponse(p, "slash", "slash", "#jijiang-ask:%s", player.id)
        if cardResponded then
          room:responseCard({
            from = p.id,
            card = cardResponded,
            skipDrop = true,
          })

          data.card = cardResponded
          return false
        end
      end
    end

    if event == fk.PreCardUse and player.phase == Player.Play then
      room:setPlayerMark(player, "jijiang-failed-phase", 1)
    end
    return true
  end,
  refresh_events = {fk.CardUsing},
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
  refresh_events = {fk.CardUsing},
  can_refresh = function(self, event, target, player, data)
    return target == player and player:hasSkill(self.name) and
      data.card.trueName == "slash" and
      player:usedCardTimes("slash") > 1
  end,
  on_refresh = function(self, event, target, player, data)
    player.room:broadcastSkillInvoke("paoxiao")
    player.room:doAnimate("InvokeSkill", {
      name = "paoxiao",
      player = player.id,
      skill_type = "offensive",
    })
  end,
}
local paoxiao = fk.CreateTargetModSkill{
  name = "paoxiao",
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
    player.room:broadcastSkillInvoke("kongcheng")
    player.room:doAnimate("InvokeSkill", {
      name = "kongcheng",
      player = player.id,
      skill_type = "defensive",
    })
  end,
}
local kongcheng = fk.CreateProhibitSkill{
  name = "kongcheng",
  frequency = Skill.Compulsory,
  is_prohibited = function(self, from, to, card)
    if to:hasSkill(self.name) and to:isKongcheng() then
      return card.trueName == "slash" or card.name == "duel"
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
    return (Fk.currentResponsePattern == nil and c.skill:canUse(Self)) or (Fk.currentResponsePattern and Exppattern:Parse(Fk.currentResponsePattern):match(c))
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
    return target == player and player:hasSkill(self.name) and
      data.card.type == Card.TypeTrick and
      data.card.sub_type ~= Card.SubtypeDelayedTrick
  end,
  on_use = function(self, event, target, player, data)
    player:drawCards(1, self.name)
  end,
}
local qicai = fk.CreateTargetModSkill{
  name = "qicai",
  frequency = Skill.Compulsory,
  bypass_distances = function(self, player, skill)
    local card_name = string.sub(skill.name, 1, -7) -- assuming all card skill is named with name_skill
    local card = Fk:cloneCard(card_name)
    if player:hasSkill(self.name) and card.type == Card.TypeTrick then
      return true
    end
  end,
}
local huangyueying = General:new(extension, "huangyueying", "shu", 3, 3, General.Female)
huangyueying:addSkill(jizhi)
huangyueying:addSkill(qicai)

local zhiheng = fk.CreateActiveSkill{
  name = "zhiheng",
  anim_type = "drawcard",
  can_use = function(self, player)
    return player:usedSkillTimes(self.name) == 0
  end,
  target_num = 0,
  min_card_num = 1,
  on_use = function(self, room, effect)
    local from = room:getPlayerById(effect.from)
    room:throwCard(effect.cards, self.name, from)
    room:drawCards(from, #effect.cards, self.name)
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
      room:drawCards(from, 2, self.name)
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
    return player:usedSkillTimes(self.name) < 1 and not player:isKongcheng()
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
    room:obtainCard(target.id, card, true)
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
      self.target_list = {}
      local room = player.room
      for _, p in ipairs(room:getOtherPlayers(player)) do
        if p.id ~= data.from and player:inMyAttackRange(p) then
          table.insert(self.target_list, p.id)
        end
      end
      return #self.target_list > 0
    end
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    local prompt = "#liuli-target"
    local plist, cid = room:askForChooseCardAndPlayers(player,
                          self.target_list, 1, 1, nil, prompt, self.name, true)
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
    self.trigger_times = 0
    for _, move in ipairs(data) do
      if move.from == player.id then
        for _, info in ipairs(move.moveInfo) do
          if info.fromArea == Card.PlayerEquip then
            self.trigger_times = self.trigger_times + 1
          end
        end
      end
    end
    return self.trigger_times > 0
  end,
  on_trigger = function(self, event, target, player, data)
    local ret
    for i = 1, self.trigger_times do
      ret = self:doCost(event, target, player, data)
      if ret then return ret end
    end
  end,
  on_use = function(self, event, target, player, data)
    player:drawCards(2, self.name)
  end,
}
local jieyin = fk.CreateActiveSkill{
  name = "jieyin",
  anim_type = "support",
  can_use = function(self, player)
    return player:usedSkillTimes(self.name) == 0
  end,
  card_filter = function(self, to_select, selected)
    return #selected < 2 and Fk:currentRoom():getCardArea(to_select) ~= Player.Equip
  end,
  target_filter = function(self, to_select, selected)
    local target = Fk:currentRoom():getPlayerById(to_select)
    local name = target.general
    return target:isWounded() and
      target.gender == General.Male
      and #selected < 1
  end,
  target_num = 1,
  card_num = 2,
  on_use = function(self, room, effect)
    local from = room:getPlayerById(effect.from)
    room:throwCard(effect.cards, self.name, from)
    room:recover({
      who = room:getPlayerById(effect.tos[1]),
      num = 1,
      recoverBy = effect.from,
      skillName = self.name
    })
    if from:isWounded() then
      room:recover({
        who = room:getPlayerById(effect.from),
        num = 1,
        recoverBy = effect.from,
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
    return player:usedSkillTimes(self.name) == 0
  end,
  card_filter = function(self, to_select, selected, targets)
    return #selected == 0 and Fk:currentRoom():getCardArea(to_select) ~= Player.Equip
  end,
  target_filter = function(self, to_select, selected, cards)
    return #selected == 0 and Fk:currentRoom():getPlayerById(to_select):isWounded()
  end,
  target_num = 1,
  card_num = 1,
  on_use = function(self, room, effect)
    local from = room:getPlayerById(effect.from)
    room:throwCard(effect.cards, self.name, from)
    room:recover({
      who = room:getPlayerById(effect.tos[1]),
      num = 1,
      recoverBy = effect.from,
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
      return data.to == player.id and data.card.name == "duel"
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
    return player:usedSkillTimes(self.name) == 0
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
    room:throwCard(use.cards, self.name, room:getPlayerById(use.from))
    local duel = Fk:cloneCard("duel")
    duel.skillName = self.name
    local new_use = {} ---@type CardUseStruct
    new_use.from = use.tos[2]
    new_use.tos = { { use.tos[1] } }
    new_use.card = duel
    new_use.prohibitedCardNames = { "nullification" }
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
    player:drawCards(1)
  end,
}
local diaochan = General:new(extension, "diaochan", "qun", 3, 3, General.Female)
diaochan:addSkill(lijian)
diaochan:addSkill(biyue)

local role_mode = fk.CreateGameMode{
  name = "aaa_role_mode", -- just to let it at the top of list
  minPlayer = 2,
  maxPlayer = 8,
  winner_getter = function(self, victim)
    local room = victim.room
    local winner = ""
    local alive = table.filter(room.alive_players, function(p)
      return not p.surrendered
    end)
  
    if victim.role == "lord" then
      if #alive == 1 and alive[1].role == "renegade" then
        winner = "renegade"
      else
        winner = "rebel"
      end
    elseif victim.role ~= "loyalist" then
      local lord_win = true
      for _, p in ipairs(alive) do
        if p.role == "rebel" or p.role == "renegade" then
          lord_win = false
          break
        end
      end
      if lord_win then
        winner = "lord+loyalist"
      end
    end
  
    return winner
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
      roleCheck = #Fk:currentRoom().alive_players == 2
      roleText = "only you and me"
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
          if p:isAlive() then
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
              if p:isAlive() then
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
  ["only you and me"] = "仅剩你和主公存活",
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

local heg_mode = require "packages.standard.hegemony"
extension:addGameMode(heg_mode)

-- load translations of this package
dofile "packages/standard/i18n/init.lua"

return extension
