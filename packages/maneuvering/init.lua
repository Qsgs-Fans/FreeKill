local extension = Package:new("maneuvering", Package.CardPack)

local slash = Fk:cloneCard("slash")

local thunderSlashSkill = fk.CreateActiveSkill{
  name = "thunder_slash_skill",
  max_phase_use_time = 1,
  target_num = 1,
  can_use = slash.skill.canUse,
  target_filter = slash.skill.targetFilter,
  on_effect = function(self, room, effect)
    local to = effect.to
    local from = effect.from

    room:damage({
      from = room:getPlayerById(from),
      to = room:getPlayerById(to),
      card = effect.card,
      damage = 1 + (effect.addtionalDamage or 0),
      damageType = fk.ThunderDamage,
      skillName = self.name
    })
  end
}
local thunderSlash = fk.CreateBasicCard{
  name = "thunder__slash",
  skill = thunderSlashSkill,
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
  name = "fire_slash_skill",
  max_phase_use_time = 1,
  target_num = 1,
  can_use = slash.skill.canUse,
  target_filter = slash.skill.targetFilter,
  on_effect = function(self, room, effect)
    local to = effect.to
    local from = effect.from

    room:damage({
      from = room:getPlayerById(from),
      to = room:getPlayerById(to),
      card = effect.card,
      damage = 1 + (effect.addtionalDamage or 0),
      damageType = fk.FireDamage,
      skillName = self.name
    })
  end
}
local fireSlash = fk.CreateBasicCard{
  name = "fire__slash",
  skill = fireSlashSkill,
}

extension:addCards{
  fireSlash:clone(Card.Heart, 4),
  fireSlash:clone(Card.Heart, 7),
  fireSlash:clone(Card.Heart, 10),
  fireSlash:clone(Card.Diamond, 4),
  fireSlash:clone(Card.Diamond, 5),
}

local ironChainEffect = fk.CreateTriggerSkill{
  name = "iron_chain_effect",
  global = true,
  priority = 0, -- game rule
  refresh_events = {fk.DamageFinished},
  can_refresh = function(self, event, target, player, data)
    return target == player and data.damageType ~= fk.NormalDamage
  end,
  on_refresh = function(self, event, target, player, data)
    local room = player.room
    if data.to.chained then
      data.to:setChainState(false)
    else
      return
    end
    if data.chain then return end

    local targets = table.filter(room:getAlivePlayers(), function(p)
      return p.chained
    end)
    for _, p in ipairs(targets) do
      local dmg = table.simpleClone(data)
      dmg.to = p
      dmg.chain = true
      room:damage(dmg)
    end
  end,
}
Fk:addSkill(ironChainEffect)
local ironChainCardSkill = fk.CreateActiveSkill{
  name = "iron_chain_skill",
  min_target_num = 1,
  max_target_num = 2,
  target_filter = function() return true end,
  on_effect = function(self, room, cardEffectEvent)
    local to = room:getPlayerById(cardEffectEvent.to)
    to:setChainState(not to.chained)
  end,
}
local ironChain = fk.CreateTrickCard{
  name = "iron_chain",
  skill = ironChainCardSkill,
}
extension:addCards{
  ironChain:clone(Card.Spade, 11),
  ironChain:clone(Card.Spade, 12),
  ironChain:clone(Card.Club, 10),
  ironChain:clone(Card.Club, 11),
  ironChain:clone(Card.Club, 12),
  ironChain:clone(Card.Club, 13),
}

local supplyShortageSkill = fk.CreateActiveSkill{
  name = "supply_shortage_skill",
  distance_limit = 1,
  target_filter = function(self, to_select, selected)
    if #selected == 0 then
      local player = Fk:currentRoom():getPlayerById(to_select)
      if Self ~= player then
        return not player:hasDelayedTrick("supply_shortage") and
          Self:distanceTo(player) <= self:getDistanceLimit(Self)
      end
    end
    return false
  end,
  target_num = 1,
  on_effect = function(self, room, effect)
    local to = room:getPlayerById(effect.to)
    local judge = {
      who = to,
      reason = "supply_shortage",
      pattern = ".|.|spade,heart,diamond",
    }
    room:judge(judge)
    local result = judge.card
    if result.suit ~= Card.Club then
      to:skip(Player.Draw)
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
  Fk:cloneCard("nullification", Card.Spade, 13),
}

Fk:loadTranslationTable{
  ["thunder__slash"] = "雷杀",
  ["fire__slash"] = "火杀",
  ["iron_chain"] = "铁锁连环",
  ["supply_shortage"] = "兵粮寸断",
  ["guding_blade"] = "古锭刀",
  ["hualiu"] = "骅骝",
}

return extension
