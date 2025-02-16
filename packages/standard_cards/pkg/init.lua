-- SPDX-License-Identifier: GPL-3.0-or-later

local extension = Package:new("standard_cards", Package.CardPack)

local prefix = "packages."
if UsingNewCore then prefix = "packages.freekill-core." end

extension:loadSkillSkels(require(prefix .. "standard_cards.pkg.skills"))

local slash = fk.CreateCard{
  name = "slash",
  type = Card.TypeBasic,
  is_damage_card = true,
  skill = "slash_skill",
}

local jink = fk.CreateCard{
  type = Card.TypeBasic,
  name = "jink",
  skill = "jink_skill",
  is_passive = true,
}

local peach = fk.CreateCard{
  name = "peach",
  type = Card.TypeBasic,
  skill = "peach_skill",
}

local dismantlement = fk.CreateCard{
  name = "dismantlement",
  type = Card.TypeTrick,
  skill = "dismantlement_skill",
}

local snatch = fk.CreateCard{
  name = "snatch",
  type = Card.TypeTrick,
  skill = "snatch_skill",
}

local duel = fk.CreateCard{
  name = "duel",
  type = Card.TypeTrick,
  skill = "duel_skill",
  is_damage_card = true,
}

local collateral = fk.CreateCard{
  name = "collateral",
  type = Card.TypeTrick,
  skill = "collateral_skill",
}

local ex_nihilo = fk.CreateCard{
  name = "ex_nihilo",
  type = Card.TypeTrick,
  skill = "ex_nihilo_skill",
}

local nullification = fk.CreateCard{
  name = "nullification",
  type = Card.TypeTrick,
  skill = "nullification_skill",
  is_passive = true,
}

local savage_assault = fk.CreateCard{
  name = "savage_assault",
  type = Card.TypeTrick,
  skill = "savage_assault_skill",
  is_damage_card = true,
  multiple_targets = true,
}

local archery_attack = fk.CreateCard{
  name = "archery_attack",
  type = Card.TypeTrick,
  skill = "archery_attack_skill",
  is_damage_card = true,
  multiple_targets = true,
}

local god_salvation = fk.CreateCard{
  name = "god_salvation",
  type = Card.TypeTrick,
  skill = "god_salvation_skill",
  multiple_targets = true,
}

local amazing_grace = fk.CreateCard{
  name = "amazing_grace",
  type = Card.TypeTrick,
  skill = "amazing_grace_skill",
  multiple_targets = true,
}

local lightning = fk.CreateCard{
  name = "lightning",
  type = Card.TypeTrick,
  sub_type = Card.SubtypeDelayedTrick,
  skill = "lightning_skill",
}

local indulgence = fk.CreateCard{
  name = "indulgence",
  type = Card.TypeTrick,
  sub_type = Card.SubtypeDelayedTrick,
  skill = "indulgence_skill",
}

local crossbow = fk.CreateCard{
  name = "crossbow",
  type = Card.TypeEquip,
  sub_type = Card.SubtypeWeapon,
  attack_range = 1,
  equip_skill = "#crossbow_skill",
}

local qinggang_sword = fk.CreateCard{
  name = "qinggang_sword",
  type = Card.TypeEquip,
  sub_type = Card.SubtypeWeapon,
  attack_range = 2,
  equip_skill = "#qinggang_sword_skill",
}

local ice_sword = fk.CreateCard{
  name = "ice_sword",
  type = Card.TypeEquip,
  sub_type = Card.SubtypeWeapon,
  attack_range = 2,
  equip_skill = "#ice_sword_skill",
}

local double_swords = fk.CreateCard{
  name = "double_swords",
  type = Card.TypeEquip,
  sub_type = Card.SubtypeWeapon,
  attack_range = 2,
  equip_skill = "#double_swords_skill",
}

local blade = fk.CreateCard{
  name = "blade",
  type = Card.TypeEquip,
  sub_type = Card.SubtypeWeapon,
  attack_range = 3,
  equip_skill = "#blade_skill",
}

local spear = fk.CreateCard{
  name = "spear",
  type = Card.TypeEquip,
  sub_type = Card.SubtypeWeapon,
  attack_range = 3,
  equip_skill = "spear_skill",
}

local axe = fk.CreateCard{
  name = "axe",
  type = Card.TypeEquip,
  sub_type = Card.SubtypeWeapon,
  attack_range = 3,
  equip_skill = "#axe_skill",
}

local halberd = fk.CreateCard{
  name = "halberd",
  type = Card.TypeEquip,
  sub_type = Card.SubtypeWeapon,
  attack_range = 4,
  equip_skill = "#halberd_skill",
}

