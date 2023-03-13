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
TargetModSkill = require "core.skill_type.target_mod"
FilterSkill = require "core.skill_type.filter"

BasicCard = require "core.card_type.basic"
local Trick = require "core.card_type.trick"
TrickCard, DelayedTrickCard = table.unpack(Trick)
local Equip = require "core.card_type.equip"
_, Weapon, Armor, DefensiveRide, OffensiveRide, Treasure = table.unpack(Equip)

local function readCommonSpecToSkill(skill, spec)
  skill.mute = spec.mute
  skill.anim_type = spec.anim_type

  if spec.attached_equip then
    assert(type(spec.attached_equip) == "string")
    skill.attached_equip = spec.attached_equip
  end
end

local function readUsableSpecToSkill(skill, spec)
  readCommonSpecToSkill(skill, spec)
  skill.target_num = spec.target_num or skill.target_num
  skill.min_target_num = spec.min_target_num or skill.min_target_num
  skill.max_target_num = spec.max_target_num or skill.max_target_num
  skill.target_num_table = spec.target_num_table or skill.target_num_table
  skill.card_num = spec.card_num or skill.card_num
  skill.min_card_num = spec.min_card_num or skill.min_card_num
  skill.max_card_num = spec.max_card_num or skill.max_card_num
  skill.card_num_table = spec.card_num_table or skill.card_num_table
  skill.max_use_time = {
    spec.max_phase_use_time or 9999,
    spec.max_turn_use_time or 9999,
    spec.max_round_use_time or 9999,
    spec.max_game_use_time or 9999,
  }
  skill.distance_limit = spec.distance_limit or skill.distance_limit
  skill.expand_pile = spec.expand_pile
end

local function readStatusSpecToSkill(skill, spec)
  readCommonSpecToSkill(skill, spec)
  if spec.global then
    skill.global = spec.global
  end
end

---@class UsableSkillSpec: UsableSkill
---@field max_phase_use_time integer
---@field max_turn_use_time integer
---@field max_round_use_time integer
---@field max_game_use_time integer

---@class StatusSkillSpec: StatusSkill

---@alias TrigFunc fun(self: TriggerSkill, event: Event, target: ServerPlayer, player: ServerPlayer):boolean
---@class TriggerSkillSpec: UsableSkillSpec
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
  readUsableSpecToSkill(skill, spec)

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

  if spec.attached_equip then
    if not spec.priority then
      spec.priority = 0.1
    end
  elseif not spec.priority then
    spec.priority = 1
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

---@class ActiveSkillSpec: UsableSkillSpec
---@field can_use fun(self: ActiveSkill, player: Player): boolean
---@field card_filter fun(self: ActiveSkill, to_select: integer, selected: integer[], selected_targets: integer[]): boolean
---@field target_filter fun(self: ActiveSkill, to_select: integer, selected: integer[], selected_cards: integer[]): boolean
---@field feasible fun(self: ActiveSkill, selected: integer[], selected_cards: integer[]): boolean
---@field on_use fun(self: ActiveSkill, room: Room, cardUseEvent: CardUseStruct): boolean
---@field about_to_effect fun(self: ActiveSkill, room: Room, cardEffectEvent: CardEffectEvent): boolean
---@field on_effect fun(self: ActiveSkill, room: Room, cardEffectEvent: CardEffectEvent): boolean
---@field on_nullified fun(self: ActiveSkill, room: Room, cardEffectEvent: CardEffectEvent): boolean

---@param spec ActiveSkillSpec
---@return ActiveSkill
function fk.CreateActiveSkill(spec)
  assert(type(spec.name) == "string")
  local skill = ActiveSkill:new(spec.name)
  readUsableSpecToSkill(skill, spec)

  if spec.can_use then skill.canUse = spec.can_use end
  if spec.card_filter then skill.cardFilter = spec.card_filter end
  if spec.target_filter then skill.targetFilter = spec.target_filter end
  if spec.feasible then
    print(spec.name .. ": feasible is deprecated. Use target_num and card_num instead.")
    skill.feasible = spec.feasible
  end
  if spec.on_use then skill.onUse = spec.on_use end
  if spec.about_to_effect then skill.aboutToEffect = spec.about_to_effect end
  if spec.on_effect then skill.onEffect = spec.on_effect end
  if spec.on_nullified then skill.onNullified = spec.on_nullified end
  return skill
end

---@class ViewAsSkillSpec: UsableSkillSpec
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
  readUsableSpecToSkill(skill, spec)

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

---@class DistanceSpec: StatusSkillSpec
---@field correct_func fun(self: DistanceSkill, from: Player, to: Player)

---@param spec DistanceSpec
---@return DistanceSkill
function fk.CreateDistanceSkill(spec)
  assert(type(spec.name) == "string")
  assert(type(spec.correct_func) == "function")

  local skill = DistanceSkill:new(spec.name)
  readStatusSpecToSkill(skill, spec)
  skill.getCorrect = spec.correct_func

  return skill
end

