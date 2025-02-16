-- SPDX-License-Identifier: GPL-3.0-or-later

local extension = Package:new("maneuvering", Package.CardPack)
local prefix = "packages."
if UsingNewCore then prefix = "packages.freekill-core." end

extension:loadSkillSkels(require(prefix .. "maneuvering.pkg.skills"))

Fk:addDamageNature(fk.FireDamage, "fire_damage")
Fk:addDamageNature(fk.ThunderDamage, "thunder_damage")

local thunder__slash = fk.CreateCard{
  name = "thunder__slash",
  type = Card.TypeBasic,
  is_damage_card = true,
  skill = "thunder__slash_skill",
}

local fire__slash = fk.CreateCard{
  name = "fire__slash",
  type = Card.TypeBasic,
  is_damage_card = true,
  skill = "fire__slash_skill",
}

local analeptic = fk.CreateCard{
  name = "analeptic",
  type = Card.TypeBasic,
  skill = "analeptic_skill",
}

local iron_chain = fk.CreateCard{
  name = "iron_chain",
  type = Card.TypeTrick,
  skill = "iron_chain_skill",
  special_skills = { "recast" },
  multiple_targets = true,
}

local fire_attack = fk.CreateCard{
  name = "fire_attack",
  type = Card.TypeTrick,
  skill = "fire_attack_skill",
  is_damage_card = true,
}

local supply_shortage = fk.CreateCard{
  name = "supply_shortage",
  type = Card.TypeTrick,
  sub_type = Card.SubtypeDelayedTrick,
  skill = "supply_shortage_skill",
}

local guding_blade = fk.CreateCard{
  name = "guding_blade",
  type = Card.TypeEquip,
  sub_type = Card.SubtypeWeapon,
  attack_range = 2,
  equip_skill = "#guding_blade_skill",
}

local fan = fk.CreateCard{
  name = "fan",
  type = Card.TypeEquip,
  sub_type = Card.SubtypeWeapon,
  attack_range = 4,
  equip_skill = "#fan_skill",
}

local vine = fk.CreateCard{
  name = "vine",
  type = Card.TypeEquip,
  sub_type = Card.SubtypeArmor,
  equip_skill = "#vine_skill",
}

local silver_lion = fk.CreateCard{
  name = "silver_lion",
  type = Card.TypeEquip,
  sub_type = Card.SubtypeArmor,
  equip_skill = "#silver_lion_skill",
}

local hualiu = fk.CreateCard{
  name = "hualiu",
  type = Card.TypeEquip,
  sub_type = Card.SubtypeDefensiveRide,
  equip_skill = "#hualiu_skill",
}

extension:loadCardSkels {
  thunder__slash, fire__slash, analeptic,
  iron_chain, fire_attack, supply_shortage,
  guding_blade, fan, vine, silver_lion, hualiu,
}

extension:addCardSpec("thunder__slash", Card.Club, 5)
extension:addCardSpec("thunder__slash", Card.Club, 6)
extension:addCardSpec("thunder__slash", Card.Club, 7)
extension:addCardSpec("thunder__slash", Card.Club, 8)
extension:addCardSpec("thunder__slash", Card.Spade, 4)
extension:addCardSpec("thunder__slash", Card.Spade, 5)
extension:addCardSpec("thunder__slash", Card.Spade, 6)
extension:addCardSpec("thunder__slash", Card.Spade, 7)
extension:addCardSpec("thunder__slash", Card.Spade, 8)

extension:addCardSpec("fire__slash", Card.Heart, 4)
extension:addCardSpec("fire__slash", Card.Heart, 7)
extension:addCardSpec("fire__slash", Card.Heart, 10)
extension:addCardSpec("fire__slash", Card.Diamond, 4)
extension:addCardSpec("fire__slash", Card.Diamond, 5)

