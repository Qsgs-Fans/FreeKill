local extension = Package:new("standard_cards", Package.CardPack)
extension.metadata = require "packages.standard_cards.metadata"

Fk:loadTranslationTable{
  ["standard_cards"] = "标+EX"
}

local slash = fk.CreateBasicCard{
  name = "slash",
  number = 7,
  suit = Card.Spade,
}
Fk:loadTranslationTable{
  ["slash"] = "杀",
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

local jink = fk.CreateBasicCard{
  name = "jink",
  suit = Card.Heart,
  number = 2,
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

local peach = fk.CreateBasicCard{
  name = "peach",
  suit = Card.Heart,
  number = 3,
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

local dismantlement = fk.CreateTrickCard{
  name = "dismantlement",
  suit = Card.Spade,
  number = 3,
}
Fk:loadTranslationTable{
  ["dismantlement"] = "过河拆桥",
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
  target_filter = function(self, to_select, selected)
    if #selected == 0 then
      local player = Fk:currentRoom():getPlayerById(to_select)
      return Self ~= player and Self:distanceTo(player) <= 1
    end
  end,
  feasible = function(self, selected)
    return #selected == 1
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
}

extension:addCards({
  snatch,
  snatch:clone(Card.Spade, 4),
  snatch:clone(Card.Spade, 11),

  snatch:clone(Card.Diamond, 3),
  snatch:clone(Card.Diamond, 4),
  snatch:clone(Card.Diamond, 4),snatch:clone(Card.Diamond, 4),snatch:clone(Card.Diamond, 4),snatch:clone(Card.Diamond, 4),snatch:clone(Card.Diamond, 4),snatch:clone(Card.Diamond, 4),snatch:clone(Card.Diamond, 4),snatch:clone(Card.Diamond, 4),snatch:clone(Card.Diamond, 4),snatch:clone(Card.Diamond, 4),snatch:clone(Card.Diamond, 4),snatch:clone(Card.Diamond, 4),snatch:clone(Card.Diamond, 4),snatch:clone(Card.Diamond, 4),snatch:clone(Card.Diamond, 4),snatch:clone(Card.Diamond, 4),snatch:clone(Card.Diamond, 4),snatch:clone(Card.Diamond, 4),snatch:clone(Card.Diamond, 4),snatch:clone(Card.Diamond, 4),snatch:clone(Card.Diamond, 4),snatch:clone(Card.Diamond, 4),snatch:clone(Card.Diamond, 4),snatch:clone(Card.Diamond, 4),snatch:clone(Card.Diamond, 4),snatch:clone(Card.Diamond, 4),snatch:clone(Card.Diamond, 4),snatch:clone(Card.Diamond, 4),snatch:clone(Card.Diamond, 4),snatch:clone(Card.Diamond, 4),snatch:clone(Card.Diamond, 4),snatch:clone(Card.Diamond, 4),snatch:clone(Card.Diamond, 4),snatch:clone(Card.Diamond, 4),snatch:clone(Card.Diamond, 4),snatch:clone(Card.Diamond, 4),
})

local duel = fk.CreateTrickCard{
  name = "duel",
  suit = Card.Spade,
  number = 1,
}
Fk:loadTranslationTable{
  ["duel"] = "决斗",
}

extension:addCards({
  duel,

  duel:clone(Card.Club, 1),

  duel:clone(Card.Diamond, 1),
})

local collateral = fk.CreateTrickCard{
  name = "collateral",
  suit = Card.Club,
  number = 12,
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
    room:drawCards(room:getPlayerById(TargetGroup:getRealTargets(cardEffectEvent.tos)[1]), 2, "ex_nihilo")
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

local nullification = fk.CreateTrickCard{
  name = "nullification",
  suit = Card.Spade,
  number = 11,
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

local savageAssault = fk.CreateTrickCard{
  name = "savage_assault",
  suit = Card.Spade,
  number = 7,
}
Fk:loadTranslationTable{
  ["savage_assault"] = "南蛮入侵",
}

extension:addCards({
  savageAssault,
  savageAssault:clone(Card.Spade, 13),
  savageAssault:clone(Card.Club, 7),
})

local archeryAttack = fk.CreateTrickCard{
  name = "archery_attack",
  suit = Card.Heart,
  number = 1,
}
Fk:loadTranslationTable{
  ["archery_attack"] = "万箭齐发",
}

extension:addCards({
  archeryAttack,
})

local godSalvation = fk.CreateTrickCard{
  name = "god_salvation",
  suit = Card.Heart,
  number = 1,
}
Fk:loadTranslationTable{
  ["god_salvation"] = "桃园结义",
}

extension:addCards({
  godSalvation,
})

local amazingGrace = fk.CreateTrickCard{
  name = "amazing_grace",
  suit = Card.Heart,
  number = 3,
}
Fk:loadTranslationTable{
  ["amazing_grace"] = "五谷丰登",
}

extension:addCards({
  amazingGrace,
  amazingGrace:clone(Card.Heart, 4),
})

local lightning = fk.CreateDelayedTrickCard{
  name = "lightning",
  suit = Card.Spade,
  number = 1,
}
Fk:loadTranslationTable{
  ["lightning"] = "闪电",
}

extension:addCards({
  lightning,
  lightning:clone(Card.Heart, 12),
})

local indulgence = fk.CreateDelayedTrickCard{
  name = "indulgence",
  suit = Card.Spade,
  number = 6,
}
Fk:loadTranslationTable{
  ["indulgence"] = "乐不思蜀",
}

extension:addCards({
  indulgence,
  indulgence:clone(Card.Club, 6),
  indulgence:clone(Card.Heart, 6),
})

local crossbow = fk.CreateWeapon{
  name = "crossbow",
  suit = Card.Club,
  number = 1,
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
}
Fk:loadTranslationTable{
  ["qinggang_sword"] = "青釭剑",
}

extension:addCards({
  qingGang,
})

local iceSword = fk.CreateWeapon{
  name = "ice_sword",
  suit = Card.Spade,
  number = 2,
}
Fk:loadTranslationTable{
  ["ice_sword"] = "寒冰剑",
}

extension:addCards({
  iceSword,
})

local doubleSwords = fk.CreateWeapon{
  name = "double_swords",
  suit = Card.Spade,
  number = 2,
}
Fk:loadTranslationTable{
  ["double_swords"] = "雌雄双股剑",
}

extension:addCards({
  doubleSwords,
})

local blade = fk.CreateWeapon{
  name = "blade",
  suit = Card.Spade,
  number = 5,
}
Fk:loadTranslationTable{
  ["blade"] = "青龙偃月刀",
}

extension:addCards({
  blade,
})

local spear = fk.CreateWeapon{
  name = "spear",
  suit = Card.Spade,
  number = 12,
}
Fk:loadTranslationTable{
  ["spear"] = "丈八蛇矛",
}

extension:addCards({
  spear,
})

local axe = fk.CreateWeapon{
  name = "axe",
  suit = Card.Diamond,
  number = 5,
}
Fk:loadTranslationTable{
  ["axe"] = "贯石斧",
}

extension:addCards({
  axe,
})

local halberd = fk.CreateWeapon{
  name = "halberd",
  suit = Card.Diamond,
  number = 12,
}
Fk:loadTranslationTable{
  ["halberd"] = "方天画戟",
}

extension:addCards({
  halberd,
})

local kylinBow = fk.CreateWeapon{
  name = "kylin_bow",
  suit = Card.Heart,
  number = 5,
}
Fk:loadTranslationTable{
  ["kylin_bow"] = "麒麟弓",
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

local niohShield = fk.CreateArmor{
  name = "nioh_shield",
  suit = Card.Club,
  number = 2,
}
Fk:loadTranslationTable{
  ["nioh_shield"] = "仁王盾",
}

extension:addCards({
  niohShield,
})

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
  suit = Card.Heart,
  number = 5,
}
Fk:loadTranslationTable{
  ["zixing"] = "紫骍",
}

extension:addCards({
  ziXing,
})

return extension
