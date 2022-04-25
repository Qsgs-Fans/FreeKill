---@class EquipCard : Card
local EquipCard = Card:subclass("EquipCard")

function EquipCard:initialize(name, suit, number)
  Card.initialize(self, name, suit, number)
  self.type = Card.TypeEquip
end

---@class Weapon : EquipCard
local Weapon = EquipCard:subclass("Weapon")

function Weapon:initialize(name, suit, number, attackRange)
  EquipCard.initialize(self, name, suit, number)
  self.sub_type = Card.SubtypeWeapon
  self.attack_range = attackRange or 1
end

---@param suit Suit
---@param number integer
---@return Weapon
function Weapon:clone(suit, number)
  local newCard = Weapon:new(self.name, suit, number, self.attack_range)
  return newCard
end

---@class Armor : EquipCard
local Armor = EquipCard:subclass("armor")

function Armor:initialize(name, suit, number)
  EquipCard.initialize(self, name, suit, number)
  self.sub_type = Card.SubtypeArmor
end

---@param suit Suit
---@param number integer
---@return Armor
function Armor:clone(suit, number)
  local newCard = Armor:new(self.name, suit, number)
  return newCard
end

---@class DefensiveRide : EquipCard
local DefensiveRide = EquipCard:subclass("DefensiveRide")

function DefensiveRide:initialize(name, suit, number)
  EquipCard.initialize(self, name, suit, number)
  self.sub_type = Card.SubtypeDefensiveRide
end

---@param suit Suit
---@param number integer
---@return DefensiveRide
function DefensiveRide:clone(suit, number)
  local newCard = DefensiveRide:new(self.name, suit, number)
  return newCard
end

---@class OffensiveRide : EquipCard
local OffensiveRide = EquipCard:subclass("OffensiveRide")

function OffensiveRide:initialize(name, suit, number)
  EquipCard.initialize(self, name, suit, number)
  self.sub_type = Card.SubtypeOffensiveRide
end

---@param suit Suit
---@param number integer
---@return OffensiveRide
function OffensiveRide:clone(suit, number)
  local newCard = OffensiveRide:new(self.name, suit, number)
  return newCard
end

---@class Treasure : EquipCard
local Treasure = EquipCard:subclass("Treasure")

function Treasure:initialize(name, suit, number)
  EquipCard.initialize(self, name, suit, number)
  self.sub_type = Card.SubtypeTreasure
end

---@param suit Suit
---@param number integer
---@return Treasure
function Treasure:clone(suit, number)
  local newCard = Treasure:new(self.name, suit, number)
  return newCard
end

return { EquipCard, Weapon, Armor, DefensiveRide, OffensiveRide, Treasure }
