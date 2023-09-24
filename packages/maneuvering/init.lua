-- SPDX-License-Identifier: GPL-3.0-or-later

local extension = Package:new("maneuvering", Package.CardPack)

local slash = Fk:cloneCard("slash")

local thunderSlashSkill = fk.CreateActiveSkill{
  name = "thunder__slash_skill",
  max_phase_use_time = 1,
  target_num = 1,
  can_use = slash.skill.canUse,
  mod_target_filter = slash.skill.modTargetFilter,
  target_filter = slash.skill.targetFilter,
  on_effect = function(self, room, effect)
    local to = effect.to
    local from = effect.from

    room:damage({
      from = room:getPlayerById(from),
      to = room:getPlayerById(to),
      card = effect.card,
      damage = 1,
      damageType = fk.ThunderDamage,
      skillName = self.name
    })
  end
}
local thunderSlash = fk.CreateBasicCard{
  name = "thunder__slash",
  skill = thunderSlashSkill,
  is_damage_card = true,
}

extension:addCards{
  thunderSlash:clone(Card.Club, 5),
  thunderSlash:clone(Card.Club, 6),
  thunderSlash:clone(Card.Club, 7),
  thunderSlash:clone(Card.Club, 8),
  thunderSlash:clone(Card.Spade, 4),
  thunderSlash:clone(Card.Spade, 5),
  thunderSlash:clone(Card.Spade, 6),
  thunderSlash:clone(Card.Spade, 7),
  thunderSlash:clone(Card.Spade, 8),
}

local fireSlashSkill = fk.CreateActiveSkill{
  name = "fire__slash_skill",
  max_phase_use_time = 1,
  target_num = 1,
  can_use = slash.skill.canUse,
  mod_target_filter = slash.skill.modTargetFilter,
  target_filter = slash.skill.targetFilter,
  on_effect = function(self, room, effect)
    local to = effect.to
    local from = effect.from

    room:damage({
      from = room:getPlayerById(from),
      to = room:getPlayerById(to),
      card = effect.card,
      damage = 1,
      damageType = fk.FireDamage,
      skillName = self.name
    })
  end
}
local fireSlash = fk.CreateBasicCard{
  name = "fire__slash",
  skill = fireSlashSkill,
  is_damage_card = true,
}

extension:addCards{
  fireSlash:clone(Card.Heart, 4),
  fireSlash:clone(Card.Heart, 7),
  fireSlash:clone(Card.Heart, 10),
  fireSlash:clone(Card.Diamond, 4),
  fireSlash:clone(Card.Diamond, 5),
}

local analepticSkill = fk.CreateActiveSkill{
  name = "analeptic_skill",
  max_turn_use_time = 1,
  mod_target_filter = function(self, to_select, selected, user, card, distance_limited)
    return self:withinTimesLimit(Fk:currentRoom():getPlayerById(to_select), Player.HistoryTurn, card, "analeptic", Fk:currentRoom():getPlayerById(to_select)) and
      not table.find(Fk:currentRoom().alive_players, function(p)
        return p.dying
      end)
  end,
  can_use = function(self, player, card)
    return self:withinTimesLimit(player, Player.HistoryTurn, card, "analeptic", player)
  end,
  on_use = function(self, room, use)
    if not use.tos or #TargetGroup:getRealTargets(use.tos) == 0 then
      use.tos = { { use.from } }
    end

    if use.extra_data and use.extra_data.analepticRecover then
      use.extraUse = true
    end
  end,
  on_effect = function(self, room, effect)
    local to = room:getPlayerById(effect.to)
    if effect.extra_data and effect.extra_data.analepticRecover then
      room:recover({
        who = to,
        num = 1,
        recoverBy = room:getPlayerById(effect.from),
        card = effect.card,
      })
    else
      to.drank = to.drank + 1
      room:broadcastProperty(to, "drank")
    end
  end
}

local analepticEffect = fk.CreateTriggerSkill{
  name = "analeptic_effect",
  global = true,
  priority = 0, -- game rule
  events = { fk.PreCardUse, fk.EventPhaseStart },
  can_trigger = function(self, event, target, player, data)
    if target ~= player then
      return false
    end

    if event == fk.PreCardUse then
      return data.card.trueName == "slash" and player.drank > 0
    else
      return target.phase == Player.NotActive
    end
  end,
  on_trigger = function(self, event, target, player, data)
    local room = player.room
    if event == fk.PreCardUse then
      data.additionalDamage = (data.additionalDamage or 0) + player.drank
      data.extra_data = data.extra_data or {}
      data.extra_data.drankBuff = player.drank
      player.drank = 0
      room:broadcastProperty(player, "drank")
    else
      for _, p in ipairs(room:getAlivePlayers(true)) do
        if p.drank > 0 then
          p.drank = 0
          room:broadcastProperty(p, "drank")
        end
      end
    end
  end,
}
Fk:addSkill(analepticEffect)