extension:addCardSpec("analeptic", Card.Spade, 3)
extension:addCardSpec("analeptic", Card.Spade, 9)
extension:addCardSpec("analeptic", Card.Club, 3)
extension:addCardSpec("analeptic", Card.Club, 9)
extension:addCardSpec("analeptic", Card.Diamond, 9)

extension:addCardSpec("iron_chain", Card.Spade, 11)
extension:addCardSpec("iron_chain", Card.Spade, 12)
extension:addCardSpec("iron_chain", Card.Club, 10)
extension:addCardSpec("iron_chain", Card.Club, 11)
extension:addCardSpec("iron_chain", Card.Club, 12)
extension:addCardSpec("iron_chain", Card.Club, 13)

extension:addCardSpec("fire_attack", Card.Heart, 2)
extension:addCardSpec("fire_attack", Card.Heart, 3)
extension:addCardSpec("fire_attack", Card.Diamond, 12)

extension:addCardSpec("supply_shortage", Card.Spade, 10)
extension:addCardSpec("supply_shortage", Card.Club, 4)

extension:addCardSpec("guding_blade", Card.Spade, 1)
extension:addCardSpec("fan", Card.Diamond, 1)

extension:addCardSpec("vine", Card.Spade, 2)
extension:addCardSpec("vine", Card.Club, 2)
extension:addCardSpec("silver_lion", Card.Club, 1)

extension:addCardSpec("hualiu", Card.Diamond, 13)

extension:addCardSpec("jink", Card.Heart, 8)
extension:addCardSpec("jink", Card.Heart, 9)
extension:addCardSpec("jink", Card.Heart, 11)
extension:addCardSpec("jink", Card.Heart, 12)
extension:addCardSpec("jink", Card.Diamond, 6)
extension:addCardSpec("jink", Card.Diamond, 7)
extension:addCardSpec("jink", Card.Diamond, 8)
extension:addCardSpec("jink", Card.Diamond, 10)
extension:addCardSpec("jink", Card.Diamond, 11)

extension:addCardSpec("peach", Card.Heart, 5)
extension:addCardSpec("peach", Card.Heart, 6)
extension:addCardSpec("peach", Card.Diamond, 2)
extension:addCardSpec("peach", Card.Diamond, 3)

extension:addCardSpec("nullification", Card.Heart, 1)
extension:addCardSpec("nullification", Card.Heart, 13)
extension:addCardSpec("nullification", Card.Spade, 13)

