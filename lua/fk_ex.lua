-- load types for extension

dofile "lua/server/event.lua"
dofile "lua/server/system_enum.lua"
TriggerSkill = require "core.skill_type.trigger"
ActiveSkill = require "core.skill_type.active_skill"

BasicCard = require "core.card_type.basic"
local Trick = require "core.card_type.trick"
TrickCard, DelayedTrickCard = table.unpack(Trick)
local Equip = require "core.card_type.equip"
_, Weapon, Armor, DefensiveRide, OffensiveRide, Treasure = table.unpack(Equip)

---@class SkillSpec: Skill

---@alias TrigFunc fun(self: TriggerSkill, event: Event, target: ServerPlayer, player: ServerPlayer):boolean
---@class TriggerSkillSpec: SkillSpec
---@field global boolean
---@field events Event | Event[]
---@field refresh_events Event | Event[]
---@field priority number | table<Event, number>
---@field on_trigger TrigFunc
---@field can_trigger TrigFunc
---@field on_refresh TrigFunc
---@field can_refresh TrigFunc

---@param spec TriggerSkillSpec
---@return TriggerSkill
function fk.CreateTriggerSkill(spec)
  assert(type(spec.name) == "string")
  --assert(type(spec.on_trigger) == "function")
  if spec.frequency then assert(type(spec.frequency) == "number") end

  local frequency = spec.frequency or Skill.NotFrequent
  local skill = TriggerSkill:new(spec.name, frequency)

  if type(spec.events) == "number" then
    table.insert(skill.events, spec.events)
  elseif type(spec.events) == "table" then
    table.insertTable(skill.events, spec.events)
  end

  if type(spec.refresh_events) == "number" then
    table.insert(skill.refresh_events, spec.refresh_events)
  elseif type(spec.refresh_events) == "table" then
    table.insertTable(skill.refresh_events, spec.refresh_events)
  end

  if type(spec.global) == "boolean" then skill.global = spec.global end

  if spec.on_trigger then skill.trigger = spec.on_trigger end

  if spec.can_trigger then
    skill.triggerable = spec.can_trigger
  end

  if spec.can_refresh then
    skill.canRefresh = spec.can_refresh
  end

  if spec.on_refresh then
    skill.refresh = spec.on_refresh
  end

  if not spec.priority then
    if frequency == Skill.Wake then
      spec.priority = 3
    elseif frequency == Skill.Compulsory then
      spec.priority = 2
    else
      spec.priority = 1
    end
  end
  if type(spec.priority) == "number" then
    for _, event in ipairs(skill.events) do
      skill.priority_table[event] = spec.priority
    end
  elseif type(spec.priority) == "table" then
    for event, priority in pairs(spec.priority) do
      skill.priority_table[event] = priority
    end
  end
  return skill
end

---@class ActiveSkillSpec: SkillSpec
---@field can_use fun(self: ActiveSkill, player: Player): boolean
---@field card_filter fun(self: ActiveSkill, to_select: integer, selected: integer[], selected_targets: integer[]): boolean
---@field target_filter fun(self: ActiveSkill, to_select: integer, selected: integer[], selected_cards: integer[]): boolean
---@field feasible fun(self: ActiveSkill, selected: integer[], selected_cards: integer[]): boolean
---@field on_use fun(self: ActiveSkill, room: Room, cardUseEvent: CardUseStruct): boolean
---@field on_effect fun(self: ActiveSkill, room: Room, cardEffectEvent: CardEffectEvent): boolean

---@param spec ActiveSkillSpec
---@return ActiveSkill
function fk.CreateActiveSkill(spec)
  assert(type(spec.name) == "string")
  local skill = ActiveSkill:new(spec.name)
  if spec.can_use then skill.canUse = spec.can_use end
  if spec.card_filter then skill.cardFilter = spec.card_filter end
  if spec.target_filter then skill.targetFilter = spec.target_filter end
  if spec.feasible then skill.feasible = spec.feasible end
  if spec.on_use then skill.onUse = spec.on_use end
  if spec.on_effect then skill.onEffect = spec.on_effect end
  return skill
end

---@class CardSpec: Card
---@field skill Skill

local defaultCardSkill = fk.CreateActiveSkill{
  name = "default_card_skill",
  on_use = function(self, room, use)
    if not use.tos or #TargetGroup:getRealTargets(use.tos) == 0 then
      use.tos = { { use.from } }
    end
  end
}

