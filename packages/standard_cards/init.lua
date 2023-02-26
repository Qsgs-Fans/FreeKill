local extension = Package:new("standard_cards", Package.CardPack)
extension.metadata = require "packages.standard_cards.metadata"

Fk:loadTranslationTable{
  ["standard_cards"] = "标+EX"
}

Fk:loadTranslationTable{
  ["unknown_card"] = '<font color="#B5BA00"><b>未知牌</b></font>',
  ["log_spade"] = "♠",
  ["log_heart"] = '<font color="#CC3131">♥</font>',
  ["log_club"] = "♣",
  ["log_diamond"] = '<font color="#CC3131">♦</font>',
  ["log_nosuit"] = "无花色",
  ["nosuit"] = "无花色",
  ["spade"] = "黑桃",
  ["heart"] = "红桃",
  ["club"] = "梅花",
  ["diamond"] = "方块",
}

Fk:loadTranslationTable({
  ["unknown_card"] = '<font color="#B5BA00"><b>Unknown card</b></font>',
  ["log_spade"] = "♠",
  ["log_heart"] = '<font color="#CC3131">♥</font>',
  ["log_club"] = "♣",
  ["log_diamond"] = '<font color="#CC3131">♦</font>',
  ["log_nosuit"] = "No suit",
  ["nosuit"] = "No suit",
  ["spade"] = "Spade",
  ["heart"] = "Heart",
  ["club"] = "Club",
  ["diamond"] = "Diamond",
}, "en_US")

local slashSkill = fk.CreateActiveSkill{
  name = "slash_skill",
  max_phase_use_time = 1,
  target_num = 1,
  can_use = function(self, player)
    return player:usedCardTimes("slash", Player.HistoryPhase) < self:getMaxUseTime(Self, Player.HistoryPhase)
  end,
  target_filter = function(self, to_select, selected, _, card)
    if #selected < self:getMaxTargetNum(Self, card) then
      local player = Fk:currentRoom():getPlayerById(to_select)
      return Self ~= player and Self:inMyAttackRange(player)
    end
  end,
  on_effect = function(self, room, effect)
    local to = effect.to
    local from = effect.from

    room:damage({
      from = room:getPlayerById(from),
      to = room:getPlayerById(to),
      card = effect.card,
      damage = 1 + (effect.addtionalDamage or 0),
      damageType = fk.NormalDamage,
      skillName = self.name
    })
  end
}
local slash = fk.CreateBasicCard{
  name = "slash",
  number = 7,
  suit = Card.Spade,
  skill = slashSkill,
}
Fk:loadTranslationTable{
  ["slash"] = "杀",
  ["#slash-jink"] = "%src 对你使用了杀，请使用 %arg 张闪",
}

extension:addCards({
  slash,
  slash:clone(Card.Spade, 8),
  slash:clone(Card.Spade, 8),
  slash:clone(Card.Spade, 9),
  slash:clone(Card.Spade, 9),
  slash:clone(Card.Spade, 10),
  slash:clone(Card.Spade, 10),

  slash:clone(Card.Club, 2),
  slash:clone(Card.Club, 3),
  slash:clone(Card.Club, 4),
  slash:clone(Card.Club, 5),
  slash:clone(Card.Club, 6),
  slash:clone(Card.Club, 7),
  slash:clone(Card.Club, 8),
  slash:clone(Card.Club, 8),
  slash:clone(Card.Club, 9),
  slash:clone(Card.Club, 9),
  slash:clone(Card.Club, 10),
  slash:clone(Card.Club, 10),
  slash:clone(Card.Club, 11),
  slash:clone(Card.Club, 11),

  slash:clone(Card.Heart, 10),
  slash:clone(Card.Heart, 10),
  slash:clone(Card.Heart, 11),

  slash:clone(Card.Diamond, 6),
  slash:clone(Card.Diamond, 7),
  slash:clone(Card.Diamond, 8),
  slash:clone(Card.Diamond, 9),
  slash:clone(Card.Diamond, 10),
  slash:clone(Card.Diamond, 13),
})

local jinkSkill = fk.CreateActiveSkill{
  name = "jink_skill",
  can_use = function()
    return false
  end,
  on_effect = function(self, room, effect)
    if effect.responseToEvent then
      effect.responseToEvent.isCancellOut = true
    end
  end
}
local jink = fk.CreateBasicCard{
  name = "jink",
  suit = Card.Heart,
  number = 2,
  skill = jinkSkill,
}
Fk:loadTranslationTable{
  ["jink"] = "闪",
}