local analeptic = fk.CreateBasicCard{
  name = "analeptic",
  suit = Card.Spade,
  number = 3,
  skill = analepticSkill,
}

extension:addCards({
  analeptic,
  analeptic:clone(Card.Spade, 9),
  analeptic:clone(Card.Club, 3),
  analeptic:clone(Card.Club, 9),
  analeptic:clone(Card.Diamond, 9),
})

local recast = fk.CreateActiveSkill{
  name = "recast",
  target_num = 0,
  on_use = function(self, room, effect)
    room:recastCard(effect.cards, room:getPlayerById(effect.from))
  end
}
Fk:addSkill(recast)

local ironChainCardSkill = fk.CreateActiveSkill{
  name = "iron_chain_skill",
  min_target_num = 1,
  max_target_num = 2,
  mod_target_filter = function(self, to_select, selected, user, card, distance_limited)
    local to = Fk:currentRoom():getPlayerById(to_select)
    local from = Fk:currentRoom():getPlayerById(user)
    return not (card and from:isProhibited(to, card)) and not to:isKongcheng()
  end,
  target_filter = function(self, to_select, selected, _, card)
    if #selected < self:getMaxTargetNum(Self, card) then
      return self:modTargetFilter(to_select, selected, Self.id, card)
    end
  end,
  on_effect = function(self, room, cardEffectEvent)
    local to = room:getPlayerById(cardEffectEvent.to)
    to:setChainState(not to.chained)
  end,
}

local ironChain = fk.CreateTrickCard{
  name = "iron_chain",
  skill = ironChainCardSkill,
  special_skills = { "recast" },
  multiple_targets = true,
}
extension:addCards{
  ironChain:clone(Card.Spade, 11),
  ironChain:clone(Card.Spade, 12),
  ironChain:clone(Card.Club, 10),
  ironChain:clone(Card.Club, 11),
  ironChain:clone(Card.Club, 12),
  ironChain:clone(Card.Club, 13),
}

local fireAttackSkill = fk.CreateActiveSkill{
  name = "fire_attack_skill",
  target_num = 1,
  mod_target_filter = function(self, to_select, selected, user, card, distance_limited)
    local to = Fk:currentRoom():getPlayerById(to_select)
    local from = Fk:currentRoom():getPlayerById(user)
    return not (card and from:isProhibited(to, card)) and not to:isKongcheng()
  end,
  target_filter = function(self, to_select, selected, _, card)
    if #selected < self:getMaxTargetNum(Self, card) then
      return self:modTargetFilter(to_select, selected, Self.id, card)
    end
  end,
  on_effect = function(self, room, cardEffectEvent)
    local from = room:getPlayerById(cardEffectEvent.from)
    local to = room:getPlayerById(cardEffectEvent.to)
    if to:isKongcheng() then return end

    local showCard = room:askForCard(to, 1, 1, false, self.name, false, ".|.|.|hand", "#fire_attack-show:" .. from.id)[1]
    to:showCards(showCard)

    showCard = Fk:getCardById(showCard)
    local cards = room:askForDiscard(from, 1, 1, false, self.name, true,
                                    ".|.|" .. showCard:getSuitString(), "#fire_attack-discard:" .. to.id .. "::" .. showCard:getSuitString())
    if #cards > 0 then
      room:damage({
        from = from,
        to = to,
        card = cardEffectEvent.card,
        damage = 1,
        damageType = fk.FireDamage,
        skillName = self.name
      })
    end
  end,
}
local fireAttack = fk.CreateTrickCard{
  name = "fire_attack",
  skill = fireAttackSkill,
  is_damage_card = true,
}
extension:addCards{
  fireAttack:clone(Card.Heart, 2),
  fireAttack:clone(Card.Heart, 3),
  fireAttack:clone(Card.Diamond, 12),
}

