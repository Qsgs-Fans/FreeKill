-- SPDX-License-Identifier: GPL-3.0-or-later

---@class EquipCard : Card
---@field public equip_skill Skill
local EquipCard = Card:subclass("EquipCard")

function EquipCard:initialize(name, suit, number)
  Card.initialize(self, name, suit, number)
  self.type = Card.TypeEquip
  self.equip_skill = nil
end

---@param room Room
---@param player Player
function EquipCard:onInstall(room, player)
  if self.equip_skill then
    room:handleAddLoseSkills(player, self.equip_skill.name, nil, false, true)
  end
end

---@param room Room
---@param player Player
function EquipCard:onUninstall(room, player)
  if self.equip_skill then
    room:handleAddLoseSkills(player, "-" .. self.equip_skill.name, nil, false, true)
  end
end

function EquipCard:clone(suit, number)
  local ret = Card.clone(self, suit, number)
  ret.equip_skill = self.equip_skill
  ret.onInstall = self.onInstall
  ret.onUninstall = self.onUninstall
  return ret
end

---@class Weapon : EquipCard
---@field public attack_range integer
local Weapon = EquipCard:subclass("Weapon")

function Weapon:initialize(name, suit, number, attackRange)
  EquipCard.initialize(self, name, suit, number)
  self.sub_type = Card.SubtypeWeapon
  self.attack_range = attackRange or 1
end

function Weapon:clone(suit, number)
  local ret = EquipCard.clone(self, suit, number)
  ret.attack_range = self.attack_range
  return ret
end

---@class Armor : EquipCard
local Armor = EquipCard:subclass("armor")

function Armor:initialize(name, suit, number)
  EquipCard.initialize(self, name, suit, number)
  self.sub_type = Card.SubtypeArmor
end

---@class DefensiveRide : EquipCard
local DefensiveRide = EquipCard:subclass("DefensiveRide")

function DefensiveRide:initialize(name, suit, number)
  EquipCard.initialize(self, name, suit, number)
  self.sub_type = Card.SubtypeDefensiveRide
end

---@class OffensiveRide : EquipCard
local OffensiveRide = EquipCard:subclass("OffensiveRide")

function OffensiveRide:initialize(name, suit, number)
  EquipCard.initialize(self, name, suit, number)
  self.sub_type = Card.SubtypeOffensiveRide
end

---@class Treasure : EquipCard
local Treasure = EquipCard:subclass("Treasure")

function Treasure:initialize(name, suit, number)
  EquipCard.initialize(self, name, suit, number)
  self.sub_type = Card.SubtypeTreasure
end

return { EquipCard, Weapon, Armor, DefensiveRide, OffensiveRide, Treasure }
