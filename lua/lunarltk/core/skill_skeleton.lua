-- SPDX-License-Identifier: GPL-3.0-or-later

---@class SkillSpec
---@field public name? string @ 技能名
---@field public mute? boolean @ 决定是否关闭技能配音
---@field public no_indicate? boolean @ 决定是否关闭技能指示线
---@field public anim_type? string|AnimationType @ 技能类型定义
---@field public global? boolean @ 决定是否是全局技能
---@field public dynamic_desc? fun(self: Skill, player: Player, lang: string): string? @ 动态描述函数
---@field public derived_piles? string|string[]  @deprecated @ 与某效果联系起来的私人牌堆名，失去该效果时将之置入弃牌堆
---@field public audio_index? table|integer @ 此技能效果播放的语音序号，可为int或int表
---@field public extra? table @ 塞进技能里的各种数据

---@class SkillSkeletonSpec
---@field public name? string @ 骨架名，即此技能集合的外在名称
---@field public tags? SkillTag[] 技能标签
---@field public attached_equip? string @ 属于什么装备的技能？
---@field public attached_kingdom? string[] @ 只有哪些势力可以获得，若为空则均可。用于势力技。
---@field public attached_skill_name? string @ 向其他角色分发的技能名（如黄天）
---@field public dynamic_name? fun(self: SkillSkeleton, player: Player, lang?: string): string @ 动态名称函数
---@field public dynamic_desc? fun(self: SkillSkeleton, player: Player, lang?: string): string? @ 动态描述函数
---@field public derived_piles? string | string[] @ 与该技能联系起来的私人牌堆名，失去该技能时将之置入弃牌堆
---@field public max_phase_use_time? integer | fun(self: SkillSkeleton, player: Player): integer? @ 该技能的最大使用次数——阶段
---@field public max_turn_use_time? integer | fun(self: SkillSkeleton, player: Player): integer? @ 该技能的最大使用次数——回合
---@field public max_round_use_time? integer | fun(self: SkillSkeleton, player: Player): integer? @ 该技能的最大使用次数——轮次
---@field public max_game_use_time? integer | fun(self: SkillSkeleton, player: Player): integer? @ 该技能的最大使用次数——本局游戏
---@field public max_branches_use_time? table<string, table<integer, integer?>?> | fun(self: SkillSkeleton, player: Player): table<string, table<integer, integer?>?>? @ 该技能的最大使用次数——任意标签（内部有独立的时段细分）
---@field public mode_skill? boolean @ 是否为模式技能（诸如斗地主的“飞扬”和“跋扈”）
---@field public extra? table @ 塞进技能里的各种数据

