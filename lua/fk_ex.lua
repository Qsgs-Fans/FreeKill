-- SPDX-License-Identifier: GPL-3.0-or-later

-- fk_ex.lua对标太阳神三国杀的sgs_ex.lua
-- 目的是提供类似太阳神三国杀拓展般的拓展语法。
-- 关于各种CreateXXXSkill的介绍，请见相应文档，这里不做赘述。

-- 首先加载所有详细的技能类型、卡牌类型等等，以及时机列表
dofile "lua/server/event.lua"
dofile "lua/server/system_enum.lua"
dofile "lua/server/mark_enum.lua"
TriggerSkill = require "core.skill_type.trigger"
ActiveSkill = require "core.skill_type.active"
ViewAsSkill = require "core.skill_type.view_as"
DistanceSkill = require "core.skill_type.distance"
ProhibitSkill = require "core.skill_type.prohibit"
AttackRangeSkill = require "core.skill_type.attack_range"
MaxCardsSkill = require "core.skill_type.max_cards"
TargetModSkill = require "core.skill_type.target_mod"
FilterSkill = require "core.skill_type.filter"
InvaliditySkill = require "lua.core.skill_type.invalidity"
VisibilitySkill = require "lua.core.skill_type.visibility"

BasicCard = require "core.card_type.basic"
local Trick = require "core.card_type.trick"
TrickCard, DelayedTrickCard = table.unpack(Trick)
local Equip = require "core.card_type.equip"
_, Weapon, Armor, DefensiveRide, OffensiveRide, Treasure = table.unpack(Equip)

function fk.readCommonSpecToSkill(skill, spec)
  skill.mute = spec.mute
  skill.no_indicate = spec.no_indicate
  skill.anim_type = spec.anim_type

  if spec.attached_equip then
    assert(type(spec.attached_equip) == "string")
    skill.attached_equip = spec.attached_equip
  end

  if spec.switch_skill_name then
    assert(type(spec.switch_skill_name) == "string")
    skill.switchSkillName = spec.switch_skill_name
  end

  if spec.relate_to_place then
    assert(type(spec.relate_to_place) == "string")
    skill.relate_to_place = spec.relate_to_place
  end

  if spec.on_acquire then
    assert(type(spec.on_acquire) == "function")
    skill.onAcquire = spec.on_acquire
  end

  if spec.on_lose then
    assert(type(spec.on_lose) == "function")
    skill.onLose = spec.on_lose
  end
end

function fk.readUsableSpecToSkill(skill, spec)
  fk.readCommonSpecToSkill(skill, spec)
  assert(spec.main_skill == nil or spec.main_skill:isInstanceOf(UsableSkill))
  if type(spec.derived_piles) == "string" then
    skill.derived_piles = {spec.derived_piles}
  else
    skill.derived_piles = spec.derived_piles or {}
  end
  skill.main_skill = spec.main_skill
  skill.attached_skill_name = spec.attached_skill_name
  skill.target_num = spec.target_num or skill.target_num
  skill.min_target_num = spec.min_target_num or skill.min_target_num
  skill.max_target_num = spec.max_target_num or skill.max_target_num
  skill.target_num_table = spec.target_num_table or skill.target_num_table
  skill.card_num = spec.card_num or skill.card_num
  skill.min_card_num = spec.min_card_num or skill.min_card_num
  skill.max_card_num = spec.max_card_num or skill.max_card_num
  skill.card_num_table = spec.card_num_table or skill.card_num_table
  skill.max_use_time = {
    spec.max_phase_use_time,
    spec.max_turn_use_time,
    spec.max_round_use_time,
    spec.max_game_use_time,
  }
  skill.distance_limit = spec.distance_limit or skill.distance_limit
  skill.expand_pile = spec.expand_pile
  skill.times = spec.times or skill.times
end

function fk.readStatusSpecToSkill(skill, spec)
  fk.readCommonSpecToSkill(skill, spec)
  if spec.global then
    skill.global = spec.global
  end
end

