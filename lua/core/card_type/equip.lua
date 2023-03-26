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

---@class Weapon : EquipCard
local Weapon = EquipCard:subclass("Weapon")

function Weapon:initialize(name, suit, number, attackRange)
  EquipCard.initialize(self, name, suit, number)
  self.sub_type = Card.SubtypeWeapon
  self.attack_range = attackRange or 1
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