extension:addCards({
  jink,
  jink:clone(Card.Heart, 2),
  jink:clone(Card.Heart, 13),

  jink:clone(Card.Diamond, 2),
  jink:clone(Card.Diamond, 2),
  jink:clone(Card.Diamond, 3),
  jink:clone(Card.Diamond, 4),
  jink:clone(Card.Diamond, 5),
  jink:clone(Card.Diamond, 6),
  jink:clone(Card.Diamond, 7),
  jink:clone(Card.Diamond, 8),
  jink:clone(Card.Diamond, 9),
  jink:clone(Card.Diamond, 10),
  jink:clone(Card.Diamond, 11),
  jink:clone(Card.Diamond, 11),
})

local peachSkill = fk.CreateActiveSkill{
  name = "peach_skill",
  can_use = function(self, player)
    return player:isWounded()
  end,
  on_use = function(self, room, use)
    if not use.tos or #TargetGroup:getRealTargets(use.tos) == 0 then
      use.tos = { { use.from } }
    end
  end,
  on_effect = function(self, room, effect)
    local to = effect.to
    local from = effect.from

    room:recover({
      who = room:getPlayerById(to),
      num = 1,
      recoverBy = from,
      skillName = self.name
    })
  end
}
local peach = fk.CreateBasicCard{
  name = "peach",
  suit = Card.Heart,
  number = 3,
  skill = peachSkill,
}
Fk:loadTranslationTable{
  ["peach"] = "桃",
}

extension:addCards({
  peach,
  peach:clone(Card.Heart, 4),
  peach:clone(Card.Heart, 6),
  peach:clone(Card.Heart, 7),
  peach:clone(Card.Heart, 8),
  peach:clone(Card.Heart, 9),
  peach:clone(Card.Heart, 12),
  peach:clone(Card.Heart, 12),
})

local dismantlementSkill = fk.CreateActiveSkill{
  name = "dismantlement_skill",
  target_num = 1,
  target_filter = function(self, to_select, selected)
    if #selected < self:getMaxTargetNum(Self) then
      local player = Fk:currentRoom():getPlayerById(to_select)
      return Self ~= player and not player:isAllNude()
    end
  end,
  on_effect = function(self, room, effect)
    local to = room:getPlayerById(effect.to)
    if to:isAllNude() then return end
    local from = room:getPlayerById(effect.from)
    local cid = room:askForCardChosen(
      from,
      to,
      "hej",
      self.name
    )

    room:throwCard(cid, self.name, to, from)
  end
}
local dismantlement = fk.CreateTrickCard{
  name = "dismantlement",
  suit = Card.Spade,
  number = 3,
  skill = dismantlementSkill,
}
Fk:loadTranslationTable{
  ["dismantlement"] = "过河拆桥",
  ["dismantlement_skill"] = "过河拆桥",
}

extension:addCards({
  dismantlement,
  dismantlement:clone(Card.Spade, 4),
  dismantlement:clone(Card.Spade, 12),

  dismantlement:clone(Card.Club, 3),
  dismantlement:clone(Card.Club, 4),

  dismantlement:clone(Card.Heart, 12),
})

local snatchSkill = fk.CreateActiveSkill{
  name = "snatch_skill",
  distance_limit = 1,
  target_filter = function(self, to_select, selected)
    if #selected == 0 then
      local player = Fk:currentRoom():getPlayerById(to_select)
      return Self ~= player and Self:distanceTo(player) <= self:getDistanceLimit(Self)
        and not player:isAllNude()
    end
  end,
  target_num = 1,
  on_effect = function(self, room, effect)
    local to = effect.to
    local from = effect.from
    local cid = room:askForCardChosen(
      room:getPlayerById(from),
      room:getPlayerById(to),
      "hej",
      self.name
    )

    room:obtainCard(from, cid)
  end
}
local snatch = fk.CreateTrickCard{
  name = "snatch",
  suit = Card.Spade,
  number = 3,
  skill = snatchSkill,
}
Fk:loadTranslationTable{
  ["snatch"] = "顺手牵羊",
  ["snatch_skill"] = "顺手牵羊",
}