---@class SkillSpec
---@field public name string @ 技能名
---@field public frequency? Frequency @ 技能发动的频繁程度，通常compulsory（锁定技）及limited（限定技）用的多。
---@field public mute? boolean @ 决定是否关闭技能配音
---@field public no_indicate? boolean @ 决定是否关闭技能指示线
---@field public anim_type? string|AnimationType @ 技能类型定义
---@field public global? boolean @ 决定是否是全局技能
---@field public attached_equip? string @ 属于什么装备的技能？
---@field public switch_skill_name? string @ 转换技名字
---@field public relate_to_place? string @ 主将技/副将技
---@field public on_acquire? fun(self: UsableSkill, player: ServerPlayer, is_start: boolean)
---@field public on_lose? fun(self: UsableSkill, player: ServerPlayer, is_death: boolean)
---@field public attached_skill_name? string @ 给其他角色添加技能的名称

---@class UsableSkillSpec: SkillSpec
---@field public main_skill? UsableSkill
---@field public max_use_time? integer[]
---@field public expand_pile? string | integer[] | fun(self: UsableSkill): integer[]|string?
---@field public derived_piles? string | string[]
---@field public max_phase_use_time? integer
---@field public max_turn_use_time? integer
---@field public max_round_use_time? integer
---@field public max_game_use_time? integer
---@field public times? integer | fun(self: UsableSkill): integer
---@field public min_target_num? integer
---@field public max_target_num? integer
---@field public target_num? integer
---@field public target_num_table? integer[]
---@field public min_card_num? integer
---@field public max_card_num? integer
---@field public card_num? integer
---@field public card_num_table? integer[]

---@class StatusSkillSpec: SkillSpec

---@alias TrigFunc fun(self: TriggerSkill, event: Event, target: ServerPlayer, player: ServerPlayer, data: any): any
---@class TriggerSkillSpec: UsableSkillSpec
---@field public global? boolean
---@field public events? Event | Event[]
---@field public refresh_events? Event | Event[]
---@field public priority? number | table<Event, number>
---@field public on_trigger? TrigFunc
---@field public can_trigger? TrigFunc
---@field public on_cost? TrigFunc
---@field public on_use? TrigFunc
---@field public on_refresh? TrigFunc
---@field public can_refresh? TrigFunc
---@field public can_wake? TrigFunc

---@param spec TriggerSkillSpec
---@return TriggerSkill
function fk.CreateTriggerSkill(spec)
  assert(type(spec.name) == "string")
  --assert(type(spec.on_trigger) == "function")
  if spec.frequency then assert(type(spec.frequency) == "number") end

  local frequency = spec.frequency or Skill.NotFrequent
  local skill = TriggerSkill:new(spec.name, frequency)
  fk.readUsableSpecToSkill(skill, spec)

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
    if spec.frequency == Skill.Wake then
      skill.triggerable = function(self, event, target, player, data)
        return spec.can_trigger(self, event, target, player, data) and
          skill:enableToWake(event, target, player, data)
      end
    else
      skill.triggerable = spec.can_trigger
    end
  end

  if skill.frequency == Skill.Wake and spec.can_wake then
    skill.canWake = spec.can_wake
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
---@field public can_use? fun(self: ActiveSkill, player: Player, card?: Card, extra_data: any): any
---@field public card_filter? fun(self: ActiveSkill, to_select: integer, selected: integer[], selected_targets: integer[]): any
---@field public target_filter? fun(self: ActiveSkill, to_select: integer, selected: integer[], selected_cards: integer[], card?: Card, extra_data: any): any
---@field public feasible? fun(self: ActiveSkill, selected: integer[], selected_cards: integer[]): any
---@field public on_use? fun(self: ActiveSkill, room: Room, cardUseEvent: CardUseStruct | SkillEffectEvent): any
---@field public on_action? fun(self: ActiveSkill, room: Room, cardUseEvent: CardUseStruct | SkillEffectEvent, finished: boolean): any
---@field public about_to_effect? fun(self: ActiveSkill, room: Room, cardEffectEvent: CardEffectEvent | SkillEffectEvent): any
---@field public on_effect? fun(self: ActiveSkill, room: Room, cardEffectEvent: CardEffectEvent | SkillEffectEvent): any
---@field public on_nullified? fun(self: ActiveSkill, room: Room, cardEffectEvent: CardEffectEvent | SkillEffectEvent): any
---@field public mod_target_filter? fun(self: ActiveSkill, to_select: integer, selected: integer[], user: integer, card?: Card, distance_limited: boolean): any
---@field public prompt? string|fun(self: ActiveSkill, selected_cards: integer[], selected_targets: integer[]): string
---@field public interaction? any
---@field public target_tip? fun(self: ActiveSkill, to_select: integer, selected: integer[], selected_cards: integer[], card?: Card, selectable: boolean, extra_data: any): string|TargetTipDataSpec?

