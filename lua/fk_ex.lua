-- SPDX-License-Identifier: GPL-3.0-or-later

-- fk_ex.lua对标太阳神三国杀的sgs_ex.lua
-- 目的是提供类似太阳神三国杀拓展般的拓展语法。
-- 关于各种CreateXXXSkill的介绍，请见相应文档，这里不做赘述。

-- 首先加载所有详细的技能类型、卡牌类型等等，以及时机列表

TriggerEvent = require "core.trigger_event"
require "core.events"
dofile "lua/server/event.lua"
dofile "lua/server/system_enum.lua"
dofile "lua/server/mark_enum.lua"
TriggerSkill = require "core.skill_type.trigger"
LegacyTriggerSkill = require "compat.trigger_legacy"
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

dofile "lua/compat/fk_ex.lua"

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

  if spec.dynamic_desc then
    assert(type(spec.dynamic_desc) == "function")
    skill.getDynamicDescription = spec.dynamic_desc
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
---@field public name? string @ 技能名
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
---@field public dynamic_desc? fun(self: UsableSkill, player: Player, lang: string): string
---@field public attached_skill_name? string @ 给其他角色添加技能的名称

---@class SkillSkeleton : Object, SkillSpec
---@field public effect_list ([any, any, any])[]
---@field public ai_list ([string, string, any])[]
---@field public tests fun(room: Room, me: ServerPlayer)[]
---@field public addEffect fun(self: SkillSkeleton, key: 'distance', data: DistanceSpec, attribute: nil)
---@field public addEffect fun(self: SkillSkeleton, key: 'prohibit', data: ProhibitSpec, attribute: nil)
---@field public addEffect fun(self: SkillSkeleton, key: 'atkrange', data: AttackRangeSpec, attribute: nil)
---@field public addEffect fun(self: SkillSkeleton, key: 'maxcards', data: MaxCardsSpec, attribute: nil)
---@field public addEffect fun(self: SkillSkeleton, key: 'targetmod', data: TargetModSpec, attribute: nil)
---@field public addEffect fun(self: SkillSkeleton, key: 'filter', data: FilterSpec, attribute: nil)
---@field public addEffect fun(self: SkillSkeleton, key: 'invalidity', data: InvaliditySpec, attribute: nil)
---@field public addEffect fun(self: SkillSkeleton, key: 'visibility', data: VisibilitySpec, attribute: nil)
---@field public addEffect fun(self: SkillSkeleton, key: 'active', data: ActiveSkillSpec, attribute: nil)
---@field public addEffect fun(self: SkillSkeleton, key: 'viewas', data: ViewAsSkillSpec, attribute: nil)
local SkillSkeleton = class("SkillSkeleton")

---@param spec SkillSpec
function SkillSkeleton:initialize(spec)
  self.name = spec.name
  self.frequency = spec.frequency or Skill.NotFrequent
  fk.readCommonSpecToSkill(self, spec)
  self.effect_list = {}
  self.tests = {}
end

function SkillSkeleton:addEffect(key, data, attribute)
  -- 需要按照顺序插入，active和viewas最先，trigger其次，剩下的随意
  -- 其实决定要不要插在第一个就行了
  -- 'active' 和 'viewas' 必须唯一

  local function getTypePriority(k)
    if k == 'active' or k == 'viewas' then
      return 5
    elseif type(k) == 'table' then
      return 3
    else
      return 1
    end
  end
  local main_effect = self.effect_list[1]
  local first
  if not main_effect then
    first = true
  else
    local main_prio = getTypePriority(main_effect[1])
    local param_prio = getTypePriority(key)
    if main_prio == 5 then
      if param_prio == 5 then
        fk.qCritical("You can only add 1 'active'/'viewas' effect in one skill.")
        return
      end
      first = false
    else
      first = param_prio > main_prio
    end
  end

  if first then
    table.insert(self.effect_list, 1, { key, attribute, data })
  else
    table.insert(self.effect_list, { key, attribute, data })
  end
  return self
end

--- TODO
function SkillSkeleton:addAI()
  return self