local kylin_bow = fk.CreateCard{
  name = "kylin_bow",
  type = Card.TypeEquip,
  sub_type = Card.SubtypeWeapon,
  attack_range = 5,
  equip_skill = "#kylin_bow_skill",
}

local eight_diagram = fk.CreateCard{
  name = "eight_diagram",
  type = Card.TypeEquip,
  sub_type = Card.SubtypeArmor,
  equip_skill = "#eight_diagram_skill",
}

local nioh_shield = fk.CreateCard{
  name = "nioh_shield",
  type = Card.TypeEquip,
  sub_type = Card.SubtypeArmor,
  equip_skill = "#nioh_shield_skill",
}

local dilu = fk.CreateCard{
  name = "dilu",
  type = Card.TypeEquip,
  sub_type = Card.SubtypeDefensiveRide,
  equip_skill = "#dilu_skill",
}

local jueying = fk.CreateCard{
  name = "jueying",
  type = Card.TypeEquip,
  sub_type = Card.SubtypeDefensiveRide,
  equip_skill = "#jueying_skill",
}

local zhuahuangfeidian = fk.CreateCard{
  name = "zhuahuangfeidian",
  type = Card.TypeEquip,
  sub_type = Card.SubtypeDefensiveRide,
  equip_skill = "#zhuahuangfeidian_skill",
}

local chitu = fk.CreateCard{
  name = "chitu",
  type = Card.TypeEquip,
  sub_type = Card.SubtypeOffensiveRide,
  equip_skill = "#chitu_skill",
}

local dayuan = fk.CreateCard{
  name = "dayuan",
  type = Card.TypeEquip,
  sub_type = Card.SubtypeOffensiveRide,
  equip_skill = "#dayuan_skill",
}

local zixing = fk.CreateCard{
  name = "zixing",
  type = Card.TypeEquip,
  sub_type = Card.SubtypeOffensiveRide,
  equip_skill = "#zixing_skill",
}

extension:loadCardSkels {
  slash, jink, peach,
  dismantlement, snatch, duel, collateral, ex_nihilo, nullification,
  savage_assault, archery_attack, god_salvation, amazing_grace,
  lightning, indulgence,
  crossbow, qinggang_sword, ice_sword, double_swords,
  blade, spear, axe, halberd, kylin_bow,
  eight_diagram, nioh_shield,
  dilu, jueying, zhuahuangfeidian,
  chitu, dayuan, zixing,
}

extension:addCardSpec("slash", Card.Spade, 7)
extension:addCardSpec("slash", Card.Spade, 8)
extension:addCardSpec("slash", Card.Spade, 8)
extension:addCardSpec("slash", Card.Spade, 9)
extension:addCardSpec("slash", Card.Spade, 9)
extension:addCardSpec("slash", Card.Spade, 10)
extension:addCardSpec("slash", Card.Spade, 10)
extension:addCardSpec("slash", Card.Club, 2)
extension:addCardSpec("slash", Card.Club, 3)
extension:addCardSpec("slash", Card.Club, 4)
extension:addCardSpec("slash", Card.Club, 5)
extension:addCardSpec("slash", Card.Club, 6)
extension:addCardSpec("slash", Card.Club, 7)
extension:addCardSpec("slash", Card.Club, 8)
extension:addCardSpec("slash", Card.Club, 8)
extension:addCardSpec("slash", Card.Club, 9)
extension:addCardSpec("slash", Card.Club, 9)
extension:addCardSpec("slash", Card.Club, 10)
extension:addCardSpec("slash", Card.Club, 10)
extension:addCardSpec("slash", Card.Club, 11)
extension:addCardSpec("slash", Card.Club, 11)
extension:addCardSpec("slash", Card.Heart, 10)
extension:addCardSpec("slash", Card.Heart, 10)
extension:addCardSpec("slash", Card.Heart, 11)
extension:addCardSpec("slash", Card.Diamond, 6)
extension:addCardSpec("slash", Card.Diamond, 7)
extension:addCardSpec("slash", Card.Diamond, 8)
extension:addCardSpec("slash", Card.Diamond, 9)
extension:addCardSpec("slash", Card.Diamond, 10)
extension:addCardSpec("slash", Card.Diamond, 13)

extension:addCardSpec("jink", Card.Heart, 2)
extension:addCardSpec("jink", Card.Heart, 2)
extension:addCardSpec("jink", Card.Heart, 13)
extension:addCardSpec("jink", Card.Diamond, 2)
extension:addCardSpec("jink", Card.Diamond, 2)
extension:addCardSpec("jink", Card.Diamond, 3)
extension:addCardSpec("jink", Card.Diamond, 4)
extension:addCardSpec("jink", Card.Diamond, 5)
extension:addCardSpec("jink", Card.Diamond, 6)
extension:addCardSpec("jink", Card.Diamond, 7)
extension:addCardSpec("jink", Card.Diamond, 8)
extension:addCardSpec("jink", Card.Diamond, 9)
extension:addCardSpec("jink", Card.Diamond, 10)
extension:addCardSpec("jink", Card.Diamond, 11)
extension:addCardSpec("jink", Card.Diamond, 11)