---@param spec ActiveSkillSpec
---@return ActiveSkill
function fk.CreateActiveSkill(spec)
  assert(type(spec.name) == "string")
  local skill = ActiveSkill:new(spec.name, spec.frequency or Skill.NotFrequent)
  fk.readUsableSpecToSkill(skill, spec)

  if spec.can_use then
    skill.canUse = function(curSkill, player, card, extra_data)
      return spec.can_use(curSkill, player, card, extra_data) and curSkill:isEffectable(player)
    end
  end
  if spec.card_filter then skill.cardFilter = spec.card_filter end
  if spec.target_filter then skill.targetFilter = spec.target_filter end
  if spec.mod_target_filter then skill.modTargetFilter = spec.mod_target_filter end
  if spec.feasible then
    -- print(spec.name .. ": feasible is deprecated. Use target_num and card_num instead.")
    skill.feasible = spec.feasible
  end
  if spec.on_use then skill.onUse = spec.on_use end
  if spec.on_action then skill.onAction = spec.on_action end
  if spec.about_to_effect then skill.aboutToEffect = spec.about_to_effect end
  if spec.on_effect then skill.onEffect = spec.on_effect end
  if spec.on_nullified then skill.onNullified = spec.on_nullified end
  if spec.prompt then skill.prompt = spec.prompt end
  if spec.target_tip then skill.targetTip = spec.target_tip end

  if spec.interaction then
    skill.interaction = setmetatable({}, {
      __call = function()
        if type(spec.interaction) == "function" then
          return spec.interaction(skill)
        else
          return spec.interaction
        end
      end,
    })
  end
  return skill
end

---@class ViewAsSkillSpec: UsableSkillSpec
---@field public card_filter? fun(self: ViewAsSkill, to_select: integer, selected: integer[]): any
---@field public view_as fun(self: ViewAsSkill, cards: integer[]): Card?
---@field public pattern? string
---@field public enabled_at_play? fun(self: ViewAsSkill, player: Player): any
---@field public enabled_at_response? fun(self: ViewAsSkill, player: Player, response: boolean): any
---@field public before_use? fun(self: ViewAsSkill, player: ServerPlayer, use: CardUseStruct): string?
---@field public after_use? fun(self: ViewAsSkill, player: ServerPlayer, use: CardUseStruct): string?
---@field public prompt? string|fun(self: ActiveSkill, selected_cards: integer[], selected: integer[]): string
---@field public interaction? any

---@param spec ViewAsSkillSpec
---@return ViewAsSkill
function fk.CreateViewAsSkill(spec)
  assert(type(spec.name) == "string")
  assert(type(spec.view_as) == "function")

  local skill = ViewAsSkill:new(spec.name, spec.frequency or Skill.NotFrequent)
  fk.readUsableSpecToSkill(skill, spec)

  skill.viewAs = spec.view_as
  if spec.card_filter then
    skill.cardFilter = spec.card_filter
  end
  if type(spec.pattern) == "string" then
    skill.pattern = spec.pattern
  end
  if type(spec.enabled_at_play) == "function" then
    skill.enabledAtPlay = function(curSkill, player)
      return spec.enabled_at_play(curSkill, player) and curSkill:isEffectable(player)
    end
  end
  if type(spec.enabled_at_response) == "function" then
    skill.enabledAtResponse = function(curSkill, player, cardResponsing)
      return spec.enabled_at_response(curSkill, player, cardResponsing) and curSkill:isEffectable(player)
    end
  end
  if spec.prompt then skill.prompt = spec.prompt end

  if spec.interaction then
    skill.interaction = setmetatable({}, {
      __call = function()
        if type(spec.interaction) == "function" then
          return spec.interaction(skill)
        else
          return spec.interaction
        end
      end,
    })
  end

  if spec.before_use and type(spec.before_use) == "function" then
    skill.beforeUse = spec.before_use
  end

  if spec.after_use and type(spec.after_use) == "function" then
    skill.afterUse = spec.after_use
  end

  return skill
end

