-- SPDX-License-Identifier: GPL-3.0-or-later

---@class EquipCard : Card
---@field public equip_skill Skill
---@field public equip_skills Skill[]
---@field public dynamicEquipSkills fun(player: Player): Skill[]
local EquipCard = Card:subclass("EquipCard")

function EquipCard:initialize(name, suit, number)
  Card.initialize(self, name, suit, number)
  self.type = Card.TypeEquip
  self.equip_skill = nil
  self.equip_skills = nil
  self.dynamicEquipSkills = nil
end

---@param room Room
---@param player Player
function EquipCard:onInstall(room, player)
  local equipSkills = self:getEquipSkills(player)
  if #equipSkills > 0 then
    local noTrigger = table.filter(equipSkills, function(skill) return skill.attached_equip end)
    if #noTrigger > 0 then
      noTrigger = table.map(noTrigger, function(skill) return skill.name end)
      room:handleAddLoseSkills(player, table.concat(noTrigger, "|"), nil, false, true)
    end

    local toTrigger = table.filter(equipSkills, function(skill) return not skill.attached_equip end)
    if #toTrigger > 0 then
      toTrigger = table.map(toTrigger, function(skill) return skill.name end)
      room:handleAddLoseSkills(player, table.concat(toTrigger, "|"), nil, false)
    end
  end
end

---@param room Room
---@param player Player
function EquipCard:onUninstall(room, player)
  local equipSkills = self:getEquipSkills(player)
  if #equipSkills > 0 then
    local noTrigger = table.filter(equipSkills, function(skill) return skill.attached_equip end)
    if #noTrigger > 0 then
      noTrigger = table.map(noTrigger, function(skill) return '-' .. skill.name end)
      room:handleAddLoseSkills(player, table.concat(noTrigger, "|"), nil, false, true)
    end

    local toTrigger = table.filter(equipSkills, function(skill) return not skill.attached_equip end)
    if #toTrigger > 0 then
      toTrigger = table.map(toTrigger, function(skill) return '-' .. skill.name end)
      room:handleAddLoseSkills(player, table.concat(toTrigger, "|"), nil, false)
    end
  end
end

---@param player Player
---@return Skill[]
function EquipCard:getEquipSkills(player)
  if self.dynamicEquipSkills then
    local equipSkills = self:dynamicEquipSkills(player)
    if equipSkills and #equipSkills > 0 then
      return equipSkills
    end
  end

  if self.equip_skills then
    return self.equip_skills
  elseif self.equip_skill then
    return { self.equip_skill }
  end

  return {}
end

function EquipCard:clone(suit, number)
  local ret = Card.clone(self, suit, number) --[[@as EquipCard]]
  ret.equip_skill = self.equip_skill
  ret.equip_skills = self.equip_skills
  ret.dynamicEquipSkills = self.dynamicEquipSkills
  ret.onInstall = self.onInstall
  ret.onUninstall = self.onUninstall
  return ret
end

---@class Weapon : EquipCard
---@field public attack_range integer
---@field public dynamicAttackRange? fun(self: Weapon, player: Player): integer
local Weapon = EquipCard:subclass("Weapon")

function Weapon:initialize(name, suit, number, attackRange)
  EquipCard.initialize(self, name, suit, number)
  self.sub_type = Card.SubtypeWeapon
  self.attack_range = attackRange or 1
end

function Weapon:clone(suit, number)
  local ret = EquipCard.clone(self, suit, number) --[[@as Weapon]]
  ret.attack_range = self.attack_range
  ret.dynamicAttackRange = self.dynamicAttackRange
  return ret
end

--- 获取一个武器牌的攻击范围
---@param player? Player @ 拥有此武器的角色
function Weapon:getAttackRange(player)
  if type(self.dynamicAttackRange) == "function" and player then
    local currentAttackRange = self:dynamicAttackRange(player)
    if currentAttackRange then
      return currentAttackRange
    end
  end

  return self.attack_range
end

--- 判断一个角色的某个武器的攻击范围是否有效
---@param player Player @ 拥有此武器的角色
function Weapon:AvailableAttackRange(player)
  local status_skills = Fk:currentRoom().status_skills[InvaliditySkill] or Util.DummyTable
  for _, skill in ipairs(status_skills) do
    local ret = skill:getInvalidityAttackRange(player, self)
    if ret then
      return false
    end
  end
  return true
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
