-- SPDX-License-Identifier: GPL-3.0-or-later

---@class CardSkelSpec: CardSpec
---@field public skill? string
---@field public type? integer
---@field public sub_type? integer
---@field public attack_range? integer

---@class CardSkeleton : Object
---@field public spec CardSkelSpec
local CardSkeleton = class("CardSkeleton")

---@param spec CardSkelSpec
function CardSkeleton:initialize(spec)
  self.spec = spec
end

function CardSkeleton:createCardPrototype()
  local spec = self.spec
  fk.preprocessCardSpec(spec)
  local klass
  local basetype, subtype = spec.type, spec.sub_type
  if basetype == Card.TypeBasic then
    klass = BasicCard
  elseif basetype == Card.TypeTrick then
    if subtype == Card.SubtypeDelayedTrick then
      klass = DelayedTrickCard
    else
      klass = TrickCard
    end
  else
    if subtype == Card.SubtypeWeapon then
      klass = Weapon
    elseif subtype == Card.SubtypeArmor then
      klass = Armor
    elseif subtype == Card.SubtypeDefensiveRide then
      klass = DefensiveRide
    elseif subtype == Card.SubtypeOffensiveRide then
      klass = OffensiveRide
    elseif subtype == Card.SubtypeTreasure then
      klass = Treasure
    end
  end

  if not klass then
    fk.qCritical("unknown card type or sub_type!")
    return nil
  end

  local card
  if klass == Weapon then
    card = klass:new(spec.name, spec.suit, spec.number, spec.attack_range)
  else
    card = klass:new(spec.name, spec.suit, spec.number)
  end

  fk.readCardSpecToCard(card, spec)

  if card.type == Card.TypeEquip then
    fk.readCardSpecToEquip(card, spec)
    if klass == Weapon then
      ---@cast spec +WeaponSpec
      if spec.dynamic_attack_range then
        assert(type(spec.dynamic_attack_range) == "function")
        card.dynamicAttackRange = spec.dynamic_attack_range
      end
    end
  end

  return card
end

---@param spec CardSkelSpec
---@return CardSkeleton
function fk.CreateCard(spec)
  return CardSkeleton:new(spec)
end

return CardSkeleton