---@class DistanceSpec: StatusSkillSpec
---@field public correct_func? fun(self: DistanceSkill, from: Player, to: Player): integer?
---@field public fixed_func? fun(self: DistanceSkill, from: Player, to: Player): integer?

---@param spec DistanceSpec
---@return DistanceSkill
function fk.CreateDistanceSkill(spec)
  assert(type(spec.name) == "string")
  assert(type(spec.correct_func) == "function" or type(spec.fixed_func) == "function")

  local skill = DistanceSkill:new(spec.name)
  fk.readStatusSpecToSkill(skill, spec)
  skill.getCorrect = spec.correct_func
  skill.getFixed = spec.fixed_func

  return skill
end

---@class ProhibitSpec: StatusSkillSpec
---@field public is_prohibited? fun(self: ProhibitSkill, from: Player, to: Player, card: Card): any
---@field public prohibit_use? fun(self: ProhibitSkill, player: Player, card: Card): any
---@field public prohibit_response? fun(self: ProhibitSkill, player: Player, card: Card): any
---@field public prohibit_discard? fun(self: ProhibitSkill, player: Player, card: Card): any
---@field public prohibit_pindian? fun(self: ProhibitSkill, from: Player, to: Player): any

---@param spec ProhibitSpec
---@return ProhibitSkill
function fk.CreateProhibitSkill(spec)
  assert(type(spec.name) == "string")

  local skill = ProhibitSkill:new(spec.name)
  fk.readStatusSpecToSkill(skill, spec)
  skill.isProhibited = spec.is_prohibited or skill.isProhibited
  skill.prohibitUse = spec.prohibit_use or skill.prohibitUse
  skill.prohibitResponse = spec.prohibit_response or skill.prohibitResponse
  skill.prohibitDiscard = spec.prohibit_discard or skill.prohibitDiscard
  skill.prohibitPindian = spec.prohibit_pindian or skill.prohibitPindian

  return skill
end

---@class AttackRangeSpec: StatusSkillSpec
---@field public correct_func? fun(self: AttackRangeSkill, from: Player, to: Player): number?
---@field public fixed_func? fun(self: AttackRangeSkill, player: Player): number?
---@field public within_func? fun(self: AttackRangeSkill, from: Player, to: Player): any
---@field public without_func? fun(self: AttackRangeSkill, from: Player, to: Player): any

---@param spec AttackRangeSpec
---@return AttackRangeSkill
function fk.CreateAttackRangeSkill(spec)
  assert(type(spec.name) == "string")
  assert(type(spec.correct_func) == "function" or type(spec.fixed_func) == "function" or
    type(spec.within_func) == "function" or type(spec.without_func) == "function")

  local skill = AttackRangeSkill:new(spec.name)
  fk.readStatusSpecToSkill(skill, spec)
  if spec.correct_func then
    skill.getCorrect = spec.correct_func
  end
  if spec.fixed_func then
    skill.getFixed = spec.fixed_func
  end
  if spec.within_func then
    skill.withinAttackRange = spec.within_func
  end
  if spec.without_func then
    skill.withoutAttackRange = spec.without_func
  end

  return skill
end

---@class MaxCardsSpec: StatusSkillSpec
---@field public correct_func? fun(self: MaxCardsSkill, player: Player): number?
---@field public fixed_func? fun(self: MaxCardsSkill, player: Player): number?
---@field public exclude_from? fun(self: MaxCardsSkill, player: Player, card: Card): any

---@param spec MaxCardsSpec
---@return MaxCardsSkill
function fk.CreateMaxCardsSkill(spec)
  assert(type(spec.name) == "string")
  assert(type(spec.correct_func) == "function" or type(spec.fixed_func) == "function" or type(spec.exclude_from) == "function")

  local skill = MaxCardsSkill:new(spec.name)
  fk.readStatusSpecToSkill(skill, spec)
  if spec.correct_func then
    skill.getCorrect = spec.correct_func
  end
  if spec.fixed_func then
    skill.getFixed = spec.fixed_func
  end
  skill.excludeFrom = spec.exclude_from or skill.excludeFrom

  return skill
end