extension:addCardSpec("peach", Card.Heart, 3)
extension:addCardSpec("peach", Card.Heart, 4)
extension:addCardSpec("peach", Card.Heart, 6)
extension:addCardSpec("peach", Card.Heart, 7)
extension:addCardSpec("peach", Card.Heart, 8)
extension:addCardSpec("peach", Card.Heart, 9)
extension:addCardSpec("peach", Card.Heart, 12)
extension:addCardSpec("peach", Card.Heart, 12)

extension:addCardSpec("dismantlement", Card.Spade, 3)
extension:addCardSpec("dismantlement", Card.Spade, 4)
extension:addCardSpec("dismantlement", Card.Spade, 12)
extension:addCardSpec("dismantlement", Card.Club, 3)
extension:addCardSpec("dismantlement", Card.Club, 4)
extension:addCardSpec("dismantlement", Card.Heart, 12)

extension:addCardSpec("snatch", Card.Spade, 3)
extension:addCardSpec("snatch", Card.Spade, 4)
extension:addCardSpec("snatch", Card.Spade, 11)
extension:addCardSpec("snatch", Card.Diamond, 3)
extension:addCardSpec("snatch", Card.Diamond, 4)

extension:addCardSpec("duel", Card.Spade, 1)
extension:addCardSpec("duel", Card.Club, 1)
extension:addCardSpec("duel", Card.Diamond, 1)

extension:addCardSpec("collateral", Card.Club, 12)
extension:addCardSpec("collateral", Card.Club, 13)

extension:addCardSpec("ex_nihilo", Card.Heart, 7)
extension:addCardSpec("ex_nihilo", Card.Heart, 8)
extension:addCardSpec("ex_nihilo", Card.Heart, 9)
extension:addCardSpec("ex_nihilo", Card.Heart, 11)

extension:addCardSpec("nullification", Card.Spade, 11)
extension:addCardSpec("nullification", Card.Club, 12)
extension:addCardSpec("nullification", Card.Club, 13)
extension:addCardSpec("nullification", Card.Diamond, 12)

extension:addCardSpec("savage_assault", Card.Spade, 7)
extension:addCardSpec("savage_assault", Card.Spade, 13)
extension:addCardSpec("savage_assault", Card.Club, 7)

extension:addCardSpec("archery_attack", Card.Heart, 1)

extension:addCardSpec("god_salvation", Card.Heart, 1)

extension:addCardSpec("amazing_grace", Card.Heart, 3)
extension:addCardSpec("amazing_grace", Card.Heart, 4)

extension:addCardSpec("lightning", Card.Spade, 1)
extension:addCardSpec("lightning", Card.Heart, 12)

extension:addCardSpec("indulgence", Card.Spade, 6)
extension:addCardSpec("indulgence", Card.Club, 6)
extension:addCardSpec("indulgence", Card.Heart, 6)

extension:addCardSpec("crossbow", Card.Club, 1)
extension:addCardSpec("crossbow", Card.Diamond, 1)

extension:addCardSpec("qinggang_sword", Card.Spade, 6)
extension:addCardSpec("ice_sword", Card.Spade, 2)
extension:addCardSpec("double_swords", Card.Spade, 2)
extension:addCardSpec("blade", Card.Spade, 5)
extension:addCardSpec("spear", Card.Spade, 12)
extension:addCardSpec("axe", Card.Diamond, 5)
extension:addCardSpec("halberd", Card.Diamond, 12)
extension:addCardSpec("kylin_bow", Card.Heart, 5)

extension:addCardSpec("eight_diagram", Card.Spade, 2)
extension:addCardSpec("eight_diagram", Card.Club, 2)
extension:addCardSpec("nioh_shield", Card.Club, 2)

extension:addCardSpec("dilu", Card.Club, 5)
extension:addCardSpec("jueying", Card.Spade, 5)
extension:addCardSpec("zhuahuangfeidian", Card.Heart, 13)

extension:addCardSpec("chitu", Card.Heart, 5)
extension:addCardSpec("dayuan", Card.Spade, 13)
extension:addCardSpec("zixing", Card.Diamond, 13)

local pkgprefix = "packages/"
if UsingNewCore then pkgprefix = "packages/freekill-core/" end
dofile(pkgprefix .. "standard_cards/i18n/init.lua")

return extension
