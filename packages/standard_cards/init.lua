-- SPDX-License-Identifier: GPL-3.0-or-later

local extension = Package:new("standard_cards", Package.CardPack)
extension.metadata = require "packages.standard_cards.metadata"

local slashSkill = fk.CreateActiveSkill{
  name = "slash_skill",
  prompt = function(self, selected_cards)
    local slash = Fk:cloneCard("slash")
    slash.subcards = Card:getIdList(selected_cards)
    local max_num = self:getMaxTargetNum(Self, slash) -- halberd
    if max_num > 1 then
      local num = #table.filter(Fk:currentRoom().alive_players, function (p)
        return p ~= Self and not Self:isProhibited(p, slash)
      end)
      max_num = math.min(num, max_num)
    end
    slash.subcards = {}
    return max_num > 1 and "#slash_skill_multi:::" .. max_num or "#slash_skill"
  end,
  max_phase_use_time = 1,
  target_num = 1,
  can_use = function(self, player, card, extra_data)
    return (extra_data and extra_data.bypass_times) or player.phase ~= Player.Play or
      table.find(Fk:currentRoom().alive_players, function(p)
        return self:withinTimesLimit(player, Player.HistoryPhase, card, "slash", p)
      end)
  end,
  mod_target_filter = function(self, to_select, selected, user, card, distance_limited)
    local player = Fk:currentRoom():getPlayerById(to_select)
    local from = Fk:currentRoom():getPlayerById(user)
    return from ~= player and not (distance_limited and not self:withinDistanceLimit(from, true, card, player))
  end,
  target_filter = function(self, to_select, selected, _, card, extra_data)
    local count_distances = not (extra_data and extra_data.bypass_distances)
    if #selected < self:getMaxTargetNum(Self, card) then
      local player = Fk:currentRoom():getPlayerById(to_select)
      return self:modTargetFilter(to_select, selected, Self.id, card, count_distances) and
      (
        #selected > 0 or
        Self.phase ~= Player.Play or
        (extra_data and extra_data.bypass_times) or
        self:withinTimesLimit(Self, Player.HistoryPhase, card, "slash", player)
      )
    end
  end,
  on_effect = function(self, room, effect)
    local from = room:getPlayerById(effect.from)
    local to = room:getPlayerById(effect.to)
    if not to.dead then
      room:damage({
        from = from,
        to = to,
        card = effect.card,
        damage = 1,
        damageType = fk.NormalDamage,
        skillName = self.name
      })
    end
  end
}
local slash = fk.CreateBasicCard{
  name = "slash",
  number = 7,
  suit = Card.Spade,
  is_damage_card = true,
  skill = slashSkill,
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
  can_use = Util.FalseFunc,
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
  is_passive = true,
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
  prompt = "#peach_skill",
  mod_target_filter = function(self, to_select)
    return Fk:currentRoom():getPlayerById(to_select):isWounded() and
      not table.find(Fk:currentRoom().alive_players, function(p)
        return p.dying
      end)
  end,
  can_use = function(self, player, card)
    return player:isWounded() and not player:isProhibited(player, card)
  end,
  on_use = function(self, room, use)
    if not use.tos or #TargetGroup:getRealTargets(use.tos) == 0 then
      use.tos = { { use.from } }
    end
  end,
  on_effect = function(self, room, effect)
    local player = room:getPlayerById(effect.from)
    local target = room:getPlayerById(effect.to)
    if target:isWounded() and not target.dead then
      room:recover({
        who = target,
        num = 1,
        card = effect.card,
        recoverBy = player,
        skillName = self.name
      })
    end
  end
}
local peach = fk.CreateBasicCard{
  name = "peach",
  suit = Card.Heart,
  number = 3,
  skill = peachSkill,
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
  prompt = "#dismantlement_skill",
  target_num = 1,
  mod_target_filter = function(self, to_select, selected, user, card)
    local player = Fk:currentRoom():getPlayerById(to_select)
    return user ~= to_select and not player:isAllNude()
  end,
  target_filter = function(self, to_select, selected, _, card)
    if #selected < self:getMaxTargetNum(Self, card) then
      return self:modTargetFilter(to_select, selected, Self.id, card)
    end
  end,
  on_effect = function(self, room, effect)
    local from = room:getPlayerById(effect.from)
    local to = room:getPlayerById(effect.to)
    if from.dead or to.dead or to:isAllNude() then return end
    local cid = room:askForCardChosen(from, to, "hej", self.name)
    room:throwCard({cid}, self.name, to, from)
  end
}
local dismantlement = fk.CreateTrickCard{
  name = "dismantlement",
  suit = Card.Spade,
  number = 3,
  skill = dismantlementSkill,
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
  prompt = "#snatch_skill",
  distance_limit = 1,
  mod_target_filter = function(self, to_select, selected, user, card, distance_limited)
    local player = Fk:currentRoom():getPlayerById(to_select)
    local from = Fk:currentRoom():getPlayerById(user)
    return from ~= player and not (player:isAllNude() or (distance_limited and not self:withinDistanceLimit(from, false, card, player)))
  end,
  target_filter = function(self, to_select, selected, _, card, extra_data)
    local count_distances = not (extra_data and extra_data.bypass_distances)
    if #selected < self:getMaxTargetNum(Self, card) then
      return self:modTargetFilter(to_select, selected, Self.id, card, count_distances)
    end
  end,
  target_num = 1,
  on_effect = function(self, room, effect)
    local from = room:getPlayerById(effect.from)
    local to = room:getPlayerById(effect.to)
    if from.dead or to.dead or to:isAllNude() then return end
    local cid = room:askForCardChosen(from, to, "hej", self.name)
    room:obtainCard(from, cid, false, fk.ReasonPrey)
  end
}
local snatch = fk.CreateTrickCard{
  name = "snatch",
  suit = Card.Spade,
  number = 3,
  skill = snatchSkill,
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
  prompt = "#duel_skill",
  mod_target_filter = function(self, to_select, selected, user, card)
    return user ~= to_select
  end,
  target_filter = function(self, to_select, selected, _, card)
    if #selected < self:getMaxTargetNum(Self, card) then
      return self:modTargetFilter(to_select, selected, Self.id, card)
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
      local loopTimes = 1
      if effect.fixedResponseTimes then
        local canFix = currentResponser == to
        if effect.fixedAddTimesResponsors then
          canFix = table.contains(effect.fixedAddTimesResponsors, currentResponser.id)
        end

        if canFix then
          if type(effect.fixedResponseTimes) == 'table' then
            loopTimes = effect.fixedResponseTimes["slash"] or 1
          elseif type(effect.fixedResponseTimes) == 'number' then
            loopTimes = effect.fixedResponseTimes
          end
        end
      end

      local cardResponded
      for i = 1, loopTimes do
        cardResponded = room:askForResponse(currentResponser, 'slash', nil, nil, true, nil, effect)
        if cardResponded then
          room:responseCard({
            from = currentResponser.id,
            card = cardResponded,
            responseToEvent = effect,
          })
        else
          break
        end
      end

      if not cardResponded then
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
        damage = 1,
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
  is_damage_card = true,
  skill = duelSkill,
}