---@class TargetModSpec: StatusSkillSpec
---@field public bypass_times? fun(self: TargetModSkill, player: Player, skill: ActiveSkill, scope: integer, card?: Card, to?: Player): any
---@field public residue_func? fun(self: TargetModSkill, player: Player, skill: ActiveSkill, scope: integer, card?: Card, to?: Player): number?
---@field public bypass_distances? fun(self: TargetModSkill, player: Player, skill: ActiveSkill, card?: Card, to?: Player): any
---@field public distance_limit_func? fun(self: TargetModSkill, player: Player, skill: ActiveSkill, card?: Card, to?: Player): number?
---@field public extra_target_func? fun(self: TargetModSkill, player: Player, skill: ActiveSkill, card?: Card): number?
---@field public target_tip_func? fun(self: TargetModSkill, player: Player, to_select: integer, selected: integer[], selected_cards: integer[], card?: Card, selectable: boolean, extra_data: any): string|TargetTipDataSpec?

---@param spec TargetModSpec
---@return TargetModSkill
function fk.CreateTargetModSkill(spec)
  assert(type(spec.name) == "string")

  local skill = TargetModSkill:new(spec.name)
  fk.readStatusSpecToSkill(skill, spec)
  if spec.bypass_times then
    skill.bypassTimesCheck = spec.bypass_times
  end
  if spec.residue_func then
    skill.getResidueNum = spec.residue_func
  end
  if spec.bypass_distances then
    skill.bypassDistancesCheck = spec.bypass_distances
  end
  if spec.distance_limit_func then
    skill.getDistanceLimit = spec.distance_limit_func
  end
  if spec.extra_target_func then
    skill.getExtraTargetNum = spec.extra_target_func
  end
  if spec.target_tip_func then
    skill.getTargetTip = spec.target_tip_func
  end

  return skill
end

---@class FilterSpec: StatusSkillSpec
---@field public card_filter? fun(self: FilterSkill, card: Card, player: Player, isJudgeEvent: boolean): any
---@field public view_as? fun(self: FilterSkill, card: Card, player: Player): Card?
---@field public equip_skill_filter? fun(self: FilterSkill, skill: Skill, player: Player): string?

---@param spec FilterSpec
---@return FilterSkill
function fk.CreateFilterSkill(spec)
  assert(type(spec.name) == "string")

  local skill = FilterSkill:new(spec.name)
  fk.readStatusSpecToSkill(skill, spec)
  skill.cardFilter = spec.card_filter
  skill.viewAs = spec.view_as
  skill.equipSkillFilter = spec.equip_skill_filter

  return skill
end

---@class InvaliditySpec: StatusSkillSpec
---@field public invalidity_func? fun(self: InvaliditySkill, from: Player, skill: Skill): any

---@param spec InvaliditySpec
---@return InvaliditySkill
function fk.CreateInvaliditySkill(spec)
  assert(type(spec.name) == "string")

  local skill = InvaliditySkill:new(spec.name)
  fk.readStatusSpecToSkill(skill, spec)
  skill.getInvalidity = spec.invalidity_func

  return skill
end

---@class VisibilitySpec: StatusSkillSpec
---@field public card_visible? fun(self: VisibilitySkill, player: Player, card: Card): any
---@field public role_visible? fun(self: VisibilitySkill, player: Player, target: Player): any

---@param spec VisibilitySpec
function fk.CreateVisibilitySkill(spec)
  assert(type(spec.name) == "string")

  local skill = VisibilitySkill:new(spec.name)
  fk.readStatusSpecToSkill(skill, spec)
  if spec.card_visible then skill.cardVisible = spec.card_visible end
  if spec.role_visible then skill.roleVisible = spec.role_visible end

  return skill
end

---@class CardSpec
---@field public name string @ 卡牌的名字
---@field public suit? Suit @ 卡牌的花色（四色及无花色）
---@field public number? integer @ 卡牌的点数（0到K）
---@field public skill? ActiveSkill
---@field public special_skills? string[]
---@field public is_damage_card? boolean
---@field public multiple_targets? boolean
---@field public is_passive? boolean

local defaultCardSkill = fk.CreateActiveSkill{
  name = "default_card_skill",
  on_use = function(self, room, use)
    if not use.tos or #TargetGroup:getRealTargets(use.tos) == 0 then
      use.tos = { { use.from } }
    end
  end
}