extension:addCards({
  snatch,
  snatch:clone(Card.Spade, 4),
  snatch:clone(Card.Spade, 11),

  snatch:clone(Card.Diamond, 3),
  snatch:clone(Card.Diamond, 4),
})

local duelSkill = fk.CreateActiveSkill{
  name = "duel_skill",
  target_filter = function(self, to_select, selected)
    if #selected == 0 then
      local player = Fk:currentRoom():getPlayerById(to_select)
      return Self ~= player
    end
  end,
  target_num = 1,
  on_effect = function(self, room, effect)
    local to = room:getPlayerById(effect.to)
    local from = room:getPlayerById(effect.from)
    local responsers = { to, from }
    local currentTurn = 1
    local currentResponser = to

    while currentResponser:isAlive() do
      if effect.disresponsive or table.contains(effect.disresponsiveList or {}, currentResponser.id) then
        break
      end

      local cardResponded = room:askForResponse(currentResponser, 'slash')
      if cardResponded then
        room:responseCard({
          from = currentResponser.id,
          card = cardResponded,
          responseToEvent = effect,
        })
      else
        break
      end

      currentTurn = currentTurn % 2 + 1
      currentResponser = responsers[currentTurn]
    end

    if currentResponser:isAlive() then
      room:damage({
        from = responsers[currentTurn % 2 + 1],
        to = currentResponser,
        card = effect.card,
        damage = 1 + (effect.addtionalDamage or 0),
        damageType = fk.NormalDamage,
        skillName = self.name,
      })
    end
  end
}
local duel = fk.CreateTrickCard{
  name = "duel",
  suit = Card.Spade,
  number = 1,
  skill = duelSkill,
}
Fk:loadTranslationTable{
  ["duel"] = "决斗",
}

extension:addCards({
  duel,

  duel:clone(Card.Club, 1),

  duel:clone(Card.Diamond, 1),
})

local collateralSkill = fk.CreateActiveSkill{
  name = "collateral_skill",
  target_filter = function(self, to_select, selected)
    local player = Fk:currentRoom():getPlayerById(to_select)
    if #selected == 0 then
      return Self ~= player and player:getEquipment(Card.SubtypeWeapon)
    elseif #selected == 1 then
      return Fk:currentRoom():getPlayerById(selected[1]):inMyAttackRange(player)
    end
  end,
  target_num = 2,
  on_use = function(self, room, cardUseEvent)
    cardUseEvent.tos = { { cardUseEvent.tos[1][1], cardUseEvent.tos[2][1] } }
  end,
  on_effect = function(self, room, effect)
    local use = room:askForUseCard(
      room:getPlayerById(effect.to),
      "slash", nil, nil, nil, { must_targets = effect.subTargets }
    )

    if use then
      room:useCard(use)
    else
      room:obtainCard(effect.from, room:getPlayerById(effect.to):getEquipment(Card.SubtypeWeapon), true, fk.ReasonGive)
    end
  end
}
local collateral = fk.CreateTrickCard{
  name = "collateral",
  suit = Card.Club,
  number = 12,
  skill = collateralSkill,
}
Fk:loadTranslationTable{
  ["collateral"] = "借刀杀人",
}

extension:addCards({
  collateral,
  collateral:clone(Card.Club, 13),
})

local exNihiloSkill = fk.CreateActiveSkill{
  name = "ex_nihilo_skill",
  on_use = function(self, room, cardUseEvent)
    if not cardUseEvent.tos or #TargetGroup:getRealTargets(cardUseEvent.tos) == 0 then
      cardUseEvent.tos = { { cardUseEvent.from } }
    end
  end,
  on_effect = function(self, room, cardEffectEvent)
    room:drawCards(room:getPlayerById(cardEffectEvent.to), 2, "ex_nihilo")
  end
}
local exNihilo = fk.CreateTrickCard{
  name = "ex_nihilo",
  suit = Card.Heart,
  number = 7,
  skill = exNihiloSkill,
}
Fk:loadTranslationTable{
  ["ex_nihilo"] = "无中生有",
}

extension:addCards({
  exNihilo,
  exNihilo:clone(Card.Heart, 8),
  exNihilo:clone(Card.Heart, 9),
  exNihilo:clone(Card.Heart, 11),
})