---@class SkillSkeleton : Object, SkillSkeletonSpec
---@field public effects Skill[] @ 该技能对应的所有效果
---@field public effect_names string[] @ 该技能对应的效果名
---@field public effect_spec_list ([any, any, any])[] @ 该技能对应的效果信息
---@field public ai_list ([string, any, string, boolean?])[]
---@field public tests fun(room: Room, me: ServerPlayer)[]
---@field public dynamicName fun(self: SkillSkeleton, player: Player, lang?: string): string @ 动态名称函数
---@field public dynamicDesc fun(self: SkillSkeleton, player: Player, lang?: string): string @ 动态描述函数
---@field public derived_piles? string[] @ 与该技能同在的私有牌堆名，失去时弃置其中的所有牌
---@field public max_use_time table<integer, integer?> @ 该技能在各时机内最大的使用次数
---@field public max_branches_use_time? table<string, table<integer, integer?>?> | fun(self: SkillSkeleton, player: Player): table<string, table<integer, integer?>?>? @ 该技能的最大使用次数——任意标签（内部有独立的时段细分）
---@field public addTest fun(self: SkillSkeleton, fn: fun(room: Room, me: ServerPlayer)) @ 测试函数
---@field public onAcquire fun(self: SkillSkeleton, player: ServerPlayer, is_start: boolean) @ 获得技能时执行的函数
---@field public onLose fun(self: SkillSkeleton, player: ServerPlayer, is_death: boolean) @ 失去技能时执行的函数
---@field public addEffect fun(self: SkillSkeleton, key: "distance", data: DistanceSpec, attribute: nil): SkillSkeleton
---@field public addEffect fun(self: SkillSkeleton, key: "prohibit", data: ProhibitSpec, attribute: nil): SkillSkeleton
---@field public addEffect fun(self: SkillSkeleton, key: "atkrange", data: AttackRangeSpec, attribute: nil): SkillSkeleton
---@field public addEffect fun(self: SkillSkeleton, key: "maxcards", data: MaxCardsSpec, attribute: nil): SkillSkeleton
---@field public addEffect fun(self: SkillSkeleton, key: "targetmod", data: TargetModSpec, attribute: nil): SkillSkeleton
---@field public addEffect fun(self: SkillSkeleton, key: "filter", data: FilterSpec, attribute: nil): SkillSkeleton
---@field public addEffect fun(self: SkillSkeleton, key: "invalidity", data: InvaliditySpec, attribute: nil): SkillSkeleton
---@field public addEffect fun(self: SkillSkeleton, key: "visibility", data: VisibilitySpec, attribute: nil): SkillSkeleton
---@field public addEffect fun(self: SkillSkeleton, key: "active", data: ActiveSkillSpec, attribute: SkillAttribute?): SkillSkeleton
---@field public addEffect fun(self: SkillSkeleton, key: "cardskill", data: CardSkillSpec, attribute: nil): SkillSkeleton
---@field public addEffect fun(self: SkillSkeleton, key: "viewas", data: ViewAsSkillSpec, attribute: SkillAttribute?): SkillSkeleton
local SkillSkeleton = class("SkillSkeleton")