extension:addCards({
  duel,

  duel:clone(Card.Club, 1),

  duel:clone(Card.Diamond, 1),
})

local collateralSkill = fk.CreateActiveSkill{
  name = "collateral_skill",
  prompt = "#collateral_skill",
  mod_target_filter = function(self, to_select, selected, user, card, distance_limited)
    local player = Fk:currentRoom():getPlayerById(to_select)
    if #selected == 0 then
      return user ~= to_select and player:getEquipment(Card.SubtypeWeapon) and not player:prohibitUse(Fk:cloneCard("slash"))
    elseif #selected == 1 then
      local target = Fk:currentRoom():getPlayerById(to_select)
      local from = Fk:currentRoom():getPlayerById(selected[1])
      return from:inMyAttackRange(target) and not from:isProhibited(player, Fk:cloneCard("slash"))
    end
  end,
  target_filter = function(self, to_select, selected, _, card)
    if #selected >= (self:getMaxTargetNum(Self, card) - 1) * 2 then
      return false--修改借刀的目标选择
    elseif #selected % 2 == 0 then
      return self:modTargetFilter(to_select, {}, Self.id, card)
    else
      return self:modTargetFilter(selected[#selected], {}, Self.id, card)
      and self:modTargetFilter(to_select, {selected[#selected]}, Self.id, card)
    end
  end,
  target_num = 2,
  on_use = function(self, room, cardUseEvent)
    local tos = {}
    local exclusive = {}
    for i, pid in ipairs(TargetGroup:getRealTargets(cardUseEvent.tos)) do
      if i % 2 == 1 then
        exclusive = { pid }
      else
        table.insert(exclusive, pid)
        table.insert(tos, exclusive)
      end
    end
    cardUseEvent.tos = tos
  end,
  on_effect = function(self, room, effect)
    local to = room:getPlayerById(effect.to)
    if to.dead then return end
    local prompt = "#collateral-slash:"..effect.from..":"..effect.subTargets[1]
    if #effect.subTargets > 1 then
      prompt = nil
    end
    local extra_data = {
      must_targets = effect.subTargets,
      bypass_times = true,
    }
    local use = room:askForUseCard(to, "slash", nil, prompt, nil, extra_data, effect)
    if use then
      use.extraUse = true
      room:useCard(use)
    else
      local from = room:getPlayerById(effect.from)
      if from.dead then return end
      local weapons = to:getEquipments(Card.SubtypeWeapon)
      if #weapons > 0 then
        room:moveCardTo(weapons, Card.PlayerHand, from, fk.ReasonGive, "collateral", nil, true, to.id)
      end
    end
  end
}
local collateral = fk.CreateTrickCard{
  name = "collateral",
  suit = Card.Club,
  number = 12,
  skill = collateralSkill,
}

extension:addCards({
  collateral,
  collateral:clone(Card.Club, 13),
})

local exNihiloSkill = fk.CreateActiveSkill{
  name = "ex_nihilo_skill",
  prompt = "#ex_nihilo_skill",
  mod_target_filter = Util.TrueFunc,
  can_use = function(self, player, card)
    return not player:isProhibited(player, card)
  end,
  on_use = function(self, room, cardUseEvent)
    if not cardUseEvent.tos or #TargetGroup:getRealTargets(cardUseEvent.tos) == 0 then
      cardUseEvent.tos = { { cardUseEvent.from } }
    end
  end,
  on_effect = function(self, room, effect)
    local target = room:getPlayerById(effect.to)
    if target.dead then return end
    target:drawCards(2, "ex_nihilo")
  end
}
local exNihilo = fk.CreateTrickCard{
  name = "ex_nihilo",
  suit = Card.Heart,
  number = 7,
  skill = exNihiloSkill,
}

extension:addCards({
  exNihilo,
  exNihilo:clone(Card.Heart, 8),
  exNihilo:clone(Card.Heart, 9),
  exNihilo:clone(Card.Heart, 11),
})

local nullificationSkill = fk.CreateActiveSkill{
  name = "nullification_skill",
  can_use = Util.FalseFunc,
  on_use = function() RoomInstance:delay(1200) end,
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
  is_passive = true,
}

extension:addCards({
  nullification,

  nullification:clone(Card.Club, 12),
  nullification:clone(Card.Club, 13),

  nullification:clone(Card.Diamond, 12),
})

local savageAssaultSkill = fk.CreateActiveSkill{
  name = "savage_assault_skill",
  prompt = "#savage_assault_skill",
  can_use = Util.AoeCanUse,
  on_use = Util.AoeOnUse,
  mod_target_filter = function(self, to_select, selected, user, card, distance_limited)
    return user ~= to_select
  end,
  on_effect = function(self, room, effect)
    local cardResponded = room:askForResponse(room:getPlayerById(effect.to), 'slash', nil, nil, true, nil, effect)

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
        damage = 1,
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
  is_damage_card = true,
  multiple_targets = true,
  skill = savageAssaultSkill,
}

extension:addCards({
  savageAssault,
  savageAssault:clone(Card.Spade, 13),
  savageAssault:clone(Card.Club, 7),
})

local archeryAttackSkill = fk.CreateActiveSkill{
  name = "archery_attack_skill",
  prompt = "#archery_attack_skill",
  can_use = Util.AoeCanUse,
  on_use = Util.AoeOnUse,
  mod_target_filter = function(self, to_select, selected, user, card, distance_limited)
    return user ~= to_select
  end,
  on_effect = function(self, room, effect)
    local cardResponded = room:askForResponse(room:getPlayerById(effect.to), 'jink', nil, nil, true, nil, effect)

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
        damage = 1,
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
  is_damage_card = true,
  multiple_targets = true,
  skill = archeryAttackSkill,
}

extension:addCards({
  archeryAttack,
})

local godSalvationSkill = fk.CreateActiveSkill{
  name = "god_salvation_skill",
  prompt = "#god_salvation_skill",
  can_use = Util.GlobalCanUse,
  on_use = Util.GlobalOnUse,
  mod_target_filter = Util.TrueFunc,
  about_to_effect = function(self, room, effect)
    if not room:getPlayerById(effect.to):isWounded() then
      return true
    end
  end,
  on_effect = function(self, room, effect)
    local player = room:getPlayerById(effect.from)
    local target = room:getPlayerById(effect.to)
    if target:isWounded() and not target.dead then
      room:recover({
        who = target,
        num = 1,
        recoverBy = player,
        card = effect.card,
        skillName = self.name,
      })
    end
  end
}
local godSalvation = fk.CreateTrickCard{
  name = "god_salvation",
  suit = Card.Heart,
  number = 1,
  multiple_targets = true,
  skill = godSalvationSkill,
}

extension:addCards({
  godSalvation,
})

local amazingGraceSkill = fk.CreateActiveSkill{
  name = "amazing_grace_skill",
  prompt = "#amazing_grace_skill",
  can_use = Util.GlobalCanUse,
  on_use = Util.GlobalOnUse,
  mod_target_filter = Util.TrueFunc,
  on_action = function(self, room, use, finished)
    if not finished then
      local toDisplay = room:getNCards(#TargetGroup:getRealTargets(use.tos))
      room:moveCards({
        ids = toDisplay,
        toArea = Card.Processing,
        moveReason = fk.ReasonPut,
        proposer = use.from,
      })

      table.forEach(room.players, function(p)
        room:fillAG(p, toDisplay)
      end)

      use.extra_data = use.extra_data or {}
      use.extra_data.AGFilled = toDisplay
      use.extra_data.AGResult = {}
    else
      if use.extra_data and use.extra_data.AGFilled then
        table.forEach(room.players, function(p)
          room:closeAG(p)
        end)

        local toDiscard = table.filter(use.extra_data.AGFilled, function(id)
          return room:getCardArea(id) == Card.Processing
        end)

        if #toDiscard > 0 then
          room:moveCards({
            ids = toDiscard,
            toArea = Card.DiscardPile,
            moveReason = fk.ReasonPutIntoDiscardPile,
          })
        end
      end

      use.extra_data.AGFilled = nil
    end
  end,
  on_effect = function(self, room, effect)
    local to = room:getPlayerById(effect.to)
    if not (effect.extra_data and effect.extra_data.AGFilled) then
      return
    end

    local chosen = room:askForAG(to, effect.extra_data.AGFilled, false, self.name)
    room:takeAG(to, chosen, room.players)
    table.insert(effect.extra_data.AGResult, {effect.to, chosen})
    room:moveCardTo(chosen, Card.PlayerHand, effect.to, fk.ReasonPrey, self.name, nil, true, effect.to)
    table.removeOne(effect.extra_data.AGFilled, chosen)
  end
}

local amazingGrace = fk.CreateTrickCard{
  name = "amazing_grace",
  suit = Card.Heart,
  number = 3,
  multiple_targets = true,
  skill = amazingGraceSkill,
}

extension:addCards({
  amazingGrace,
  amazingGrace:clone(Card.Heart, 4),
})

local lightningSkill = fk.CreateActiveSkill{
  name = "lightning_skill",
  prompt = "#lightning_skill",
  mod_target_filter = Util.TrueFunc,
  can_use = function(self, player, card)
    return not player:isProhibited(player, card)
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
        -- damageType = fk.ThunderDamage,
        damageType = Fk:getDamageNature(fk.ThunderDamage) and fk.ThunderDamage or fk.NormalDamage,
        skillName = self.name,
      }

      room:moveCards{
        ids = Card:getIdList(effect.card),
        toArea = Card.DiscardPile,
        moveReason = fk.ReasonUse
      }
    else
      self:onNullified(room, effect)
    end
  end,
  on_nullified = function(self, room, effect)
    local to = room:getPlayerById(effect.to)
    local nextp = to
    repeat
      nextp = nextp:getNextAlive(true)
      if nextp == to then
        if nextp:isProhibited(nextp, effect.card) then
          room:moveCards{
            ids = room:getSubcardsByRule(effect.card, { Card.Processing }),
            toArea = Card.DiscardPile,
            moveReason = fk.ReasonPut
          }
          return
        end
        break
      end
    until not nextp:hasDelayedTrick("lightning") and not nextp:isProhibited(nextp, effect.card)


    if effect.card:isVirtual() then
      nextp:addVirtualEquip(effect.card)
    end

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

extension:addCards({
  lightning,
  lightning:clone(Card.Heart, 12),
})

local indulgenceSkill = fk.CreateActiveSkill{
  name = "indulgence_skill",
  prompt = "#indulgence_skill",
  mod_target_filter = function(self, to_select, selected, user, card, distance_limited)
    return user ~= to_select
  end,
  target_filter = function(self, to_select, selected, _, card)
    return #selected == 0 and self:modTargetFilter(to_select, selected, Self.id, card, true)
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
      moveReason = fk.ReasonUse
    }
  end,
}
local indulgence = fk.CreateDelayedTrickCard{
  name = "indulgence",
  suit = Card.Spade,
  number = 6,
  skill = indulgenceSkill,
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
    return target == player and player:hasSkill(self) and player.phase == Player.Play and
      data.card.trueName == "slash" and player:usedCardTimes("slash", Player.HistoryPhase) > 1
  end,
  on_refresh = function(self, event, target, player, data)
    local room = player.room
    room:broadcastPlaySound("./packages/standard_cards/audio/card/crossbow")
    room:setEmotion(player, "./packages/standard_cards/image/anim/crossbow")
    room:sendLog{
      type = "#InvokeSkill",
      from = player.id,
      arg = "crossbow",
    }
  end,
}
local crossbowSkill = fk.CreateTargetModSkill{
  name = "#crossbow_skill",
  attached_equip = "crossbow",
  bypass_times = function(self, player, skill, scope, card)
    if player:hasSkill(self) and skill.trueName == "slash_skill" and scope == Player.HistoryPhase then
      --FIXME: 无法检测到非转化的cost选牌的情况，如活墨等
      local cardIds = Card:getIdList(card)
      local crossbows = table.filter(player:getEquipments(Card.SubtypeWeapon), function(id)
        return Fk:getCardById(id).equip_skill == self
      end)
      return #crossbows == 0 or not table.every(crossbows, function(id)
        return table.contains(cardIds, id)
      end)
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

extension:addCards({
  crossbow,
  crossbow:clone(Card.Diamond, 1),
})

fk.MarkArmorNullified = "mark__armor_nullified"

local armorInvalidity = fk.CreateInvaliditySkill {
  name = "armor_invalidity",
  global = true,
  invalidity_func = function(self, from, skill)
    if from:getMark(fk.MarkArmorNullified) > 0 and skill.attached_equip then
      for _, card in ipairs(Fk.cards) do
        if card.sub_type == Card.SubtypeArmor and skill.attached_equip == card.name then
          return true
        end
      end
    end
  end
}
Fk:addSkill(armorInvalidity)

local qingGangSkill = fk.CreateTriggerSkill{
  name = "#qinggang_sword_skill",
  attached_equip = "qinggang_sword",
  frequency = Skill.Compulsory,
  events = { fk.TargetSpecified },
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(self) and
      data.card and data.card.trueName == "slash"
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local to = room:getPlayerById(data.to)
    local use_event = room.logic:getCurrentEvent():findParent(GameEvent.UseCard, true)
    if use_event == nil then return end
    room:addPlayerMark(to, fk.MarkArmorNullified)
    use_event:addCleaner(function()
      room:removePlayerMark(to, fk.MarkArmorNullified)
    end)
  end,
}
Fk:addSkill(qingGangSkill)

local qingGang = fk.CreateWeapon{
  name = "qinggang_sword",
  suit = Card.Spade,
  number = 6,
  attack_range = 2,
  equip_skill = qingGangSkill,
}

extension:addCards({
  qingGang,
})

local iceSwordSkill = fk.CreateTriggerSkill{
  name = "#ice_sword_skill",
  attached_equip = "ice_sword",
  events = {fk.DamageCaused},
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(self) and (not data.chain) and
      data.card and data.card.trueName == "slash" and not data.to:isNude()
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local to = data.to
    for i = 1, 2 do
      if player.dead or to.dead or to:isNude() then break end
      local card = room:askForCardChosen(player, to, "he", self.name)
      room:throwCard({card}, self.name, to, player)
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

extension:addCards({
  iceSword,
})

local doubleSwordsSkill = fk.CreateTriggerSkill{
  name = "#double_swords_skill",
  attached_equip = "double_swords",
  events = {fk.TargetSpecified},
  can_trigger = function(self, event, target, player, data)
    if target == player and player:hasSkill(self) and
      data.card and data.card.trueName == "slash" then
      local target = player.room:getPlayerById(data.to)
      return player:compareGenderWith(target, true)
    end
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local to = player.room:getPlayerById(data.to)
    if to:isKongcheng() then
      player:drawCards(1, self.name)
    else
      local result = room:askForDiscard(to, 1, 1, false, self.name, true, ".", "#double_swords-invoke:"..player.id)
      if #result == 0 then
        player:drawCards(1, self.name)
      end
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

extension:addCards({
  doubleSwords,
})

local bladeSkill = fk.CreateTriggerSkill{
  name = "#blade_skill",
  attached_equip = "blade",
  events = {fk.CardEffectCancelledOut},
  can_trigger = function(self, event, target, player, data)
    return player:hasSkill(self) and data.from == player.id and data.card.trueName == "slash" and not player.room:getPlayerById(data.to).dead
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    local use = room:askForUseCard(player, "slash", nil, "#blade_slash:" .. data.to,
      true, { must_targets = {data.to}, exclusive_targets = {data.to}, bypass_distances = true, bypass_times = true })
    if use then
      use.extraUse = true
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

extension:addCards({
  blade,
})

local spearSkill = fk.CreateViewAsSkill{
  name = "spear_skill",
  prompt = "#spear_skill",
  attached_equip = "spear",
  pattern = "slash",
  card_filter = function(self, to_select, selected)
    if #selected == 2 then return false end
    return table.contains(Self:getHandlyIds(true), to_select)
  end,
  view_as = function(self, cards)
    if #cards ~= 2 then
      return nil
    end
    local c = Fk:cloneCard("slash")
    c.skillName = "spear"
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

extension:addCards({
  spear,
})

local axeSkill = fk.CreateTriggerSkill{
  name = "#axe_skill",
  attached_equip = "axe",
  events = {fk.CardEffectCancelledOut},
  can_trigger = function(self, event, target, player, data)
    return player:hasSkill(self) and data.from == player.id and data.card.trueName == "slash" and
      not player.room:getPlayerById(data.to).dead
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    local cards = {}
    for _, id in ipairs(player:getCardIds("he")) do
      if not player:prohibitDiscard(id) and
        not (table.contains(player:getEquipments(Card.SubtypeWeapon), id) and Fk:getCardById(id).name == "axe") then
        table.insert(cards, id)
      end
    end
    cards = room:askForDiscard(player, 2, 2, true, self.name, true, ".|.|.|.|.|.|"..table.concat(cards, ","),
      "#axe-invoke::"..data.to, true)
    if #cards > 0 then
      self.cost_data = cards
      return true
    end
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    room:throwCard(self.cost_data, "axe", player, player)
    return true
  end,
}
Fk:addSkill(axeSkill)
local axe = fk.CreateWeapon{
  name = "axe",
  suit = Card.Diamond,
  number = 5,
  attack_range = 3,
  equip_skill = axeSkill,
}

extension:addCards({
  axe,
})

local halberdAudio = fk.CreateTriggerSkill{
  name = "#halberdAudio",
  refresh_events = {fk.CardUsing},
  can_refresh = function(self, event, target, player, data)
    return target == player and player:hasSkill(self) and
      data.card.trueName == "slash" and #TargetGroup:getRealTargets(data.tos) > 1
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
    if player:hasSkill(self) and skill.trueName == "slash_skill" then
      local cards = card:isVirtual() and card.subcards or {card.id}
      local handcards = player:getCardIds(Player.Hand)
      if #handcards > 0 and #cards == #handcards and table.every(cards, function(id) return table.contains(handcards, id) end) then
        return 2
      end
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

extension:addCards({
  halberd,
})

local kylinBowSkill = fk.CreateTriggerSkill{
  name = "#kylin_bow_skill",
  attached_equip = "kylin_bow",
  events = {fk.DamageCaused},
  can_trigger = function(self, event, target, player, data)
    local ret = target == player and player:hasSkill(self) and
      data.card and data.card.trueName == "slash" and (not data.chain)
    if ret then
      ---@type ServerPlayer
      local to = data.to
      return table.find(to:getCardIds(Player.Equip), function (id)
        local card = Fk:getCardById(id)
        return card.sub_type == Card.SubtypeDefensiveRide or card.sub_type == Card.SubtypeOffensiveRide
      end)
    end
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local to = data.to
    local ride_tab = table.filter(to:getCardIds(Player.Equip), function (id)
      local card = Fk:getCardById(id)
      return card.sub_type == Card.SubtypeDefensiveRide or card.sub_type == Card.SubtypeOffensiveRide
    end)
    if #ride_tab == 0 then return end
    local id = room:askForCardChosen(player, to, {
      card_data = {
        { "equip_horse", ride_tab }
      }
    }, self.name)
    room:throwCard({id}, self.name, to, player)
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

extension:addCards({
  kylinBow,
})

local eightDiagramSkill = fk.CreateTriggerSkill{
  name = "#eight_diagram_skill",
  attached_equip = "eight_diagram",
  events = {fk.AskForCardUse, fk.AskForCardResponse},
  can_trigger = function(self, event, target, player, data)
    if not (target == player and player:hasSkill(self) and
      (data.cardName == "jink" or (data.pattern and Exppattern:Parse(data.pattern):matchExp("jink|0|nosuit|none")))) then return end
    if event == fk.AskForCardUse then
      return not player:prohibitUse(Fk:cloneCard("jink"))
    else
      return not player:prohibitResponse(Fk:cloneCard("jink"))
    end
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local judgeData = {
      who = player,
      reason = self.name,
      pattern = ".|.|heart,diamond",
    }
    room:judge(judgeData)

    if judgeData.card.color == Card.Red then
      if event == fk.AskForCardUse then
        data.result = {
          from = player.id,
          card = Fk:cloneCard('jink'),
        }
        data.result.card.skillName = "eight_diagram"

        if data.eventData then
          data.result.toCard = data.eventData.toCard
          data.result.responseToEvent = data.eventData.responseToEvent
        end
      else
        data.result = Fk:cloneCard('jink')
        data.result.skillName = "eight_diagram"
      end

      return true
    end
  end
}
Fk:addSkill(eightDiagramSkill)
local eightDiagram = fk.CreateArmor{
  name = "eight_diagram",
  suit = Card.Spade,
  number = 2,
  equip_skill = eightDiagramSkill,
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
    return player.id == effect.to and player:hasSkill(self) and
      effect.card.trueName == "slash" and effect.card.color == Card.Black
  end,
  on_use = Util.TrueFunc,
}
Fk:addSkill(niohShieldSkill)
local niohShield = fk.CreateArmor{
  name = "nioh_shield",
  suit = Card.Club,
  number = 2,
  equip_skill = niohShieldSkill,
}

extension:addCards({
  niohShield,
})

local diluSkill = fk.CreateDistanceSkill{
  name = "#dilu_skill",
  attached_equip = "dilu",
  correct_func = function(self, from, to)
    if to:hasSkill(self) then
      return 1
    end
  end,
}
Fk:addSkill(diluSkill)
local diLu = fk.CreateDefensiveRide{
  name = "dilu",
  suit = Card.Club,
  number = 5,
  equip_skill = diluSkill,
}

extension:addCards({
  diLu,
})

local jueyingSkill = fk.CreateDistanceSkill{
  name = "#jueying_skill",
  attached_equip = "jueying",
  correct_func = function(self, from, to)
    if to:hasSkill(self) then
      return 1
    end
  end,
}
Fk:addSkill(jueyingSkill)
local jueYing = fk.CreateDefensiveRide{
  name = "jueying",
  suit = Card.Spade,
  number = 5,
  equip_skill = jueyingSkill,
}

extension:addCards({
  jueYing,
})

local zhuahuangfeidianSkill = fk.CreateDistanceSkill{
  name = "#zhuahuangfeidian_skill",
  attached_equip = "zhuahuangfeidian",
  correct_func = function(self, from, to)
    if to:hasSkill(self) then
      return 1
    end
  end,
}
Fk:addSkill(zhuahuangfeidianSkill)
local zhuaHuangFeiDian = fk.CreateDefensiveRide{
  name = "zhuahuangfeidian",
  suit = Card.Heart,
  number = 13,
  equip_skill = zhuahuangfeidianSkill,
}

extension:addCards({
  zhuaHuangFeiDian,
})

local chituSkill = fk.CreateDistanceSkill{
  name = "#chitu_skill",
  attached_equip = "chitu",
  correct_func = function(self, from, to)
    if from:hasSkill(self) then
      return -1
    end
  end,
}
Fk:addSkill(chituSkill)
local chiTu = fk.CreateOffensiveRide{
  name = "chitu",
  suit = Card.Heart,
  number = 5,
  equip_skill = chituSkill,
}

extension:addCards({
  chiTu,
})

local dayuanSkill = fk.CreateDistanceSkill{
  name = "#dayuan_skill",
  attached_equip = "dayuan",
  correct_func = function(self, from, to)
    if from:hasSkill(self) then
      return -1
    end
  end,
}
Fk:addSkill(dayuanSkill)
local daYuan = fk.CreateOffensiveRide{
  name = "dayuan",
  suit = Card.Spade,
  number = 13,
  equip_skill = dayuanSkill,
}

extension:addCards({
  daYuan,
})

local zixingSkill = fk.CreateDistanceSkill{
  name = "#zixing_skill",
  attached_equip = "zixing",
  correct_func = function(self, from, to)
    if from:hasSkill(self) then
      return -1
    end
  end,
}
Fk:addSkill(zixingSkill)
local ziXing = fk.CreateOffensiveRide{
  name = "zixing",
  suit = Card.Diamond,
  number = 13,
  equip_skill = zixingSkill,
}

extension:addCards({
  ziXing,
})

local pkgprefix = "packages/"
if UsingNewCore then pkgprefix = "packages/freekill-core/" end
dofile(pkgprefix .. "standard_cards/i18n/init.lua")

return extension