local nullificationSkill = fk.CreateActiveSkill{
  name = "nullification_skill",
  can_use = function()
    return false
  end,
  on_effect = function(self, room, effect)
    if effect.responseToEvent then
      effect.responseToEvent.isCancellOut = true
    end
  end
}
local nullification = fk.CreateTrickCard{
  name = "nullification",
  suit = Card.Spade,
  number = 11,
  skill = nullificationSkill,
}
Fk:loadTranslationTable{
  ["nullification"] = "无懈可击",
}

extension:addCards({
  nullification,

  nullification:clone(Card.Club, 12),
  nullification:clone(Card.Club, 13),

  nullification:clone(Card.Diamond, 12),
})

local savageAssaultSkill = fk.CreateActiveSkill{
  name = "savage_assault_skill",
  on_use = function(self, room, cardUseEvent)
    if not cardUseEvent.tos or #TargetGroup:getRealTargets(cardUseEvent.tos) == 0 then
      cardUseEvent.tos = {}
      for _, player in ipairs(room:getOtherPlayers(room:getPlayerById(cardUseEvent.from))) do
        TargetGroup:pushTargets(cardUseEvent.tos, player.id)
      end
    end
  end,
  on_effect = function(self, room, effect)
    local cardResponded = nil
    if not (effect.disresponsive or table.contains(effect.disresponsiveList or {}, effect.to)) then
      cardResponded = room:askForResponse(room:getPlayerById(effect.to), 'slash')
    end

    if cardResponded then
      room:responseCard({
        from = effect.to,
        card = cardResponded,
        responseToEvent = effect,
      })
    else
      room:damage({
        from = room:getPlayerById(effect.from),
        to = room:getPlayerById(effect.to),
        card = effect.card,
        damage = 1 + (effect.addtionalDamage or 0),
        damageType = fk.NormalDamage,
        skillName = self.name,
      })
    end
  end
}
local savageAssault = fk.CreateTrickCard{
  name = "savage_assault",
  suit = Card.Spade,
  number = 7,
  skill = savageAssaultSkill,
}
Fk:loadTranslationTable{
  ["savage_assault"] = "南蛮入侵",
}

extension:addCards({
  savageAssault,
  savageAssault:clone(Card.Spade, 13),
  savageAssault:clone(Card.Club, 7),
})

local archeryAttackSkill = fk.CreateActiveSkill{
  name = "archery_attack_skill",
  on_use = function(self, room, cardUseEvent)
    if not cardUseEvent.tos or #TargetGroup:getRealTargets(cardUseEvent.tos) == 0 then
      cardUseEvent.tos = {}
      for _, player in ipairs(room:getOtherPlayers(room:getPlayerById(cardUseEvent.from))) do
        TargetGroup:pushTargets(cardUseEvent.tos, player.id)
      end
    end
  end,
  on_effect = function(self, room, effect)
    local cardResponded = nil
    if not (effect.disresponsive or table.contains(effect.disresponsiveList or {}, effect.to)) then
      cardResponded = room:askForResponse(room:getPlayerById(effect.to), 'jink')
    end

    if cardResponded then
      room:responseCard({
        from = effect.to,
        card = cardResponded,
        responseToEvent = effect,
      })
    else
      room:damage({
        from = room:getPlayerById(effect.from),
        to = room:getPlayerById(effect.to),
        card = effect.card,
        damage = 1 + (effect.addtionalDamage or 0),
        damageType = fk.NormalDamage,
        skillName = self.name,
      })
    end
  end
}
local archeryAttack = fk.CreateTrickCard{
  name = "archery_attack",
  suit = Card.Heart,
  number = 1,
  skill = archeryAttackSkill,
}
Fk:loadTranslationTable{
  ["archery_attack"] = "万箭齐发",
}

extension:addCards({
  archeryAttack,
})

local godSalvationSkill = fk.CreateActiveSkill{
  name = "god_salvation_skill",
  on_use = function(self, room, cardUseEvent)
    if not cardUseEvent.tos or #TargetGroup:getRealTargets(cardUseEvent.tos) == 0 then
      cardUseEvent.tos = {}
      for _, player in ipairs(room:getAlivePlayers()) do
        TargetGroup:pushTargets(cardUseEvent.tos, player.id)
      end
    end
  end,
  about_to_effect = function(self, room, effect)
    if not room:getPlayerById(effect.to):isWounded() then
      return true
    end
  end,
  on_effect = function(self, room, effect)
    room:recover({
      who = room:getPlayerById(effect.to),
      num = 1,
      skillName = self.name,
    })
  end
}
local godSalvation = fk.CreateTrickCard{
  name = "god_salvation",
  suit = Card.Heart,
  number = 1,
  skill = godSalvationSkill,
}
Fk:loadTranslationTable{
  ["god_salvation"] = "桃园结义",
}