local defaultEquipSkill = fk.CreateActiveSkill{
  name = "default_equip_skill",
  prompt = function(_, selected_cards, _)
    return "#default_equip_skill:::" .. Fk:getCardById(selected_cards).name .. ":" .. Fk:getCardById(selected_cards):getSubtypeString()
  end,
  mod_target_filter = function(self, to_select, selected, user, card, distance_limited)
    return #Fk:currentRoom():getPlayerById(to_select):getAvailableEquipSlots(card.sub_type) > 0
  end,
  can_use = function(self, player, card)
    return self:modTargetFilter(player.id, {}, player.id, card, true) and not player:isProhibited(player, card)
  end,
  on_use = function(self, room, use)
    if not use.tos or #TargetGroup:getRealTargets(use.tos) == 0 then
      use.tos = { { use.from } }
    end
  end
}

local function preprocessCardSpec(spec)
  assert(type(spec.name) == "string" or type(spec.class_name) == "string")
  if not spec.name then spec.name = spec.class_name
  elseif not spec.class_name then spec.class_name = spec.name end
  if spec.suit then assert(type(spec.suit) == "number") end
  if spec.number then assert(type(spec.number) == "number") end
end

local function readCardSpecToCard(card, spec)
  card.skill = spec.skill or (card.type == Card.TypeEquip and defaultEquipSkill or defaultCardSkill)
  card.skill.cardSkill = true
  card.special_skills = spec.special_skills
  card.is_damage_card = spec.is_damage_card
  card.multiple_targets = spec.multiple_targets
  card.is_passive = spec.is_passive
end

---@param spec CardSpec
---@return BasicCard
function fk.CreateBasicCard(spec)
  preprocessCardSpec(spec)
  local card = BasicCard:new(spec.name, spec.suit, spec.number)
  readCardSpecToCard(card, spec)
  return card
end

---@param spec CardSpec
---@return TrickCard
function fk.CreateTrickCard(spec)
  preprocessCardSpec(spec)
  local card = TrickCard:new(spec.name, spec.suit, spec.number)
  readCardSpecToCard(card, spec)
  return card
end

---@param spec CardSpec
---@return DelayedTrickCard
function fk.CreateDelayedTrickCard(spec)
  preprocessCardSpec(spec)
  local card = DelayedTrickCard:new(spec.name, spec.suit, spec.number)
  readCardSpecToCard(card, spec)
  return card
end

---@class EquipCardSpec: CardSpec
---@field public equip_skill? Skill
---@field public dynamic_equip_skills? fun(player: Player): Skill[]
---@field public on_install? fun(self: EquipCard, room: Room, player: ServerPlayer)
---@field public on_uninstall? fun(self: EquipCard, room: Room, player: ServerPlayer)

local function readCardSpecToEquip(card, spec)
  if spec.equip_skill then
    if spec.equip_skill.class and spec.equip_skill:isInstanceOf(Skill) then
      card.equip_skill = spec.equip_skill
      card.equip_skills = { spec.equip_skill }
    else
      card.equip_skill = spec.equip_skill[1]
      card.equip_skills = spec.equip_skill
    end
  end

  if spec.dynamic_equip_skills then
    assert(type(spec.dynamic_equip_skills) == "function")
    card.dynamicEquipSkills = spec.dynamic_equip_skills
  end

  if spec.on_install then card.onInstall = spec.on_install end
  if spec.on_uninstall then card.onUninstall = spec.on_uninstall end
end

---@class WeaponSpec: EquipCardSpec
---@field public attack_range? integer
---@field public dynamic_attack_range? fun(player: Player): int

---@param spec WeaponSpec
---@return Weapon
function fk.CreateWeapon(spec)
  preprocessCardSpec(spec)
  if spec.attack_range then
    assert(type(spec.attack_range) == "number" and spec.attack_range >= 0)
  end

  local card = Weapon:new(spec.name, spec.suit, spec.number, spec.attack_range)
  readCardSpecToCard(card, spec)
  readCardSpecToEquip(card, spec)
  if spec.dynamic_attack_range then
    assert(type(spec.dynamic_attack_range) == "function")
    card.dynamicAttackRange = spec.dynamic_attack_range
  end

  return card
end

---@param spec EquipCardSpec
---@return Armor
function fk.CreateArmor(spec)
  preprocessCardSpec(spec)
  local card = Armor:new(spec.name, spec.suit, spec.number)
  readCardSpecToCard(card, spec)
  readCardSpecToEquip(card, spec)
  return card
end