---@param spec CardSpec
---@return BasicCard
function fk.CreateBasicCard(spec)
  assert(type(spec.name) == "string" or type(spec.class_name) == "string")
  if not spec.name then spec.name = spec.class_name
  elseif not spec.class_name then spec.class_name = spec.name end
  if spec.suit then assert(type(spec.suit) == "number") end
  if spec.number then assert(type(spec.number) == "number") end

  local card = BasicCard:new(spec.name, spec.suit, spec.number)
  card.skill = spec.skill or defaultCardSkill
  return card
end

---@param spec CardSpec
---@return TrickCard
function fk.CreateTrickCard(spec)
  assert(type(spec.name) == "string" or type(spec.class_name) == "string")
  if not spec.name then spec.name = spec.class_name
  elseif not spec.class_name then spec.class_name = spec.name end
  if spec.suit then assert(type(spec.suit) == "number") end
  if spec.number then assert(type(spec.number) == "number") end

  local card = TrickCard:new(spec.name, spec.suit, spec.number)  
  card.skill = spec.skill or defaultCardSkill
  return card
end

---@param spec CardSpec
---@return DelayedTrickCard
function fk.CreateDelayedTrickCard(spec)
  assert(type(spec.name) == "string" or type(spec.class_name) == "string")
  if not spec.name then spec.name = spec.class_name
  elseif not spec.class_name then spec.class_name = spec.name end
  if spec.suit then assert(type(spec.suit) == "number") end
  if spec.number then assert(type(spec.number) == "number") end

  local card = DelayedTrickCard:new(spec.name, spec.suit, spec.number)
  card.skill = spec.skill or defaultCardSkill
  return card
end

---@param spec CardSpec
---@return Weapon
function fk.CreateWeapon(spec)
  assert(type(spec.name) == "string" or type(spec.class_name) == "string")
  if not spec.name then spec.name = spec.class_name
  elseif not spec.class_name then spec.class_name = spec.name end
  if spec.suit then assert(type(spec.suit) == "number") end
  if spec.number then assert(type(spec.number) == "number") end
  if spec.attack_range then assert(type(spec.attack_range) == "number" and spec.attack_range >= 0) end

  local card = Weapon:new(spec.name, spec.suit, spec.number, spec.attack_range)
  card.skill = spec.skill or defaultCardSkill
  return card
end

---@param spec CardSpec
---@return Armor
function fk.CreateArmor(spec)
  assert(type(spec.name) == "string" or type(spec.class_name) == "string")
  if not spec.name then spec.name = spec.class_name
  elseif not spec.class_name then spec.class_name = spec.name end
  if spec.suit then assert(type(spec.suit) == "number") end
  if spec.number then assert(type(spec.number) == "number") end

  local card = Armor:new(spec.name, spec.suit, spec.number)
  card.skill = spec.skill or defaultCardSkill
  return card
end

---@param spec CardSpec
---@return DefensiveRide
function fk.CreateDefensiveRide(spec)
  assert(type(spec.name) == "string" or type(spec.class_name) == "string")
  if not spec.name then spec.name = spec.class_name
  elseif not spec.class_name then spec.class_name = spec.name end
  if spec.suit then assert(type(spec.suit) == "number") end
  if spec.number then assert(type(spec.number) == "number") end

  local card = DefensiveRide:new(spec.name, spec.suit, spec.number)
  card.skill = spec.skill or defaultCardSkill
  return card
end

---@param spec CardSpec
---@return OffensiveRide
function fk.CreateOffensiveRide(spec)
  assert(type(spec.name) == "string" or type(spec.class_name) == "string")
  if not spec.name then spec.name = spec.class_name
  elseif not spec.class_name then spec.class_name = spec.name end
  if spec.suit then assert(type(spec.suit) == "number") end
  if spec.number then assert(type(spec.number) == "number") end

  local card = OffensiveRide:new(spec.name, spec.suit, spec.number)
  card.skill = spec.skill or defaultCardSkill
  return card
end

---@param spec CardSpec
---@return Treasure
function fk.CreateTreasure(spec)
  assert(type(spec.name) == "string" or type(spec.class_name) == "string")
  if not spec.name then spec.name = spec.class_name
  elseif not spec.class_name then spec.class_name = spec.name end
  if spec.suit then assert(type(spec.suit) == "number") end
  if spec.number then assert(type(spec.number) == "number") end

  local card = Treasure:new(spec.name, spec.suit, spec.number)
  card.skill = spec.skill or defaultCardSkill
  return card
end