Fk:loadTranslationTable{
  ["maneuvering"] = "军争",

  ["thunder__slash"] = "雷杀",
  [":thunder__slash"] = "基本牌<br/><b>时机</b>：出牌阶段<br/><b>目标</b>：攻击范围内的一名角色<br/><b>效果</b>：对目标角色造成1点雷电伤害。",
  ["#thunder__slash_skill"] = "选择攻击范围内的一名角色，对其造成1点雷电伤害",
  ["#thunder__slash_skill_multi"] = "选择攻击范围内的至多%arg名角色，对这些角色各造成1点雷电伤害",

  ["fire__slash"] = "火杀",
  [":fire__slash"] = "基本牌<br/><b>时机</b>：出牌阶段<br/><b>目标</b>：攻击范围内的一名角色<br/><b>效果</b>：对目标角色造成1点火焰伤害。",
  ["#fire__slash_skill"] = "选择攻击范围内的一名角色，对其造成1点火焰伤害",
  ["#fire__slash_skill_multi"] = "选择攻击范围内的至多%arg名角色，对这些角色各造成1点火焰伤害",

  ["analeptic"] = "酒",
  [":analeptic"] = "基本牌<br/><b>时机</b>：出牌阶段/你处于濒死状态时<br/><b>目标</b>：你<br/><b>效果</b>：目标角色本回合使用的下一张【杀】将要造成的伤害+1/目标角色回复1点体力。",
  ["#analeptic_skill"] = "你于此回合内使用的下一张【杀】的伤害值基数+1",

  ["iron_chain"] = "铁锁连环",
  [":iron_chain"] = "锦囊牌<br/><b>时机</b>：出牌阶段<br/><b>目标</b>：一至两名角色<br/><b>效果</b>：横置或重置目标角色的武将牌。",
  ["#iron_chain_skill"] = "选择一至两名角色，这些角色横置或重置",
  ["_normal_use"] = "正常使用",
  ["recast"] = "重铸",
  [":recast"] = "你可以将此牌置入弃牌堆，然后摸一张牌。",
  ["#recast"] = "将此牌置入弃牌堆，然后摸一张牌",

  ["fire_attack"] = "火攻",
  ["fire_attack_skill"] = "火攻",
  [":fire_attack"] = "锦囊牌<br/><b>时机</b>：出牌阶段<br/><b>目标</b>：一名有手牌的角色<br/><b>效果</b>：目标角色展示一张手牌，然后你可以弃置一张与此牌花色相同的手牌对其造成1点火焰伤害。",
  ["#fire_attack-show"] = "%src 对你使用了火攻，请展示一张手牌",
  ["#fire_attack-discard"] = "你可弃置一张 %arg 手牌，对 %src 造成1点火属性伤害",
  ["#fire_attack_skill"] = "选择一名有手牌的角色，令其展示一张手牌，<br />然后你可以弃置一张与此牌花色相同的手牌对其造成1点火焰伤害",

  ["supply_shortage"] = "兵粮寸断",
  [":supply_shortage"] = "延时锦囊牌<br/><b>时机</b>：出牌阶段<br/><b>目标</b>：距离1的一名其他角色<br/><b>效果</b>：将此牌置于目标角色判定区内。其判定阶段进行判定：若结果不为♣，其跳过摸牌阶段。然后将【兵粮寸断】置入弃牌堆。",
  ["#supply_shortage_skill"] = "选择距离1的一名角色，将此牌置于其判定区内。其判定阶段判定：<br/>若结果不为♣，其跳过摸牌阶段",

  ["guding_blade"] = "古锭刀",
  [":guding_blade"] = "装备牌·武器<br/><b>攻击范围</b>：2<br/><b>武器技能</b>：锁定技。每当你使用【杀】对目标角色造成伤害时，若该角色没有手牌，此伤害+1。",
  ["#guding_blade_skill"] = "古锭刀",

  ["fan"] = "朱雀羽扇",
  [":fan"] = "装备牌·武器<br/><b>攻击范围</b>：4<br/><b>武器技能</b>：当你声明使用普【杀】后，你可以将此【杀】改为火【杀】。",
  ["#fan_skill"] = "朱雀羽扇",

  ["vine"] = "藤甲",
  [":vine"] = "装备牌·防具<br/><b>防具技能</b>：锁定技。【南蛮入侵】、【万箭齐发】和普通【杀】对你无效。每当你受到火焰伤害时，此伤害+1。",
  ["#vine_skill"] = "藤甲",

  ["silver_lion"] = "白银狮子",
  [":silver_lion"] = "装备牌·防具<br/><b>防具技能</b>：锁定技。每当你受到伤害时，若此伤害大于1点，防止多余的伤害。每当你失去装备区里的【白银狮子】后，你回复1点体力。",
  ["#silver_lion_skill"] = "白银狮子",

  ["hualiu"] = "骅骝",
  [":hualiu"] = "装备牌·坐骑<br/><b>坐骑技能</b>：其他角色与你的距离+1。",
}

local pkgprefix = "packages/"
if UsingNewCore then pkgprefix = "packages/freekill-core/" end
Fk:loadTranslationTable(require(pkgprefix .. 'maneuvering/i18n/en_US'), 'en_US')
Fk:loadTranslationTable(require(pkgprefix .. 'maneuvering/i18n/vi_VN'), 'vi_VN')

return extension