---@param spec EquipCardSpec
---@return DefensiveRide
function fk.CreateDefensiveRide(spec)
  preprocessCardSpec(spec)
  local card = DefensiveRide:new(spec.name, spec.suit, spec.number)
  readCardSpecToCard(card, spec)
  readCardSpecToEquip(card, spec)
  return card
end

---@param spec EquipCardSpec
---@return OffensiveRide
function fk.CreateOffensiveRide(spec)
  preprocessCardSpec(spec)
  local card = OffensiveRide:new(spec.name, spec.suit, spec.number)
  readCardSpecToCard(card, spec)
  readCardSpecToEquip(card, spec)
  return card
end

---@param spec EquipCardSpec
---@return Treasure
function fk.CreateTreasure(spec)
  preprocessCardSpec(spec)
  local card = Treasure:new(spec.name, spec.suit, spec.number)
  readCardSpecToCard(card, spec)
  readCardSpecToEquip(card, spec)
  return card
end

---@class GameModeSpec: GameMode
---@field public winner_getter? fun(self: GameMode, victim: ServerPlayer): string
---@field public surrender_func? fun(self: GameMode, playedTime: number): table
---@field public is_counted? fun(self: GameMode, room: Room): boolean
---@field public get_adjusted? fun(self: GameMode, player: ServerPlayer): table
---@field public reward_punish? fun(self: GameMode, victim: ServerPlayer, killer?: ServerPlayer)
---@field public build_draw_pile? fun(self: GameMode): integer[], integer[]

---@param spec GameModeSpec
---@return GameMode
function fk.CreateGameMode(spec)
  assert(type(spec.name) == "string")
  assert(type(spec.minPlayer) == "number")
  assert(type(spec.maxPlayer) == "number")
  local ret = GameMode:new(spec.name, spec.minPlayer, spec.maxPlayer)
  ret.whitelist = spec.whitelist
  ret.blacklist = spec.blacklist
  ret.rule = spec.rule
  ret.logic = spec.logic
  ret.main_mode = spec.main_mode or spec.name
  Fk.main_mode_list[ret.main_mode] = Fk.main_mode_list[ret.main_mode] or {}
  table.insert(Fk.main_mode_list[ret.main_mode], ret.name)

  if spec.winner_getter then
    assert(type(spec.winner_getter) == "function")
    ret.getWinner = spec.winner_getter
  end
  if spec.surrender_func then
    assert(type(spec.surrender_func) == "function")
    ret.surrenderFunc = spec.surrender_func
  end
  if spec.is_counted then
    assert(type(spec.is_counted) == "function")
    ret.countInFunc = spec.is_counted
  end
  if spec.get_adjusted then
    assert(type(spec.get_adjusted) == "function")
    ret.getAdjustedProperty = spec.get_adjusted
  end
  if spec.reward_punish then
    assert(type(spec.reward_punish) == "function")
    ret.deathRewardAndPunish = spec.reward_punish
  end
  if spec.build_draw_pile then
    assert(type(spec.build_draw_pile) == "function")
    ret.buildDrawPile = spec.build_draw_pile
  end
  return ret
end

-- other

---@class PoxiSpec
---@field name string
---@field card_filter fun(to_select: int, selected: int[], data: any, extra_data: any): any
---@field feasible fun(selected: int[], data: any, extra_data: any): any
---@field post_select? fun(selected: int[], data: any, extra_data: any): int[]
---@field default_choice? fun(data: any, extra_data: any): int[]
---@field prompt? string | fun(data: any, extra_data: any): string

---@class QmlMarkSpec
---@field name string
---@field qml_path string | fun(name: string, value?: any, player?: Player): string
---@field how_to_show fun(name: string, value?: any, player?: Player): string?

-- TODO: 断连 不操作的人观看 现在只做了专为22设计的框
---@class MiniGameSpec
---@field name string
---@field qml_path string | fun(player: Player, data: any): string
---@field update_func? fun(player: ServerPlayer, data: any)
---@field default_choice? fun(player: ServerPlayer, data: any): any

---@class TargetTipDataSpec
---@field content string
---@field type "normal"|"warning"

---@class TargetTipSpec
---@field name string
---@field target_tip fun(self: ActiveSkill, to_select: integer, selected: integer[], selected_cards: integer[], card: Card, selectable: boolean, extra_data: any): string|TargetTipDataSpec?