extension:addCards({
  godSalvation,
})

local amazingGraceSkill = fk.CreateActiveSkill{
  name = "amazing_grace_skill",
  on_use = function(self, room, cardUseEvent)
    if not cardUseEvent.tos or #TargetGroup:getRealTargets(cardUseEvent.tos) == 0 then
      cardUseEvent.tos = {}
      for _, player in ipairs(room:getAlivePlayers()) do
        TargetGroup:pushTargets(cardUseEvent.tos, player.id)
      end
    end
  end,
  on_effect = function(self, room, cardEffectEvent)
    room:getPlayerById(cardEffectEvent.to):drawCards(1, 'god_salvation')
  end
}
local amazingGrace = fk.CreateTrickCard{
  name = "amazing_grace",
  suit = Card.Heart,
  number = 3,
  skill = amazingGraceSkill,
}
Fk:loadTranslationTable{
  ["amazing_grace"] = "五谷丰登",
}

extension:addCards({
  amazingGrace,
  amazingGrace:clone(Card.Heart, 4),
})

local lightningSkill = fk.CreateActiveSkill{
  name = "lightning_skill",
  can_use = function(self, player)
    return not Self:hasDelayedTrick("lightning")
  end,
  on_use = function(self, room, use)
    if not use.tos or #TargetGroup:getRealTargets(use.tos) == 0 then
      use.tos = { { use.from } }
    end
  end,
  on_effect = function(self, room, effect)
    local to = room:getPlayerById(effect.to)
    local judge = {
      who = to,
      reason = "lightning",
      pattern = ".|2~9|spade",
    }
    room:judge(judge)
    local result = judge.card
    if result.suit == Card.Spade and result.number >= 2 and result.number <= 9 then
      room:damage{
        to = to,
        damage = 3,
        card = effect.card,
        damageType = fk.ThunderDamage,
        skillName = self.name,
      }

      room:moveCards{
        ids = { effect.cardId },
        toArea = Card.DiscardPile,
        moveReason = fk.ReasonPutIntoDiscardPile
      }
    else
      self:onNullified(room, effect)
    end
  end,
  on_nullified = function(self, room, effect)
    local to = room:getPlayerById(effect.to)
    local nextp = to:getNextAlive()
    room:moveCards{
      ids = room:getSubcardsByRule(effect.card, { Card.Processing }),
      to = nextp.id,
      toArea = Card.PlayerJudge,
      moveReason = fk.ReasonPut
    }
  end,
}
local lightning = fk.CreateDelayedTrickCard{
  name = "lightning",
  suit = Card.Spade,
  number = 1,
  skill = lightningSkill,
}
Fk:loadTranslationTable{
  ["lightning"] = "闪电",
}

extension:addCards({
  lightning,
  lightning:clone(Card.Heart, 12),
})

local indulgenceSkill = fk.CreateActiveSkill{
  name = "indulgence_skill",
  target_filter = function(self, to_select, selected)
    if #selected == 0 then
      local player = Fk:currentRoom():getPlayerById(to_select)
      if Self ~= player then
        return not player:hasDelayedTrick("indulgence")
      end
    end
    return false
  end,
  target_num = 1,
  on_effect = function(self, room, effect)
    local to = room:getPlayerById(effect.to)
    local judge = {
      who = to,
      reason = "indulgence",
      pattern = ".|.|spade,club,diamond",
    }
    room:judge(judge)
    local result = judge.card
    if result.suit ~= Card.Heart then
      to:skip(Player.Play)
    end
    self:onNullified(room, effect)
  end,
  on_nullified = function(self, room, effect)
    room:moveCards{
      ids = room:getSubcardsByRule(effect.card, { Card.Processing }),
      toArea = Card.DiscardPile,
      moveReason = fk.ReasonPutIntoDiscardPile
    }
  end,
}
local indulgence = fk.CreateDelayedTrickCard{
  name = "indulgence",
  suit = Card.Spade,
  number = 6,
  skill = indulgenceSkill,
}
Fk:loadTranslationTable{
  ["indulgence"] = "乐不思蜀",
}

