-- load types for extension

dofile "lua/server/event.lua"
dofile "lua/server/system_enum.lua"
TriggerSkill = require "core.skill_type.trigger"
ActiveSkill = require "core.skill_type.active"
ViewAsSkill = require "core.skill_type.view_as"
DistanceSkill = require "core.skill_type.distance"
ProhibitSkill = require "core.skill_type.prohibit"
AttackRangeSkill = require "core.skill_type.attack_range"
MaxCardsSkill = require "core.skill_type.max_cards"

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
---@field on_cost TrigFunc
---@field on_use TrigFunc
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
  skill.mute = spec.mute
  skill.anim_type = spec.anim_type

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

  if spec.on_cost then skill.cost = spec.on_cost end
  if spec.on_use then skill.use = spec.on_use end

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
---@field on_nullified fun(self: ActiveSkill, room: Room, cardEffectEvent: CardEffectEvent): boolean

---@param spec ActiveSkillSpec
---@return ActiveSkill
function fk.CreateActiveSkill(spec)
  assert(type(spec.name) == "string")
  local skill = ActiveSkill:new(spec.name)
  skill.mute = spec.mute
  skill.anim_type = spec.anim_type
  if spec.can_use then skill.canUse = spec.can_use end
  if spec.card_filter then skill.cardFilter = spec.card_filter end
  if spec.target_filter then skill.targetFilter = spec.target_filter end
  if spec.feasible then skill.feasible = spec.feasible end
  if spec.on_use then skill.onUse = spec.on_use end
  if spec.on_effect then skill.onEffect = spec.on_effect end
  if spec.on_nullified then skill.onNullified = spec.on_nullified end
  return skill
end

---@class ViewAsSkillSpec: SkillSpec
---@field card_filter fun(self: ViewAsSkill, to_select: integer, selected: integer[]): boolean
---@field view_as fun(self: ViewAsSkill, cards: integer[])
---@field pattern string
---@field enabled_at_play fun(self: ViewAsSkill, player: Player): boolean
---@field enabled_at_response fun(self: ViewAsSkill, player: Player): boolean

---@param spec ViewAsSkillSpec
---@return ViewAsSkill
function fk.CreateViewAsSkill(spec)
  assert(type(spec.name) == "string")
  assert(type(spec.view_as) == "function")

  local skill = ViewAsSkill:new(spec.name)
  skill.mute = spec.mute
  skill.anim_type = spec.anim_type
  skill.viewAs = spec.view_as
  if spec.card_filter then
    skill.cardFilter = spec.card_filter
  end
  if type(spec.pattern) == "string" then
    skill.pattern = spec.pattern
  end
  if type(spec.enabled_at_play) == "function" then
    skill.enabledAtPlay = spec.enabled_at_play
  end
  if type(spec.enabled_at_response) == "function" then
    skill.enabledAtResponse = spec.enabled_at_response
  end

  return skill
end

---@class DistanceSpec: SkillSpec
---@field correct_func fun(self: DistanceSkill, from: Player, to: Player)
---@field global boolean

---@param spec DistanceSpec
---@return DistanceSkill
function fk.CreateDistanceSkill(spec)
  assert(type(spec.name) == "string")
  assert(type(spec.correct_func) == "function")

  local skill = DistanceSkill:new(spec.name)
  skill.getCorrect = spec.correct_func
  if spec.global then
    skill.global = spec.global
  end

  return skill
end

---@class ProhibitSpec: SkillSpec
---@field is_prohibited fun(self: ProhibitSkill, from: Player, to: Player, card: Card)
---@field global boolean

---@param spec ProhibitSpec
---@return ProhibitSkill
function fk.CreateProhibitSkill(spec)
  assert(type(spec.name) == "string")
  assert(type(spec.is_prohibited) == "function")

  local skill = ProhibitSkill:new(spec.name)
  skill.isProhibited = spec.is_prohibited
  if spec.global then
    skill.global = spec.global
  end

  return skill
end

---@class AttackRangeSpec: SkillSpec
---@field correct_func fun(self: AttackRangeSkill, from: Player, to: Player)
---@field global boolean

---@param spec AttackRangeSpec
---@return AttackRangeSkill
function fk.CreateAttackRangeSkill(spec)
  assert(type(spec.name) == "string")
  assert(type(spec.correct_func) == "function")

  local skill = AttackRangeSkill:new(spec.name)
  skill.getCorrect = spec.correct_func
  if spec.global then
    skill.global = spec.global
  end

  return skill
end

---@class MaxCardsSpec: SkillSpec
---@field correct_func fun(self: MaxCardsSkill, player: Player)
---@field fixed_func fun(self: MaxCardsSkill, from: Player)
---@field global boolean

---@param spec MaxCardsSpec
---@return MaxCardsSkill
function fk.CreateMaxCardsSkill(spec)
  assert(type(spec.name) == "string")
  assert(type(spec.correct_func) == "function" or type(spec.fixed_func) == "function")

  local skill = MaxCardsSkill:new(spec.name)
  if spec.correct_func then
    skill.getCorrect = spec.correct_func
  end
  if spec.fixed_func then
    skill.getFixed = spec.fixed_func
  end
  if spec.global then
    skill.global = spec.global
  end

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