---@param spec SkillSkeletonSpec
function SkillSkeleton:initialize(spec)
  local name = spec.name ---@type string
  self.name = name
  self.effects = {}
  self.effect_names = {}
  self.effect_spec_list = {}
  self.ai_list = {}
  self.tests = {}

  local name_split = self.name:split("__")
  self.trueName = name_split[#name_split]

  self.tags = spec.tags or {}

  self.visible = true
  if string.sub(name, 1, 1) == "#" then
    self.visible = false
  end

  self.attached_equip = spec.attached_equip

  self.attached_skill_name = spec.attached_skill_name

  self.attached_kingdom = spec.attached_kingdom or {}

  self.dynamicName = spec.dynamic_name
  self.dynamicDesc = spec.dynamic_desc

  if type(spec.derived_piles) == "string" then
    self.derived_piles = { spec.derived_piles }
  else
    self.derived_piles = spec.derived_piles
  end
  self.mode_skill = spec.mode_skill

  self.extra = spec.extra or {}

  self.max_use_time = {
    spec.max_phase_use_time,
    spec.max_turn_use_time,
    spec.max_round_use_time,
    spec.max_game_use_time,
  }
  self.max_branches_use_time = spec.max_branches_use_time

  --Notify智慧，当不存在main_skill时，用于创建main_skill。看上去毫无用处
  fk.readCommonSpecToSkill(self, spec)

  if self.max_use_time[Player.HistoryGame] == nil then
    if table.contains(self.tags, Skill.Limited) or table.contains(self.tags, Skill.Wake) then
      self.max_use_time[Player.HistoryGame] = 1
    end
  end
end

function SkillSkeleton:addEffect(key, data, attribute)
  -- 需要按照顺序插入，active和viewas最先，trigger其次，剩下的随意
  -- 其实决定要不要插在第一个就行了
  -- 'active' 和 'viewas' 必须唯一

  local function getTypePriority(k)
    if type(k) == 'table' then -- 触发技
      return 3
    else
      return Fk.skill_keys[k][2] or 1
    end
  end
  local main_effect = self.effect_spec_list[1]
  local first
  if not main_effect then
    first = true
  else
    local main_prio = getTypePriority(main_effect[1])
    local param_prio = getTypePriority(key)
    if main_prio == 5 then
      if param_prio == 5 then
        fk.qCritical("You can only add 1 'active'/'viewas' effect in one skill [Skill: " .. self.name .. "]")
        return
      end
      first = false
    else
      first = param_prio > main_prio
    end
  end

  if first then
    table.insert(self.effect_spec_list, 1, { key, attribute, data })
  else
    table.insert(self.effect_spec_list, { key, attribute, data })
  end
  return self
end

---@param spec? SkillAISpec|TriggerSkillAISpec
---@param inherit? string
---@param key? string
---@param setTriggerSkillAI? boolean
---@return SkillSkeleton
function SkillSkeleton:addAI(spec, inherit, key, setTriggerSkillAI)
  table.insert(self.ai_list, { key or self.name, spec, inherit, setTriggerSkillAI })
  return self
end

---@param fn fun(room: Room, me: ServerPlayer)
function SkillSkeleton:addTest(fn)
  table.insert(self.tests, fn)
  return self
end

---@return Skill
function SkillSkeleton:createSkill()
  local main_skill
  for i, effect in ipairs(self.effect_spec_list) do
    local k, attr, data = table.unpack(effect)
    attr = attr or Util.DummyTable
    local sk
    if type(k) == "string" then
      local createSkillFunc = Fk.skill_keys[k][1]
      if createSkillFunc then
        sk = createSkillFunc(self, self, i, k, attr, data)
      end
    else
      sk = self:createTriggerSkill(self, i, k, attr, data)
    end
    if sk then
      local sk_name = sk.name
      if not main_skill then
        main_skill = sk
        main_skill.name = self.name
        local name_split = self.name:split("__")
        main_skill.trueName = name_split[#name_split]
        main_skill.visible = self.name[1] ~= "#"
        sk_name = string.format("#%s_main_skill", main_skill.name)
      else
        if not sk.is_delay_effect then
          sk.main_skill = main_skill
        end
        main_skill:addRelatedSkill(sk)
      end
      table.insert(self.effects, sk)
      table.insert(self.effect_names, sk_name)
      sk.skeleton = self
    end
  end
  if not main_skill then
    local frequency = Skill.NotFrequent
    if #self.tags > 0 then
      frequency = self.tags[1]
    end
    main_skill = Skill:new(self.name, frequency)
    fk.readCommonSpecToSkill(main_skill, self)
    main_skill.skeleton = self
  end
  return main_skill
end

---@class SkillAttribute
---@field public check_effect_limit? boolean @ 若为true，则自带判断效果次数（若不填can_use，则默认带限定“本阶段”的次数判定）
---@field public check_skill_limit? boolean @ 若为true，则自带判断技能次数

---@class TrigSkelAttribute: SkillAttribute
---@field public is_delay_effect? boolean @ 若为true，则不贴main_skill

---@alias TrigFunc fun(self: TriggerSkill, event: TriggerEvent, target: ServerPlayer?, player: ServerPlayer, data: any): any
---@class TrigSkelSpec<T>: {
--- on_trigger?: T,
--- can_trigger?: T,
--- on_cost?: T,
--- on_use?: T,
--- on_refresh?: T,
--- can_refresh?: T,
--- can_wake?: T,
--- global?: boolean,
--- anim_type?: AnimationType,
--- frequency?: string,
--- is_delay_effect?: boolean,
--- late_refresh?: boolean,
--- audio_index?: integer|table,
--- trigger_times?: T,
--- priority? : number,
--- times?: integer|(fun(self: TriggerSkill, player: ServerPlayer): integer?),
--- max_phase_use_time?: integer|(fun(self: TriggerSkill, player: ServerPlayer): integer?),
--- max_turn_use_time?: integer|(fun(self: TriggerSkill, player: ServerPlayer): integer?),
--- max_round_use_time?: integer|(fun(self: TriggerSkill, player: ServerPlayer): integer?),
--- max_game_use_time?: integer|(fun(self: TriggerSkill, player: ServerPlayer): integer?),
--- }

---@param _skill SkillSkeleton
---@param idx integer
---@param key TriggerEvent
---@param attr TrigSkelAttribute
---@param spec TrigSkelSpec<TrigFunc>
---@return TriggerSkill
function SkillSkeleton:createTriggerSkill(_skill, idx, key, attr, spec)
  local new_name = string.format("#%s_%d_trig", _skill.name, idx)
  local sk = TriggerSkill:new(new_name, #_skill.tags > 0 and _skill.tags[1] or Skill.NotFrequent)
  if attr.is_delay_effect then spec.is_delay_effect = true end
  fk.readUsableSpecToSkill(sk, spec)
  Fk:loadTranslationTable({ [new_name] = Fk:translate(_skill.name) }, Config.language)
  sk.event = key
  if spec.global then
    sk.global = spec.global
  end
  if spec.can_trigger then
    local tmp_func
    if table.contains(_skill.tags, Skill.Wake) then
      if spec.can_wake then
        sk.canWake = spec.can_wake
      end
      tmp_func = function(_self, event, target, player, data)
        return spec.can_trigger(_self, event, target, player, data) and
          sk:enableToWake(event, target, player, data)
      end
    else
      tmp_func = spec.can_trigger
    end
    sk.triggerable = function(_self, event, target, player, data)
      if attr.check_effect_limit then
        for scope, _ in pairs(_self.max_use_time) do
          if not _self:withinTimesLimit(player, scope) then
            return false
          end
        end
      end
      if attr.check_skill_limit then
        if #_skill.max_use_time == 0 and _skill.max_branches_use_time then
          -- 写死的时机table，考虑到历史记录也是写死在这的，姑且先这样吧
          for _, scope in ipairs({Player.HistoryGame, Player.HistoryRound, Player.HistoryTurn, Player.HistoryPhase}) do
            if not _skill:withinBranchTimesLimit(player, nil, scope) then
              return false
            end
          end
        end
        for scope, _ in pairs(_skill.max_use_time) do
          if not _skill:withinTimesLimit(player, scope) then
            return false
          end
        end
      end
      return tmp_func(_self, event, target, player, data)
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

  if spec.trigger_times then sk.triggerableTimes = spec.trigger_times end

  -- TODO: useAbleSpec, priority
  sk.priority = spec.priority or 1

  return sk
end

---@param key 'distance'
---@param spec DistanceSpec
---@return DistanceSkill
function SkillSkeleton:createDistanceSkill(_skill, idx, key, attr, spec)
  assert(type(spec.correct_func) == "function" or type(spec.fixed_func) == "function")
  local new_name = string.format("#%s_%d_distance", _skill.name, idx)
  Fk:loadTranslationTable({ [new_name] = Fk:translate(_skill.name) }, Config.language)

  local sk = DistanceSkill:new(new_name, #_skill.tags > 0 and _skill.tags[1] or Skill.Compulsory)
  fk.readStatusSpecToSkill(sk, spec)
  sk.getCorrect = spec.correct_func
  sk.getFixed = spec.fixed_func

  return sk
end

---@param key 'prohibit'
---@param spec ProhibitSpec
---@return ProhibitSkill
function SkillSkeleton:createProhibitSkill(_skill, idx, key, attr, spec)
  local new_name = string.format("#%s_%d_prohibit", _skill.name, idx)
  Fk:loadTranslationTable({ [new_name] = Fk:translate(_skill.name) }, Config.language)

  local sk = ProhibitSkill:new(new_name, #_skill.tags > 0 and _skill.tags[1] or Skill.Compulsory)
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
    type(spec.within_func) == "function" or type(spec.without_func) == "function" or
    type(spec.final_func) == "function")
  local new_name = string.format("#%s_%d_atkrange", _skill.name, idx)
  Fk:loadTranslationTable({ [new_name] = Fk:translate(_skill.name) }, Config.language)

  local skill = AttackRangeSkill:new(new_name, #_skill.tags > 0 and _skill.tags[1] or Skill.Compulsory)
  fk.readStatusSpecToSkill(skill, spec)
  if spec.correct_func then
    skill.getCorrect = spec.correct_func
  end
  if spec.fixed_func then
    skill.getFixed = spec.fixed_func
  end
  if spec.final_func then
    skill.getFinal = spec.final_func
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

  local skill = MaxCardsSkill:new(new_name, #_skill.tags > 0 and _skill.tags[1] or Skill.Compulsory)
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

  local skill = TargetModSkill:new(new_name, #_skill.tags > 0 and _skill.tags[1] or Skill.Compulsory)
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
  if spec.fix_target_func then
    skill.getFixedTargets = spec.fix_target_func
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

  local skill = FilterSkill:new(new_name, #_skill.tags > 0 and _skill.tags[1] or Skill.Compulsory)
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

  local skill = InvaliditySkill:new(new_name, #_skill.tags > 0 and _skill.tags[1] or Skill.Compulsory)
  fk.readStatusSpecToSkill(skill, spec)

  if spec.invalidity_func then
    skill.getInvalidity = spec.invalidity_func
  end
  if spec.invalidity_attackrange then
    skill.getInvalidityAttackRange = spec.invalidity_attackrange
  end
  skill.recheck_invalidity = not not spec.recheck_invalidity

  return skill
end

---@param spec VisibilitySpec
---@return VisibilitySkill
function SkillSkeleton:createVisibilitySkill(_skill, idx, key, attr, spec)
  local new_name = string.format("#%s_%d_visibility", _skill.name, idx)
  Fk:loadTranslationTable({ [new_name] = Fk:translate(_skill.name) }, Config.language)

  local skill = VisibilitySkill:new(new_name, #_skill.tags > 0 and _skill.tags[1] or Skill.Compulsory)
  fk.readStatusSpecToSkill(skill, spec)
  if spec.card_visible then skill.cardVisible = spec.card_visible end
  if spec.role_visible then skill.roleVisible = spec.role_visible end
  if spec.move_visible then skill.moveVisible = spec.move_visible end

  return skill
end

-- 将技能的选项框设置元表，仅用于主动技、视为技
function fk.readInteractionToSkill(skill, spec)
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
end

---@param _skill SkillSkeleton
---@param idx integer
---@param attr SkillAttribute
---@param spec ActiveSkillSpec
---@return ActiveSkill
function SkillSkeleton:createActiveSkill(_skill, idx, key, attr, spec)
  local new_name = string.format("#%s_%d_active", _skill.name, idx)
  Fk:loadTranslationTable({ [new_name] = Fk:translate(_skill.name) }, Config.language)

  local skill = ActiveSkill:new(new_name, #_skill.tags > 0 and _skill.tags[1] or Skill.NotFrequent)
  fk.readUsableSpecToSkill(skill, spec)

  local spec_can_use = spec.can_use
  if not spec_can_use then
    spec_can_use = ActiveSkill.canUse
  end

  ---@param curSkill ViewAsSkill
  ---@param player Player
  skill.canUse = function(curSkill, player, card, extra_data)
    if not curSkill:isEffectable(player) then return end
    if attr.check_effect_limit then
      for scope, _ in pairs(curSkill.max_use_time) do
        if not curSkill:withinTimesLimit(player, scope) then
          return false
        end
      end
    end
    if attr.check_skill_limit then
      if #_skill.max_use_time == 0 and _skill.max_branches_use_time then
        -- 写死的时机table，考虑到历史记录也是写死在这的，姑且先这样吧
        for _, scope in ipairs({Player.HistoryGame, Player.HistoryRound, Player.HistoryTurn, Player.HistoryPhase}) do
          if not _skill:withinBranchTimesLimit(player, nil, scope) then
            return false
          end
        end
      end
      for scope, _ in pairs(_skill.max_use_time) do
        if not _skill:withinTimesLimit(player, scope) then
          return false
        end
      end
    end
    return spec_can_use(curSkill, player, card, extra_data)
  end
  if spec.card_filter then skill.cardFilter = spec.card_filter end
  if spec.target_filter then skill.targetFilter = spec.target_filter end
  if spec.feasible then skill.feasible = spec.feasible end
  if spec.on_cost then skill.onCost = spec.on_cost end
  if spec.on_use then skill.onUse = spec.on_use end
  if spec.prompt then skill.prompt = spec.prompt end
  if spec.target_tip then skill.targetTip = spec.target_tip end
  if spec.handly_pile then skill.handly_pile = spec.handly_pile end
  if spec.click_count then skill.click_count = spec.click_count end

  fk.readInteractionToSkill(skill, spec)
  return skill
end

---@param spec CardSkillSpec
---@return CardSkill
function SkillSkeleton:createCardSkill(_skill, idx, key, attr, spec)
  local new_name = string.format("#%s_%d_cardskill", _skill.name, idx)
  Fk:loadTranslationTable({ [new_name] = Fk:translate(_skill.name) }, Config.language)

  local skill = CardSkill:new(new_name, #_skill.tags > 0 and _skill.tags[1] or Skill.NotFrequent)
  fk.readUsableSpecToSkill(skill, spec)

  if spec.can_use then skill.canUse = spec.can_use end
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
  if spec.fix_targets then skill.fixTargets = spec.fix_targets end
  if spec.offset_func then skill.preEffect = spec.offset_func end

  fk.readInteractionToSkill(skill, spec)
  return skill
end

---@param _skill SkillSkeleton
---@param idx integer
---@param attr SkillAttribute
---@param spec ViewAsSkillSpec
---@return ViewAsSkill
function SkillSkeleton:createViewAsSkill(_skill, idx, key, attr, spec)
  local new_name = string.format("#%s_%d_active", _skill.name, idx)
  Fk:loadTranslationTable({ [new_name] = Fk:translate(_skill.name) }, Config.language)

  local skill = ViewAsSkill:new(new_name, #_skill.tags > 0 and _skill.tags[1] or Skill.NotFrequent)
  fk.readUsableSpecToSkill(skill, spec)

  skill.viewAs = spec.view_as
  if spec.card_filter then
    skill.cardFilter = spec.card_filter
  end

  if type(spec.filter_pattern) == "table" then
    skill.filterPattern = function ()
      return spec.filter_pattern
    end
  else
    skill.filterPattern = spec.filter_pattern
  end

  if spec.target_filter then skill.targetFilter = spec.target_filter end
  if spec.feasible then skill.feasible = spec.feasible end
  if spec.on_use then skill.onUse = spec.on_use end

  if type(spec.pattern) == "string" then
    skill.pattern = spec.pattern
  end

  ---@param curSkill ViewAsSkill
  ---@param player Player
  local timeCheck = function(curSkill, player)
    if attr.check_effect_limit then
      for scope, _ in pairs(curSkill.max_use_time) do
        if not curSkill:withinTimesLimit(player, scope) then
          return false
        end
      end
    end
    if attr.check_skill_limit then
      if #_skill.max_use_time == 0 and _skill.max_branches_use_time then
        -- 写死的时机table，考虑到历史记录也是写死在这的，姑且先这样吧
        for _, scope in ipairs({Player.HistoryGame, Player.HistoryRound, Player.HistoryTurn, Player.HistoryPhase}) do
          if not _skill:withinBranchTimesLimit(player, nil, scope) then
            return false
          end
        end
      end
      for scope, _ in pairs(_skill.max_use_time) do
        if not _skill:withinTimesLimit(player, scope) then
          return false
        end
      end
    end
    return true
  end

  if type(spec.enabled_at_play) == "function" then
    skill.enabledAtPlay = function(curSkill, player)
      return timeCheck(curSkill, player) and spec.enabled_at_play(curSkill, player) and curSkill:isEffectable(player)
    end
  else
    skill.enabledAtPlay = function(curSkill, player)
      return timeCheck(curSkill, player) and ViewAsSkill.enabledAtPlay(curSkill, player)
    end
  end
  if type(spec.enabled_at_response) == "function" then
    skill.enabledAtResponse = function(curSkill, player, cardResponsing)
      return timeCheck(curSkill, player) and spec.enabled_at_response(curSkill, player, cardResponsing) and curSkill:isEffectable(player)
    end
  else
    skill.enabledAtResponse = function(curSkill, player, cardResponsing)
      return timeCheck(curSkill, player) and ViewAsSkill.enabledAtResponse(curSkill, player, cardResponsing)
    end
  end
  if spec.prompt then skill.prompt = spec.prompt end

  fk.readInteractionToSkill(skill, spec)

  if spec.before_use and type(spec.before_use) == "function" then
    skill.beforeUse = spec.before_use
  end

  if spec.after_use and type(spec.after_use) == "function" then
    skill.afterUse = spec.after_use
    skill.afterResponse = spec.after_use
  end

  if spec.click_count then skill.click_count = spec.click_count end

  if type(spec.enabled_at_nullification) == "function" then
    skill.enabledAtNullification = function(curSkill, player, cardData)
      return timeCheck(curSkill, player) and spec.enabled_at_nullification(curSkill, player, cardData) and curSkill:isEffectable(player)
    end
  else
    skill.enabledAtNullification = function(curSkill, player, cardData)
      return timeCheck(curSkill, player) and ViewAsSkill.enabledAtNullification(curSkill, player, cardData)
    end
  end

  skill.handly_pile = spec.handly_pile

  if spec.mute_card ~= nil then
    skill.mute_card = spec.mute_card
  else
    skill.mute_card = not (string.find(skill.pattern, "|") or skill.pattern == "." or string.find(skill.pattern, ","))
  end

  if spec.on_cost then skill.onCost = spec.on_cost end

  return skill
end

function SkillSkeleton:onAcquire(player, is_start)
  local room = player.room
  if self.attached_skill_name then
    for _, p in ipairs(room.alive_players) do
      if p ~= player then
        room:handleAddLoseSkills(p, self.attached_skill_name, nil, false, true)
      end
    end
  end
  if self.on_acquire then
    self.on_acquire(player, is_start)
  end
end

---@param player ServerPlayer
---@param is_death boolean?
function SkillSkeleton:onLose(player, is_death)
  local room = player.room
  if self.attached_skill_name then
    local skill_owners = table.filter(room.alive_players, function (p)
      return p:hasSkill(self.name, true)
    end)
    if #skill_owners == 0 then
      for _, p in ipairs(room.alive_players) do
        room:handleAddLoseSkills(p, "-" .. self.attached_skill_name, nil, false, true)
      end
    elseif #skill_owners == 1 then
      local p = skill_owners[1]
      room:handleAddLoseSkills(p, "-" .. self.attached_skill_name, nil, false, true)
    end
  end
  local lost_piles = {}
  if self.derived_piles then
    for _, pile_name in ipairs(self.derived_piles) do
      table.insertTableIfNeed(lost_piles, player:getPile(pile_name))
    end
  end
  for _, effect in ipairs(self.effects) do
    if effect.derived_piles then
      if type(effect.derived_piles) == "string" then
        effect.derived_piles = {effect.derived_piles}
      end
      for _, pile_name in ipairs(effect.derived_piles) do
        table.insertTableIfNeed(lost_piles, player:getPile(pile_name))
      end
    end
  end
  if #lost_piles > 0 then
    player.room:moveCards({
      ids = lost_piles,
      from = player,
      toArea = Card.DiscardPile,
      moveReason = fk.ReasonPutIntoDiscardPile,
    })
  end
  if self.on_lose then
    self.on_lose(player, is_death)
  end
end

-- 获得此技能时，触发此函数
---@param fn fun(self:SkillSkeleton, player:ServerPlayer, is_start:boolean?)
function SkillSkeleton:addAcquireEffect(fn)
  ---@param player ServerPlayer
  ---@param is_start boolean?
  self.on_acquire = function (player, is_start)
    fn(self, player, is_start)
  end
end

-- 失去此技能时，触发此函数
---@param fn fun(self:SkillSkeleton, player:ServerPlayer, is_death:boolean?)
function SkillSkeleton:addLoseEffect(fn)
  self.on_lose = function (player, is_death)
    fn(self, player, is_death)
  end
end

--- 获取技能动态技能名
---@param player Player
---@param lang? string
---@return string?
function SkillSkeleton:getDynamicName(player, lang)
  return self.dynamicName and self:dynamicName(player, lang)
end

---@param player Player
---@param lang? string
---@return string?
function SkillSkeleton:getDynamicDescription(player, lang)
  if table.contains(self.tags, Skill.Switch) or table.contains(self.tags, Skill.Rhyme) then
    local skill_name = self.name
    local switchState = player:getSwitchSkillState(skill_name)
    local descKey = ":" .. skill_name .. (switchState == fk.SwitchYang and "_yang" or "_yin")
    local translation = Fk:translate(descKey, lang)
    if translation ~= descKey then
      return translation
    end
  end
  return self.dynamicDesc and self:dynamicDesc(player, lang)
end

-- 获得技能的最大使用次数
---@param player Player @ 使用者
---@param scope integer @ 查询历史范围（默认为回合）
---@param to? Player @ 目标
---@return number? @ 最大使用次数，nil就是无限
function SkillSkeleton:getMaxUseTime(player, scope, to)
  scope = scope or Player.HistoryTurn
  local time = self.max_use_time[scope]
  local ret = time
  if type(time) == "function" then
    ret = time(self, player, to)
  end
  if ret == nil then return nil end
  return ret
end

-- 获得技能的最大使用次数（基于某个分支）
---@param player Player @ 使用者
---@param branch string @ 分支名（没有后缀）
---@param scope integer @ 查询历史范围（默认为回合）
---@param to? Player @ 目标
---@return number? @ 最大使用次数，nil就是无限
function SkillSkeleton:getBranchMaxUseTime(player, branch, scope, to)
  scope = scope or Player.HistoryTurn
  local times_table
  if type(self.max_branches_use_time) == "function" then
    times_table = self:max_branches_use_time(player)
  else
    times_table = self.max_branches_use_time
  end
  if not times_table then return nil end

  local ret = times_table[branch][scope]
  if ret == nil then return nil end
  return ret
end

-- 获得技能的剩余使用次数
---@param player Player @ 使用者
---@param scope integer @ 查询历史范围（默认为回合）
---@param to? Player @ 目标
---@return number? @ 剩余使用次数，nil就是无限
function SkillSkeleton:getRemainUseTime(player, scope, to)
  scope = scope or Player.HistoryTurn

  local limit = self:getMaxUseTime(player, scope, to)
  if limit == nil then return nil end

  return math.max(0, limit - player:usedSkillTimes(self.name, scope))
end

-- 判断一个角色是否在技能的次数限制内
---@param player Player @ 使用者
---@param scope? integer @ 查询历史范围（默认为回合）
---@param to? Player @ 目标
---@return boolean?
function SkillSkeleton:withinTimesLimit(player, scope, to)
  scope = scope or Player.HistoryTurn
  if not self:withinBranchTimesLimit(player, nil, scope) then return false end

  local limit = self:getMaxUseTime(player, scope, to)
  if limit == nil then return true end

  return self:getRemainUseTime(player, scope, to) > 0
end

-- 判断一个角色是否在技能的**所有分支**次数限制内
---@param player Player @ 使用者
---@param branch? string @ 查询分支范围（无则检查所有分支）
---@param scope? integer @ 查询历史范围（默认为回合）
---@param to? Player @ 目标
---@return boolean?
function SkillSkeleton:withinBranchTimesLimit(player, branch, scope, to)
  scope = scope or Player.HistoryTurn
  local times_table
  if type(self.max_branches_use_time) == "function" then
    times_table = self:max_branches_use_time(player)
  else
    times_table = self.max_branches_use_time
  end
  if not times_table then return true end

  if branch then
    local limit = (times_table[branch] or {})[scope]
    return not (limit and player:usedSkillTimes(self.name, scope, branch) >= limit)
  end

  local has_limit = false
  for target_branch, limits in pairs(times_table) do
    local ret = (limits or {})[scope]
    if ret ~= nil then
      has_limit = true
      if player:usedSkillTimes(self.name, scope, target_branch) < ret then
        return true
      end
    end
  end
  return not has_limit
end

---@param spec SkillSkeletonSpec
---@return SkillSkeleton
function fk.CreateSkill(spec)
  return SkillSkeleton:new(spec)
end

return SkillSkeleton