extension:addCards({
  indulgence,
  indulgence:clone(Card.Club, 6),
  indulgence:clone(Card.Heart, 6),
})

local crossbowAudio = fk.CreateTriggerSkill{
  name = "#crossbowAudio",
  refresh_events = {fk.CardUsing},
  can_refresh = function(self, event, target, player, data)
    return target == player and player:hasSkill(self.name) and
      data.card.name == "slash" and
      player:usedCardTimes("slash") > 1
  end,
  on_refresh = function(self, event, target, player, data)
    local room = player.room
    room:broadcastPlaySound("./packages/standard_cards/audio/card/crossbow")
    room:setEmotion(player, "./packages/standard_cards/image/anim/crossbow")
  end,
}
local crossbowSkill = fk.CreateTargetModSkill{
  name = "#crossbow_skill",
  attached_equip = "crossbow",
  residue_func = function(self, player, skill, scope)
    if player:hasSkill(self.name) and skill.name == "slash_skill"
      and scope == Player.HistoryPhase then
      return 999
    end
  end,
}
crossbowSkill:addRelatedSkill(crossbowAudio)
Fk:addSkill(crossbowSkill)

local crossbow = fk.CreateWeapon{
  name = "crossbow",
  suit = Card.Club,
  number = 1,
  attack_range = 1,
  equip_skill = crossbowSkill,
}
Fk:loadTranslationTable{
  ["crossbow"] = "诸葛连弩",
}

extension:addCards({
  crossbow,
  crossbow:clone(Card.Diamond, 1),
})

local qingGang = fk.CreateWeapon{
  name = "qinggang_sword",
  suit = Card.Spade,
  number = 6,
  attack_range = 2,
}
Fk:loadTranslationTable{
  ["qinggang_sword"] = "青釭剑",
}

extension:addCards({
  qingGang,
})

local iceSwordSkill = fk.CreateTriggerSkill{
  name = "#ice_sword_skill",
  attached_equip = "ice_sword",
  events = {fk.DamageCaused},
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(self.name) and
      data.card and data.card.name == "slash" and not data.to:isNude()
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local to = data.to
    for i = 1, 2 do
      if to:isNude() then break end
      local card = room:askForCardChosen(player, to, "he", self.name)
      room:throwCard(card, self.name, to, player)
    end
    return true
  end
}
Fk:addSkill(iceSwordSkill)

local iceSword = fk.CreateWeapon{
  name = "ice_sword",
  suit = Card.Spade,
  number = 2,
  attack_range = 2,
  equip_skill = iceSwordSkill,
}
Fk:loadTranslationTable{
  ["ice_sword"] = "寒冰剑",
  ["#ice_sword_skill"] = "寒冰剑",
}

extension:addCards({
  iceSword,
})

local doubleSwordsSkill = fk.CreateTriggerSkill{
  name = "#double_swords_skill",
  attached_equip = "double_swords",
  events = {fk.TargetSpecified},
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(self.name) and
      data.card and data.card.name == "slash" and
      (player.room:getPlayerById(data.to).gender ~= player.gender)
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local to = player.room:getPlayerById(data.to)
    local result = room:askForDiscard(to, 1, 1, false, self.name, true)
    if #result == 0 then
      player:drawCards(1, self.name)
    end
  end,
}
Fk:addSkill(doubleSwordsSkill)
local doubleSwords = fk.CreateWeapon{
  name = "double_swords",
  suit = Card.Spade,
  number = 2,
  attack_range = 2,
  equip_skill = doubleSwordsSkill,
}
Fk:loadTranslationTable{
  ["double_swords"] = "雌雄双股剑",
  ["#double_swords_skill"] = "雌雄双股剑",
}

extension:addCards({
  doubleSwords,
})

local bladeSkill = fk.CreateTriggerSkill{
  name = "#blade_skill",
  attached_equip = "blade",
  events = {fk.CardUseFinished},
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(self.name) then return end
    local use = data ---@type CardUseStruct
    if use.card.name == "jink" and use.toCard and use.toCard.name == "slash" then
      local effect = use.responseToEvent
      return effect.from == player.id
    end
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    local use = room:askForUseCard(player, "slash", nil, "#blade_slash:" .. target.id,
      true, { must_targets = {target.id} })
    if use then
      self.cost_data = use
      return true
    end
  end,
  on_use = function(self, event, target, player, data)
    player.room:useCard(self.cost_data)
  end,
}
Fk:addSkill(bladeSkill)
local blade = fk.CreateWeapon{
  name = "blade",
  suit = Card.Spade,
  number = 5,
  attack_range = 3,
  equip_skill = bladeSkill,
}
Fk:loadTranslationTable{
  ["blade"] = "青龙偃月刀",
  ["#blade_skill"] = "青龙偃月刀",
  ["#blade_slash"] = "你可以发动“青龙偃月刀”对 %src 再使用一张杀",
}