end

---@param fn fun(room: Room, me: ServerPlayer)
function SkillSkeleton:addTest(fn)
  table.insert(self.tests, fn)
  return self
end

---@return Skill
function SkillSkeleton:createSkill()
  local frequency = self.frequency
  local main_skill
  for i, effect in ipairs(self.effect_list) do
    local k, attr, data = table.unpack(effect)
    attr = attr or Util.DummyTable
    local sk
    if k == 'distance' then
      sk = self:createDistanceSkill(self, i, k, attr, data)
    elseif k == 'prohibit' then
      sk = self:createProhibitSkill(self, i, k, attr, data)
    elseif k == 'atkrange' then
      sk = self:createAttackRangeSkill(self, i, k, attr, data)
    elseif k == 'maxcards' then
      sk = self:createMaxCardsSkill(self, i, k, attr, data)
    elseif k == 'targetmod' then
      sk = self:createTargetModSkill(self, i, k, attr, data)
    elseif k == 'filter' then
      sk = self:createFilterSkill(self, i, k, attr, data)
    elseif k == 'invalidity' then
      sk = self:createInvaliditySkill(self, i, k, attr, data)
    elseif k == 'visibility' then
      sk = self:createVisibilitySkill(self, i, k, attr, data)
    elseif k == 'active' then
      sk = self:createActiveSkill(self, i, k, attr, data)
    elseif k == 'viewas' then
      sk = self:createViewAsSkill(self, i, k, attr, data)
    else
      sk = self:createTriggerSkill(self, i, k, attr, data)
    end
    if sk then
      if not main_skill then
        main_skill = sk
        main_skill.name = self.name
        local name_splited = self.name:split("__")
        main_skill.trueName = name_splited[#name_splited]
        main_skill.visible = self.name[1] ~= "#"
        if string.sub(main_skill.name, #main_skill.name) == "$" then
          main_skill.name = string.sub(main_skill.name, 1, #main_skill.name - 1)
          main_skill.lordSkill = true
        end
      else
        if not attr.is_delay_effect then
          sk.main_skill = main_skill
        end
        main_skill:addRelatedSkill(sk)
      end
    end
  end
  if not main_skill then
    main_skill = Skill:new(self.name, frequency)
    fk.readCommonSpecToSkill(main_skill, self)
  end
  return main_skill
end

---@class TrigSkelAttribute
---@field public is_delay_effect? boolean
--- 若为true，则不贴main_skill

---@alias TrigFunc fun(self: TriggerSkill, event: TriggerEvent, target: ServerPlayer?, player: ServerPlayer, data: any): any
---@class TrigSkelSpec<T>: {
--- on_trigger?: T,
--- can_trigger?: T,
--- on_cost?: T,
--- on_use?: T,
--- on_refresh?: T,
--- can_refresh?: T,
--- can_wake?: T,
--- }

---@param _skill SkillSkeleton
---@param idx integer
---@param key TriggerEvent
---@param attr TrigSkelAttribute
---@param spec TrigSkelSpec<TrigFunc>
---@return TriggerSkill
function SkillSkeleton:createTriggerSkill(_skill, idx, key, attr, spec)
  local new_name = string.format("#%s_%d_trig", _skill.name, idx)
  local sk = TriggerSkill:new(new_name, _skill.frequency)
  fk.readCommonSpecToSkill(sk, self)
  Fk:loadTranslationTable({ [new_name] = Fk:translate(_skill.name) }, Config.language)
  sk.event = key
  if spec.can_trigger then
    if _skill.frequency == Skill.Wake then
      sk.triggerable = function(_self, event, target, player, data)
        return spec.can_trigger(_self, event, target, player, data) and
          sk:enableToWake(event, target, player, data)
      end
    else
      sk.triggerable = spec.can_trigger
    end
    if _skill.frequency == Skill.Wake and spec.can_wake then
      sk.canWake = spec.can_wake
    end
  end
  if spec.on_trigger then sk.trigger = spec.on_trigger end
  if spec.on_cost then sk.cost = spec.on_cost end
  if spec.on_use then sk.use = spec.on_use end

  if spec.can_refresh then sk.canRefresh = spec.can_refresh end
  if spec.on_refresh then sk.refresh = spec.on_refresh end

  if spec.can_refresh and not (spec.can_trigger or spec.can_wake or spec.on_trigger
    or spec.on_cost or spec.on_use) then
    sk.triggerable = Util.FalseFunc
  end

  -- TODO: useAbleSpec, priority
  sk.priority = 1

  return sk
end

---@param key 'distance'
---@param spec DistanceSpec
---@return DistanceSkill
function SkillSkeleton:createDistanceSkill(_skill, idx, key, attr, spec)
  assert(type(spec.correct_func) == "function" or type(spec.fixed_func) == "function")
  local new_name = string.format("#%s_%d_distance", _skill.name, idx)
  Fk:loadTranslationTable({ [new_name] = Fk:translate(_skill.name) }, Config.language)

  local sk = DistanceSkill:new(new_name)
  fk.readStatusSpecToSkill(sk, spec)
  sk.getCorrect = spec.correct_func
  sk.getFixed = spec.fixed_func

  return sk
end

---@param spec ProhibitSpec
---@return ProhibitSkill
function SkillSkeleton:createProhibitSkill(_skill, idx, key, attr, spec)
  local new_name = string.format("#%s_%d_prohibit", _skill.name, idx)
  Fk:loadTranslationTable({ [new_name] = Fk:translate(_skill.name) }, Config.language)

  local sk = ProhibitSkill:new(new_name)
  fk.readStatusSpecToSkill(sk, spec)
  sk.isProhibited = spec.is_prohibited or sk.isProhibited
  sk.prohibitUse = spec.prohibit_use or sk.prohibitUse
  sk.prohibitResponse = spec.prohibit_response or sk.prohibitResponse
  sk.prohibitDiscard = spec.prohibit_discard or sk.prohibitDiscard
  sk.prohibitPindian = spec.prohibit_pindian or sk.prohibitPindian

  return sk
end

---@param spec AttackRangeSpec
---@return AttackRangeSkill
function SkillSkeleton:createAttackRangeSkill(_skill, idx, key, attr, spec)
  assert(type(spec.correct_func) == "function" or type(spec.fixed_func) == "function" or
    type(spec.within_func) == "function" or type(spec.without_func) == "function")
  local new_name = string.format("#%s_%d_atkrange", _skill.name, idx)
  Fk:loadTranslationTable({ [new_name] = Fk:translate(_skill.name) }, Config.language)

  local skill = AttackRangeSkill:new(new_name)
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

---@param spec MaxCardsSpec
---@return MaxCardsSkill
function SkillSkeleton:createMaxCardsSkill(_skill, idx, key, attr, spec)
  assert(type(spec.correct_func) == "function" or type(spec.fixed_func) == "function" or type(spec.exclude_from) == "function")
  local new_name = string.format("#%s_%d_maxcards", _skill.name, idx)
  Fk:loadTranslationTable({ [new_name] = Fk:translate(_skill.name) }, Config.language)

  local skill = MaxCardsSkill:new(new_name)
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

---@param spec TargetModSpec
---@return TargetModSkill
function SkillSkeleton:createTargetModSkill(_skill, idx, key, attr, spec)
  local new_name = string.format("#%s_%d_targetmod", _skill.name, idx)
  Fk:loadTranslationTable({ [new_name] = Fk:translate(_skill.name) }, Config.language)

  local skill = TargetModSkill:new(new_name)
  fk.readStatusSpecToSkill(skill, spec)
  if spec.bypass_times then
    skill.bypassTimesCheck = spec.bypass_times
  end
  if spec.residue_func then
    skill.getResidueNum = spec.residue_func
  end
  if spec.fix_times_func then
    skill.getFixedNum = spec.fix_times_func
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

---@param spec FilterSpec
---@return FilterSkill
function SkillSkeleton:createFilterSkill(_skill, idx, key, attr, spec)
  local new_name = string.format("#%s_%d_filter", _skill.name, idx)
  Fk:loadTranslationTable({ [new_name] = Fk:translate(_skill.name) }, Config.language)

  local skill = FilterSkill:new(new_name)
  fk.readStatusSpecToSkill(skill, spec)
  skill.cardFilter = spec.card_filter
  skill.viewAs = spec.view_as
  skill.equipSkillFilter = spec.equip_skill_filter
  skill.handlyCardsFilter = spec.handly_cards

  return skill
end

---@param spec InvaliditySpec
---@return InvaliditySkill
function SkillSkeleton:createInvaliditySkill(_skill, idx, key, attr, spec)
  local new_name = string.format("#%s_%d_invalidity", _skill.name, idx)
  Fk:loadTranslationTable({ [new_name] = Fk:translate(_skill.name) }, Config.language)

  local skill = InvaliditySkill:new(new_name)
  fk.readStatusSpecToSkill(skill, spec)

  if spec.invalidity_func then
    skill.getInvalidity = spec.invalidity_func
  end
  if spec.invalidity_attackrange then
    skill.getInvalidityAttackRange = spec.invalidity_attackrange
  end

  return skill
end

---@param spec VisibilitySpec
---@return VisibilitySkill
function SkillSkeleton:createVisibilitySkill(_skill, idx, key, attr, spec)
  local new_name = string.format("#%s_%d_visibility", _skill.name, idx)
  Fk:loadTranslationTable({ [new_name] = Fk:translate(_skill.name) }, Config.language)

  local skill = VisibilitySkill:new(new_name)
  fk.readStatusSpecToSkill(skill, spec)
  if spec.card_visible then skill.cardVisible = spec.card_visible end
  if spec.role_visible then skill.roleVisible = spec.role_visible end

  return skill
end

---@param spec ActiveSkillSpec
---@return ActiveSkill
function SkillSkeleton:createActiveSkill(_skill, idx, key, attr, spec)
  local new_name = string.format("#%s_%d_active", _skill.name, idx)
  Fk:loadTranslationTable({ [new_name] = Fk:translate(_skill.name) }, Config.language)

  local skill = ActiveSkill:new(new_name, spec.frequency or Skill.NotFrequent)
  fk.readUsableSpecToSkill(skill, spec)

  if spec.can_use then
    skill.canUse = function(curSkill, player, card, extra_data)
      return spec.can_use(curSkill, player, card, extra_data) and curSkill:isEffectable(player)
    end
  end
  if spec.card_filter then skill.cardFilter = spec.card_filter end
  if spec.target_filter then skill.targetFilter = spec.target_filter end
  if spec.mod_target_filter then skill.modTargetFilter = spec.mod_target_filter end
  if spec.feasible then skill.feasible = spec.feasible end
  if spec.on_use then skill.onUse = spec.on_use end
  if spec.on_action then skill.onAction = spec.on_action end
  if spec.about_to_effect then skill.aboutToEffect = spec.about_to_effect end
  if spec.on_effect then skill.onEffect = spec.on_effect end
  if spec.on_nullified then skill.onNullified = spec.on_nullified end
  if spec.prompt then skill.prompt = spec.prompt end
  if spec.target_tip then skill.targetTip = spec.target_tip end
  if spec.handly_pile then skill.handly_pile = spec.handly_pile end
  if spec.fix_targets then skill.fixTargets = spec.fix_targets end

  if spec.interaction then
    skill.interaction = setmetatable({}, {
      __call = function(_, ...)
        if type(spec.interaction) == "function" then
          return spec.interaction(...)
        else
          return spec.interaction
        end
      end,
    })
  end
  return skill
end

---@param spec ViewAsSkillSpec
---@return ViewAsSkill
function SkillSkeleton:createViewAsSkill(_skill, idx, key, attr, spec)
  local new_name = string.format("#%s_%d_active", _skill.name, idx)
  Fk:loadTranslationTable({ [new_name] = Fk:translate(_skill.name) }, Config.language)

  local skill = ViewAsSkill:new(new_name, spec.frequency or Skill.NotFrequent)
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
      __call = function(_, ...)
        if type(spec.interaction) == "function" then
          return spec.interaction(...)
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
  skill.handly_pile = spec.handly_pile

  return skill
end

---@param spec SkillSpec
---@return SkillSkeleton
function fk.CreateSkill(spec)
  return SkillSkeleton:new(spec)
end

---@class CardSkelSpec: CardSpec
---@field public skill? string
---@field public type? integer
---@field public sub_type? integer

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

  local card = klass:new(spec.name, spec.suit, spec.number)
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

---@class UsableSkillSpec: SkillSpec
---@field public main_skill? UsableSkill
---@field public max_use_time? integer[]
---@field public expand_pile? string | integer[] | fun(self: UsableSkill, player: ServerPlayer): integer[]|string? @ 额外牌堆，牌堆名称或卡牌id表
---@field public derived_piles? string | string[]
---@field public max_phase_use_time? integer
---@field public max_turn_use_time? integer
---@field public max_round_use_time? integer
---@field public max_game_use_time? integer
---@field public times? integer | fun(self: UsableSkill, player: Player): integer
---@field public min_target_num? integer
---@field public max_target_num? integer
---@field public target_num? integer
---@field public target_num_table? integer[]
---@field public min_card_num? integer
---@field public max_card_num? integer
---@field public card_num? integer
---@field public card_num_table? integer[]

---@class StatusSkillSpec: SkillSpec

---@class ActiveSkillSpec: UsableSkillSpec
---@field public can_use? fun(self: ActiveSkill, player: Player, card?: Card, extra_data: any): any @ 判断主动技能否发动
---@field public card_filter? fun(self: ActiveSkill, player: Player, to_select: integer, selected: integer[]): any @ 判断卡牌能否选择
---@field public target_filter? fun(self: ActiveSkill, player: Player?, to_select: Player, selected: Player[], selected_cards: integer[], card?: Card, extra_data: any): any @ 判定目标能否选择
---@field public feasible? fun(self: ActiveSkill, player: Player, selected: Player[], selected_cards: integer[]): any @ 判断卡牌和目标是否符合技能限制
---@field public on_use? fun(self: ActiveSkill, room: Room, cardUseEvent: UseCardData | SkillUseData): any
---@field public on_action? fun(self: ActiveSkill, room: Room, cardUseEvent: UseCardData | SkillUseData, finished: boolean): any
---@field public about_to_effect? fun(self: ActiveSkill, room: Room, cardEffectEvent: CardEffectData): any
---@field public on_effect? fun(self: ActiveSkill, room: Room, cardEffectEvent: CardEffectData): any
---@field public on_nullified? fun(self: ActiveSkill, room: Room, cardEffectEvent: CardEffectData): any
---@field public mod_target_filter? fun(self: ActiveSkill, player: Player, to_select: Player, selected: Player[], card?: Card, extra_data: any): any
---@field public prompt? string|fun(self: ActiveSkill, player: Player, selected_cards: integer[], selected_targets: Player[]): string @ 提示信息
---@field public interaction? any
---@field public target_tip? fun(self: ActiveSkill, player: Player, to_select: Player, selected: Player[], selected_cards: integer[], card?: Card, selectable: boolean, extra_data: any): string|TargetTipDataSpec?
---@field public handly_pile? boolean @ 是否能够选择“如手牌使用或打出”的牌
---@field public fix_targets? fun(self: ActiveSkill, player: Player, card?: Card, extra_data: any): Player[]? @ 设置固定目标

---@class ViewAsSkillSpec: UsableSkillSpec
---@field public card_filter? fun(self: ViewAsSkill, player: Player, to_select: integer, selected: integer[]): any @ 判断卡牌能否选择
---@field public view_as fun(self: ViewAsSkill, player: Player, cards: integer[]): Card? @ 判断转化为什么牌
---@field public pattern? string
---@field public enabled_at_play? fun(self: ViewAsSkill, player: Player): any
---@field public enabled_at_response? fun(self: ViewAsSkill, player: Player, response: boolean): any
---@field public before_use? fun(self: ViewAsSkill, player: ServerPlayer, use: UseCardDataSpec): string?
---@field public after_use? fun(self: ViewAsSkill, player: ServerPlayer, use: UseCardData): string? @ 使用此牌后执行的内容，注意打出不会执行
---@field public prompt? string|fun(self: ActiveSkill, player: Player, selected_cards: integer[], selected: Player[]): string
---@field public interaction? any
---@field public handly_pile? boolean @ 是否能够选择“如手牌使用或打出”的牌

---@class DistanceSpec: StatusSkillSpec
---@field public correct_func? fun(self: DistanceSkill, from: Player, to: Player): integer?
---@field public fixed_func? fun(self: DistanceSkill, from: Player, to: Player): integer?

---@class ProhibitSpec: StatusSkillSpec
---@field public is_prohibited? fun(self: ProhibitSkill, from: Player, to: Player, card: Card): any
---@field public prohibit_use? fun(self: ProhibitSkill, player: Player, card: Card): any
---@field public prohibit_response? fun(self: ProhibitSkill, player: Player, card: Card): any
---@field public prohibit_discard? fun(self: ProhibitSkill, player: Player, card: Card): any
---@field public prohibit_pindian? fun(self: ProhibitSkill, from: Player, to: Player): any

---@class AttackRangeSpec: StatusSkillSpec
---@field public correct_func? fun(self: AttackRangeSkill, from: Player, to: Player): number?
---@field public fixed_func? fun(self: AttackRangeSkill, player: Player): number?  @ 判定角色的锁定攻击范围初值
---@field public within_func? fun(self: AttackRangeSkill, from: Player, to: Player): any @ 判定to角色是否锁定在角色from攻击范围内
---@field public without_func? fun(self: AttackRangeSkill, from: Player, to: Player): any @ 判定to角色是否锁定在角色from攻击范围外

---@class MaxCardsSpec: StatusSkillSpec
---@field public correct_func? fun(self: MaxCardsSkill, player: Player): number?
---@field public fixed_func? fun(self: MaxCardsSkill, player: Player): number?
---@field public exclude_from? fun(self: MaxCardsSkill, player: Player, card: Card): any

---@class TargetModSpec: StatusSkillSpec
---@field public bypass_times? fun(self: TargetModSkill, player: Player, skill: ActiveSkill, scope: integer, card?: Card, to?: Player): any
---@field public residue_func? fun(self: TargetModSkill, player: Player, skill: ActiveSkill, scope: integer, card?: Card, to?: Player): number?
---@field public bypass_distances? fun(self: TargetModSkill, player: Player, skill: ActiveSkill, card?: Card, to?: Player): any
---@field public distance_limit_func? fun(self: TargetModSkill, player: Player, skill: ActiveSkill, card?: Card, to?: Player): number?
---@field public extra_target_func? fun(self: TargetModSkill, player: Player, skill: ActiveSkill, card?: Card): number?
---@field public target_tip_func? fun(self: TargetModSkill, player: Player, to_select: Player, selected: Player[], selected_cards: integer[], card?: Card, selectable: boolean, extra_data: any): string|TargetTipDataSpec?

---@class FilterSpec: StatusSkillSpec
---@field public card_filter? fun(self: FilterSkill, card: Card, player: Player, isJudgeEvent: boolean): any
---@field public view_as? fun(self: FilterSkill, player: Player, card: Card): Card?
---@field public equip_skill_filter? fun(self: FilterSkill, skill: Skill, player: Player): string?
---@field public handly_cards? fun(self: FilterSkill, player: Player): integer[]? @ 视为拥有可以如手牌般使用或打出的牌


---@class InvaliditySpec: StatusSkillSpec
---@field public invalidity_func? fun(self: InvaliditySkill, from: Player, skill: Skill): any @ 判定角色的技能是否无效
---@field public invalidity_attackrange? fun(self: InvaliditySkill, player: Player, card: Weapon): any @ 判定武器的攻击范围是否无效

---@class VisibilitySpec: StatusSkillSpec
---@field public card_visible? fun(self: VisibilitySkill, player: Player, card: Card): any
---@field public role_visible? fun(self: VisibilitySkill, player: Player, target: Player): any

---@class CardSpec
---@field public name string @ 卡牌的名字
---@field public suit? Suit @ 卡牌的花色（四色及无花色）
---@field public number? integer @ 卡牌的点数（0到K）
---@field public skill? ActiveSkill
---@field public special_skills? string[]
---@field public is_damage_card? boolean
---@field public multiple_targets? boolean
---@field public is_passive? boolean

function fk.preprocessCardSpec(spec)
  assert(type(spec.name) == "string" or type(spec.class_name) == "string")
  if not spec.name then spec.name = spec.class_name
  elseif not spec.class_name then spec.class_name = spec.name end
  if spec.suit then assert(type(spec.suit) == "number") end
  if spec.number then assert(type(spec.number) == "number") end
end

function fk.readCardSpecToCard(card, spec)
  if type(spec.skill) == "string" then
    spec.skill = Fk.skills[spec.skill]
  end
  card.skill = spec.skill or (card.type == Card.TypeEquip and
    Fk.skills["default_equip_skill"] or Fk.skills["default_card_skill"])
  card.skill.cardSkill = true
  card.special_skills = spec.special_skills
  card.is_damage_card = spec.is_damage_card
  card.multiple_targets = spec.multiple_targets
  card.is_passive = spec.is_passive
end

---@class EquipCardSpec: CardSpec
---@field public equip_skill? Skill|string
---@field public dynamic_equip_skills? fun(player: Player): Skill[]
---@field public on_install? fun(self: EquipCard, room: Room, player: ServerPlayer)
---@field public on_uninstall? fun(self: EquipCard, room: Room, player: ServerPlayer)

function fk.readCardSpecToEquip(card, spec)
  if type(spec.equip_skill) == "string" then
    local skill = Fk.skills[spec.equip_skill]
    if not skill then
      fk.qCritical(string.format("Equip %s does not exist!", spec.equip_skill))
    end
    spec.equip_skill = skill
  end

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
---@field public dynamic_attack_range? fun(player: Player): integer

---@class GameModeSpec
---@field public name string @ 游戏模式名
---@field public minPlayer integer @ 最小玩家数
---@field public maxPlayer integer @ 最大玩家数
---@field public rule? TriggerSkill @ 规则（通过技能完成，通常用来为特定角色及特定时机提供触发事件）
---@field public logic? fun(): GameLogic @ 逻辑（通过function完成，通常用来初始化、分配身份及座次）
---@field public whitelist? string[] | fun(self: GameMode, pkg: Package): boolean? @ 白名单
---@field public blacklist? string[] | fun(self: GameMode, pkg: Package): boolean? @ 黑名单
---@field public config_template? GameModeConfigEntry[] 游戏模式的配置页面，如此一个数组
---@field public main_mode? string @ 主模式名（用于判断此模式是否为某模式的衍生）
---@field public winner_getter? fun(self: GameMode, victim: ServerPlayer): string @ 在死亡流程中用于判断是否结束游戏，并输出胜利者身份
---@field public surrender_func? fun(self: GameMode, playedTime: number): table
---@field public is_counted? fun(self: GameMode, room: Room): boolean @ 是否计入胜率统计
---@field public get_adjusted? fun(self: GameMode, player: ServerPlayer): table @ 调整玩家初始属性
---@field public reward_punish? fun(self: GameMode, victim: ServerPlayer, killer?: ServerPlayer) @ 死亡奖惩
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
---@field card_filter fun(to_select: integer, selected: integer[], data: any, extra_data: any): any
---@field feasible fun(selected: integer[], data: any, extra_data: any): any
---@field post_select? fun(selected: integer[], data: any, extra_data: any): integer[]
---@field default_choice? fun(data: any, extra_data: any): integer[]
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