---@class ProhibitSpec: StatusSkillSpec
---@field is_prohibited fun(self: ProhibitSkill, from: Player, to: Player, card: Card)
---@field prohibit_use fun(self: ProhibitSkill, player: Player, card: Card)
---@field prohibit_response fun(self: ProhibitSkill, player: Player, card: Card)
---@field prohibit_discard fun(self: ProhibitSkill, player: Player, card: Card)

---@param spec ProhibitSpec
---@return ProhibitSkill
function fk.CreateProhibitSkill(spec)
  assert(type(spec.name) == "string")
  assert(type(spec.is_prohibited) == "function")

  local skill = ProhibitSkill:new(spec.name)
  readStatusSpecToSkill(skill, spec)
  skill.isProhibited = spec.is_prohibited or skill.isProhibited
  skill.prohibitUse = spec.prohibit_use or skill.prohibitUse
  skill.prohibitResponse = spec.prohibit_response or skill.prohibitResponse
  skill.prohibitDiscard = spec.prohibit_discard or skill.prohibitDiscard

  return skill
end

---@class AttackRangeSpec: StatusSkillSpec
---@field correct_func fun(self: AttackRangeSkill, from: Player, to: Player)

---@param spec AttackRangeSpec
---@return AttackRangeSkill
function fk.CreateAttackRangeSkill(spec)
  assert(type(spec.name) == "string")
  assert(type(spec.correct_func) == "function")

  local skill = AttackRangeSkill:new(spec.name)
  readStatusSpecToSkill(skill, spec)
  skill.getCorrect = spec.correct_func

  return skill
end

---@class MaxCardsSpec: StatusSkillSpec
---@field correct_func fun(self: MaxCardsSkill, player: Player)
---@field fixed_func fun(self: MaxCardsSkill, from: Player)

---@param spec MaxCardsSpec
---@return MaxCardsSkill
function fk.CreateMaxCardsSkill(spec)
  assert(type(spec.name) == "string")
  assert(type(spec.correct_func) == "function" or type(spec.fixed_func) == "function")

  local skill = MaxCardsSkill:new(spec.name)
  readStatusSpecToSkill(skill, spec)
  if spec.correct_func then
    skill.getCorrect = spec.correct_func
  end
  if spec.fixed_func then
    skill.getFixed = spec.fixed_func
  end

  return skill
end

---@class TargetModSpec: StatusSkillSpec
---@field residue_func fun(self: TargetModSkill, player: Player, skill: ActiveSkill, scope: integer)
---@field distance_limit_func fun(self: TargetModSkill, player: Player, skill: ActiveSkill)
---@field extra_target_func fun(self: TargetModSkill, player: Player, skill: ActiveSkill)

---@param spec TargetModSpec
---@return TargetModSkill
function fk.CreateTargetModSkill(spec)
  assert(type(spec.name) == "string")

  local skill = TargetModSkill:new(spec.name)
  readStatusSpecToSkill(skill, spec)
  if spec.residue_func then
    skill.getResidueNum = spec.residue_func
  end
  if spec.distance_limit_func then
    skill.getDistanceLimit = spec.distance_limit_func
  end
  if spec.extra_target_func then
    skill.getExtraTargetNum = spec.extra_target_func
  end

  return skill
end

---@class FilterSpec: StatusSkillSpec
---@field card_filter fun(self: FilterSkill, card: Card)
---@field view_as fun(self: FilterSkill, card: Card)

---@param spec FilterSpec
---@return FilterSkill
function fk.CreateFilterSkill(spec)
  assert(type(spec.name) == "string")

  local skill = FilterSkill:new(spec.name)
  readStatusSpecToSkill(skill, spec)
  skill.cardFilter = spec.card_filter
  skill.viewAs = spec.view_as

  return skill
end

---@class CardSpec: Card
---@field skill Skill
---@field equip_skill Skill

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
  card.equip_skill = spec.equip_skill

  if spec.on_install then card.onInstall = spec.on_install end
  if spec.on_uninstall then card.onUninstall = spec.on_uninstall end
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
  card.equip_skill = spec.equip_skill

  if spec.on_install then card.onInstall = spec.on_install end
  if spec.on_uninstall then card.onUninstall = spec.on_uninstall end
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
  card.equip_skill = spec.equip_skill

  if spec.on_install then card.onInstall = spec.on_install end
  if spec.on_uninstall then card.onUninstall = spec.on_uninstall end
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
  card.equip_skill = spec.equip_skill

  if spec.on_install then card.onInstall = spec.on_install end
  if spec.on_uninstall then card.onUninstall = spec.on_uninstall end
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
  card.equip_skill = spec.equip_skill

  if spec.on_install then card.onInstall = spec.on_install end
  if spec.on_uninstall then card.onUninstall = spec.on_uninstall end
  return card
end

---@param spec ScenarioSpec
---@return Scenario
function fk.CreateScenario(spec)
  assert(type(spec.name) == "string")
  assert(type(spec.minPlayer) == "number")
  assert(type(spec.maxPlayer) == "number")
  local ret = Scenario:new(spec.name, spec.minPlayer, spec.maxPlayer)
  ret.rule = spec.rule
  ret.logic = spec.logic
  return ret
end