extension:addCards({
  blade,
})

local spearSkill = fk.CreateViewAsSkill{
  name = "spear_skill",
  attached_equip = "spear",
  pattern = "slash",
  card_filter = function(self, to_select, selected)
    if #selected == 2 then return false end
    return Fk:currentRoom():getCardArea(to_select) ~= Player.Equip
  end,
  view_as = function(self, cards)
    if #cards ~= 2 then
      return nil
    end
    local c = Fk:cloneCard("slash")
    c:addSubcards(cards)
    return c
  end,
}
Fk:addSkill(spearSkill)
local spear = fk.CreateWeapon{
  name = "spear",
  suit = Card.Spade,
  number = 12,
  attack_range = 3,
  equip_skill = spearSkill,
}
Fk:loadTranslationTable{
  ["spear"] = "丈八蛇矛",
  ["spear_skill"] = "丈八矛",
}

extension:addCards({
  spear,
})

local axeSkill = fk.CreateTriggerSkill{
  name = "#axe_skill",
  attached_equip = "axe",
  events = {fk.CardEffecting},
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(self.name) then return end
    local effect = data ---@type CardEffectEvent
    return effect.card.name == "jink" and effect.responseToEvent and
      effect.responseToEvent.from == player.id and
      effect.toCard.name == "slash"
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    local ret = room:askForDiscard(player, 2, 2, true, self.name, true)
    if #ret > 0 then return true end
  end,
  on_use = function() return true end,
}
Fk:addSkill(axeSkill)
local axe = fk.CreateWeapon{
  name = "axe",
  suit = Card.Diamond,
  number = 5,
  attack_range = 3,
  equip_skill = axeSkill,
}
Fk:loadTranslationTable{
  ["axe"] = "贯石斧",
  ["#axe_skill"] = "贯石斧",
}

extension:addCards({
  axe,
})

local halberdAudio = fk.CreateTriggerSkill{
  name = "#halberdAudio",
  refresh_events = {fk.CardUsing},
  can_refresh = function(self, event, target, player, data)
    return target == player and player:hasSkill(self.name) and
      data.card.name == "slash" and #TargetGroup:getRealTargets(data.tos) > 1
  end,
  on_refresh = function(self, event, target, player, data)
    local room = player.room
    room:broadcastPlaySound("./packages/standard_cards/audio/card/halberd")
    room:setEmotion(player, "./packages/standard_cards/image/anim/halberd")
  end,
}
local halberdSkill = fk.CreateTargetModSkill{
  name = "#halberd_skill",
  attached_equip = "halberd",
  extra_target_func = function(self, player, skill, card)
    if player:hasSkill(self.name) and skill.name == "slash_skill"
      and #player:getCardIds(Player.Hand) == 1
      and player:getCardIds(Player.Hand)[1] == card.id then
      return 2
    end
  end,
}
halberdSkill:addRelatedSkill(halberdAudio)
Fk:addSkill(halberdSkill)
local halberd = fk.CreateWeapon{
  name = "halberd",
  suit = Card.Diamond,
  number = 12,
  attack_range = 4,
  equip_skill = halberdSkill,
}
Fk:loadTranslationTable{
  ["halberd"] = "方天画戟",
}

extension:addCards({
  halberd,
})