local supplyShortageSkill = fk.CreateActiveSkill{
  name = "supply_shortage_skill",
  distance_limit = 1,
  mod_target_filter = function(self, to_select, selected, user, card, distance_limited)
    local player = Fk:currentRoom():getPlayerById(to_select)
    local from = Fk:currentRoom():getPlayerById(user)
    return from ~= player and not (distance_limited and not self:withinDistanceLimit(from, false, card, player))
    and not (card and from:isProhibited(player, card))
  end,
  target_filter = function(self, to_select, selected, _, card)
    return #selected == 0 and self:modTargetFilter(to_select, selected, Self.id, card, true)
  end,
  target_num = 1,
  on_effect = function(self, room, effect)
    local to = room:getPlayerById(effect.to)
    local judge = {
      who = to,
      reason = "supply_shortage",
      negative = true, --增加了反向动画
      pattern = ".|.|club"
    }
    room:judge(judge)
    if not judge.isgood then
      to:skip(Player.Draw)
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
local supplyShortage = fk.CreateDelayedTrickCard{
  name = "supply_shortage",
  skill = supplyShortageSkill,
}
extension:addCards{
  supplyShortage:clone(Card.Spade, 10),
  supplyShortage:clone(Card.Club, 4),
}

local gudingSkill = fk.CreateTriggerSkill{
  name = "#guding_blade_skill",
  attached_equip = "guding_blade",
  frequency = Skill.Compulsory,
  events = {fk.DamageCaused},
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(self.name) and
      data.to:isKongcheng() and data.card and data.card.trueName == "slash" and
      not data.chain
  end,
  on_use = function(_, _, _, _, data)
    data.damage = data.damage + 1
  end,
}
Fk:addSkill(gudingSkill)
local gudingBlade = fk.CreateWeapon{
  name = "guding_blade",
  suit = Card.Spade,
  number = 1,
  attack_range = 2,
  equip_skill = gudingSkill,
}

extension:addCard(gudingBlade)

local fanSkill = fk.CreateTriggerSkill{
  name = "#fan_skill",
  attached_equip = "fan",
  events = { fk.AfterCardUseDeclared },
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(self.name) and data.card.name == "slash"
  end,
  on_use = function(_, _, _, _, data)
    local card = Fk:cloneCard("fire__slash")
    card.skillName = "fan"
    card:addSubcard(data.card)
    data.card = card
  end,
}
Fk:addSkill(fanSkill)
local fan = fk.CreateWeapon{
  name = "fan",
  suit = Card.Diamond,
  number = 1,
  attack_range = 4,
  equip_skill = fanSkill,
}

extension:addCard(fan)

local vineSkill = fk.CreateTriggerSkill{
  name = "#vine_skill",
  attached_equip = "vine",
  mute = true,
  frequency = Skill.Compulsory,

  events = {fk.PreCardEffect, fk.DamageInflicted},
  can_trigger = function(self, event, target, player, data)
    if event == fk.DamageInflicted then
      return target == player and player:hasSkill(self.name) and
        data.damageType == fk.FireDamage
    end
    local effect = data ---@type CardEffectEvent
    return player.id == effect.to and player:hasSkill(self.name) and
      (effect.card.name == "slash" or effect.card.name == "savage_assault" or
      effect.card.name == "archery_attack")
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    if event == fk.DamageInflicted then
      room:broadcastPlaySound("./packages/maneuvering/audio/card/vineburn")
      room:setEmotion(player, "./packages/maneuvering/image/anim/vineburn")
      data.damage = data.damage + 1
    else
      room:broadcastPlaySound("./packages/maneuvering/audio/card/vine")
      room:setEmotion(player, "./packages/maneuvering/image/anim/vine")
      return true
    end
  end,
}
Fk:addSkill(vineSkill)
local vine = fk.CreateArmor{
  name = "vine",
  equip_skill = vineSkill,
}
extension:addCards{
  vine:clone(Card.Spade, 2),
  vine:clone(Card.Club, 2),
}

local silverLionSkill = fk.CreateTriggerSkill{
  name = "#silver_lion_skill",
  attached_equip = "silver_lion",
  frequency = Skill.Compulsory,
  events = {fk.DamageInflicted},
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(self.name) and data.damage > 1
  end,
  on_use = function(_, _, _, _, data)
    data.damage = 1
  end,
}
Fk:addSkill(silverLionSkill)
local silverLion = fk.CreateArmor{
  name = "silver_lion",
  suit = Card.Club,
  number = 1,
  equip_skill = silverLionSkill,
  on_uninstall = function(self, room, player)
    Armor.onUninstall(self, room, player)
    if player:isAlive() and player:isWounded() and self.equip_skill:isEffectable(player) then
      room:broadcastPlaySound("./packages/maneuvering/audio/card/silver_lion")
      room:setEmotion(player, "./packages/maneuvering/image/anim/silver_lion")
      room:recover{
        who = player,
        num = 1,
        skillName = self.name
      }
    end
  end,
}
extension:addCard(silverLion)

local huaLiu = fk.CreateDefensiveRide{
  name = "hualiu",
  suit = Card.Diamond,
  number = 13,
}

extension:addCards({
  huaLiu,
})

extension:addCards{
  Fk:cloneCard("jink", Card.Heart, 8),
  Fk:cloneCard("jink", Card.Heart, 9),
  Fk:cloneCard("jink", Card.Heart, 11),
  Fk:cloneCard("jink", Card.Heart, 12),
  Fk:cloneCard("jink", Card.Diamond, 6),
  Fk:cloneCard("jink", Card.Diamond, 7),
  Fk:cloneCard("jink", Card.Diamond, 8),
  Fk:cloneCard("jink", Card.Diamond, 10),
  Fk:cloneCard("jink", Card.Diamond, 11),

  Fk:cloneCard("peach", Card.Heart, 5),
  Fk:cloneCard("peach", Card.Heart, 6),
  Fk:cloneCard("peach", Card.Diamond, 2),
  Fk:cloneCard("peach", Card.Diamond, 3),

  Fk:cloneCard("nullification", Card.Heart, 1),
  Fk:cloneCard("nullification", Card.Heart, 13),
  Fk:cloneCard("nullification", Card.Spade, 13),
}

Fk:loadTranslationTable{
  ["maneuvering"] = "军争",

  ["thunder__slash"] = "雷杀",
	[":thunder__slash"] = "基本牌<br /><b>时机</b>：出牌阶段<br /><b>目标</b>：攻击范围内的一名角色<br /><b>效果</b>：对目标角色造成1点雷电伤害。",
  ["fire__slash"] = "火杀",
	[":fire__slash"] = "基本牌<br /><b>时机</b>：出牌阶段<br /><b>目标</b>：攻击范围内的一名角色<br /><b>效果</b>：对目标角色造成1点火焰伤害。",
  ["analeptic"] = "酒",
	[":analeptic"] = "基本牌<br /><b>时机</b>：出牌阶段/你处于濒死状态时<br /><b>目标</b>：你<br /><b>效果</b>：目标角色本回合使用的下一张【杀】将要造成的伤害+1/目标角色回复1点体力。",
  ["iron_chain"] = "铁锁连环",
	[":iron_chain"] = "锦囊牌<br /><b>时机</b>：出牌阶段<br /><b>目标</b>：一至两名角色<br /><b>效果</b>：横置或重置目标角色的武将牌。",
  ["_normal_use"] = "正常使用",
  ["recast"] = "重铸",
  [":recast"] = "你可以将此牌置入弃牌堆，然后摸一张牌。",
  ["fire_attack"] = "火攻",
  ["fire_attack_skill"] = "火攻",
	[":fire_attack"] = "锦囊牌<br /><b>时机</b>：出牌阶段<br /><b>目标</b>：一名有手牌的角色<br /><b>效果</b>：目标角色展示一张手牌，然后你可以弃置一张与所展示牌花色相同的手牌令其受到1点火焰伤害。",
  ["#fire_attack-show"] = "%src 对你使用了火攻，请展示一张手牌",
  ["#fire_attack-discard"] = "你可弃置一张 %arg 手牌，对 %src 造成1点火属性伤害",
  ["supply_shortage"] = "兵粮寸断",
	[":supply_shortage"] = "延时锦囊牌<br /><b>时机</b>：出牌阶段<br /><b>目标</b>：距离1的一名其他角色<br /><b>效果</b>：将此牌置于目标角色判定区内。其判定阶段进行判定：若结果不为梅花，其跳过摸牌阶段。然后将【兵粮寸断】置入弃牌堆。",
  ["guding_blade"] = "古锭刀",
	[":guding_blade"] = "装备牌·武器<br /><b>攻击范围</b>：２<br /><b>武器技能</b>：锁定技。每当你使用【杀】对目标角色造成伤害时，若该角色没有手牌，此伤害+1。",
  ["fan"] = "朱雀羽扇",
	[":fan"] = "装备牌·武器<br /><b>攻击范围</b>：４<br /><b>武器技能</b>：你可以将一张普通【杀】当火【杀】使用。",
  ["#fan_skill"] = "朱雀羽扇",
  ["vine"] = "藤甲",
	[":vine"] = "装备牌·防具<br /><b>防具技能</b>：锁定技。【南蛮入侵】、【万箭齐发】和普通【杀】对你无效。每当你受到火焰伤害时，此伤害+1。",
  ["silver_lion"] = "白银狮子",
	[":silver_lion"] = "装备牌·防具<br /><b>防具技能</b>：锁定技。每当你受到伤害时，若此伤害大于1点，防止多余的伤害。每当你失去装备区里的【白银狮子】后，你回复1点体力。",
  ["hualiu"] = "骅骝",
  [":hualiu"] = "装备牌·坐骑<br /><b>坐骑技能</b>：其他角色与你的距离+1。",
}

return extension
