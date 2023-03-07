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

return extension