local kylinBowSkill = fk.CreateTriggerSkill{
  name = "#kylin_bow_skill",
  attached_equip = "kylin_bow",
  events = {fk.DamageCaused},
  can_trigger = function(self, event, target, player, data)
    local ret = target == player and player:hasSkill(self.name) and
      data.card and data.card.name == "slash"
    if ret then
      ---@type ServerPlayer
      local to = data.to
      return to:getEquipment(Card.SubtypeDefensiveRide) or
        to:getEquipment(Card.SubtypeOffensiveRide)
    end
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local to = data.to
    local ride_tab = {}
    if to:getEquipment(Card.SubtypeDefensiveRide) then
      table.insert(ride_tab, "+1")
    end
    if to:getEquipment(Card.SubtypeOffensiveRide) then
      table.insert(ride_tab, "-1")
    end
    if #ride_tab == 0 then return end
    local choice = room:askForChoice(player, ride_tab, self.name)
    if choice == "+1" then
      room:throwCard(to:getEquipment(Card.SubtypeDefensiveRide), self.name, to, player)
    else
      room:throwCard(to:getEquipment(Card.SubtypeOffensiveRide), self.name, to, player)
    end
  end
}
Fk:addSkill(kylinBowSkill)
local kylinBow = fk.CreateWeapon{
  name = "kylin_bow",
  suit = Card.Heart,
  number = 5,
  attack_range = 5,
  equip_skill = kylinBowSkill,
}
Fk:loadTranslationTable{
  ["kylin_bow"] = "麒麟弓",
  ["#kylin_bow_skill"] = "麒麟弓",
}

extension:addCards({
  kylinBow,
})

local eightDiagram = fk.CreateArmor{
  name = "eight_diagram",
  suit = Card.Spade,
  number = 2,
}
Fk:loadTranslationTable{
  ["eight_diagram"] = "八卦阵",
}

extension:addCards({
  eightDiagram,
  eightDiagram:clone(Card.Club, 2),
})

local niohShieldSkill = fk.CreateTriggerSkill{
  name = "#nioh_shield_skill",
  attached_equip = "nioh_shield",
  frequency = Skill.Compulsory,
  events = {fk.PreCardEffect},
  can_trigger = function(self, event, target, player, data)
    local effect = data ---@type CardEffectEvent
    return player.id == effect.to and player:hasSkill(self.name) and
      effect.card.name == "slash" and effect.card.color == Card.Black
  end,
  on_use = function() return true end,
}
Fk:addSkill(niohShieldSkill)
local niohShield = fk.CreateArmor{
  name = "nioh_shield",
  suit = Card.Club,
  number = 2,
  equip_skill = niohShieldSkill,
}
Fk:loadTranslationTable{
  ["nioh_shield"] = "仁王盾",
}

extension:addCards({
  niohShield,
})

local horseSkill = fk.CreateDistanceSkill{
  name = "horse_skill",
  global = true,
  correct_func = function(self, from, to)
    local ret = 0
    if from:getEquipment(Card.SubtypeOffensiveRide) then
      ret = ret - 1
    end
    if to:getEquipment(Card.SubtypeDefensiveRide) then
      ret = ret + 1
    end
    return ret
  end,
}
if not Fk.skills["horse_skill"] then
  Fk:addSkill(horseSkill)
end

local diLu = fk.CreateDefensiveRide{
  name = "dilu",
  suit = Card.Club,
  number = 5,
}
Fk:loadTranslationTable{
  ["dilu"] = "的卢",
}

extension:addCards({
  diLu,
})

local jueYing = fk.CreateDefensiveRide{
  name = "jueying",
  suit = Card.Spade,
  number = 5,
}
Fk:loadTranslationTable{
  ["jueying"] = "绝影",
}

extension:addCards({
  jueYing,
})

local zhuaHuangFeiDian = fk.CreateDefensiveRide{
  name = "zhuahuangfeidian",
  suit = Card.Heart,
  number = 13,
}
Fk:loadTranslationTable{
  ["zhuahuangfeidian"] = "爪黄飞电",
}

extension:addCards({
  zhuaHuangFeiDian,
})

local chiTu = fk.CreateOffensiveRide{
  name = "chitu",
  suit = Card.Heart,
  number = 5,
}
Fk:loadTranslationTable{
  ["chitu"] = "赤兔",
}

extension:addCards({
  chiTu,
})

local daYuan = fk.CreateOffensiveRide{
  name = "dayuan",
  suit = Card.Spade,
  number = 13,
}
Fk:loadTranslationTable{
  ["dayuan"] = "大宛",
}

extension:addCards({
  daYuan,
})

local ziXing = fk.CreateOffensiveRide{
  name = "zixing",
  suit = Card.Diamond,
  number = 13,
}
Fk:loadTranslationTable{
  ["zixing"] = "紫骍",
}

extension:addCards({
  ziXing,
})

return extension
