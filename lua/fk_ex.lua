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
-- LegacyTriggerSkill = require "compat.trigger_legacy"
ActiveSkill = require "core.skill_type.active"
CardSkill = require "core.skill_type.cardskill"
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

-- dofile "lua/compat/fk_ex.lua"

---@param skill SkillSkeleton|Skill
---@param spec table
function fk.readCommonSpecToSkill(skill, spec)
  skill.mute = spec.mute
  skill.no_indicate = spec.no_indicate
  skill.anim_type = spec.anim_type
  skill.audio_index = spec.audio_index

  if spec.relate_to_place then
    assert(type(spec.relate_to_place) == "string")
    skill.relate_to_place = spec.relate_to_place
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
  skill.card_num = spec.card_num or skill.card_num
  skill.min_card_num = spec.min_card_num or skill.min_card_num
  skill.max_card_num = spec.max_card_num or skill.max_card_num
  skill.max_use_time = {
    spec.max_phase_use_time,
    spec.max_turn_use_time,
    spec.max_round_use_time,
    spec.max_game_use_time,
  }
  skill.distance_limit = spec.distance_limit or skill.distance_limit
  skill.expand_pile = spec.expand_pile
  skill.times = spec.times or skill.times
  skill.is_delay_effect = not not spec.is_delay_effect
  skill.late_refresh = not not spec.late_refresh
  skill.click_count = not not spec.click_count
end

function fk.readStatusSpecToSkill(skill, spec)
  fk.readCommonSpecToSkill(skill, spec)
  if spec.global then
    skill.global = spec.global
  end
end

---@class UsableSkillSpec: SkillSpec
---@field public main_skill? UsableSkill
---@field public max_use_time? integer[]
---@field public expand_pile? string | integer[] | fun(self: UsableSkill, player: ServerPlayer): integer[]|string? @ 额外牌堆，牌堆名称或卡牌id表
---@field public derived_piles? string | string[] @ 与某效果联系起来的私人牌堆名，失去该效果时将之置入弃牌堆(@deprecated)
---@field public max_phase_use_time? integer  @ 每阶段使用次数上限
---@field public max_turn_use_time? integer  @ 每回合使用次数上限
---@field public max_round_use_time? integer  @ 每回合使用次数上限
---@field public max_game_use_time? integer  @ 整场游戏使用次数上限
---@field public times? integer | fun(self: UsableSkill, player: Player): integer
---@field public min_target_num? integer
---@field public max_target_num? integer
---@field public target_num? integer
---@field public min_card_num? integer
---@field public max_card_num? integer
---@field public card_num? integer
---@field public distance_limit? integer @ 目标距离限制，与目标距离小于等于此值方可使用

---@class StatusSkillSpec: SkillSpec

---@class ActiveSkillSpec: UsableSkillSpec
---@field public can_use? fun(self: ActiveSkill, player: Player): any @ 判断主动技能否发动
---@field public card_filter? fun(self: ActiveSkill, player: Player, to_select: integer, selected: integer[], selected_targets: Player[]): any @ 判断卡牌能否选择
---@field public target_filter? fun(self: ActiveSkill, player: Player?, to_select: Player, selected: Player[], selected_cards: integer[], card: Card?, extra_data: UseExtraData|table?): any @ 判定目标能否选择
---@field public feasible? fun(self: ActiveSkill, player: Player, selected: Player[], selected_cards: integer[], card: Card): any @ 判断卡牌和目标是否符合技能限制
---@field public on_use? fun(self: ActiveSkill, room: Room, skillUseEvent: SkillUseData): any
---@field public prompt? string|fun(self: ActiveSkill, player: Player, selected_cards: integer[], selected_targets: Player[]): string @ 提示信息
---@field public interaction? fun(self: ActiveSkill, player: Player): table? @ 选项框
---@field public target_tip? fun(self: ActiveSkill, player: Player, to_select: Player, selected: Player[], selected_cards: integer[], card?: Card, selectable: boolean, extra_data: any): string|TargetTipDataSpec? @ 显示在目标武将牌脸上的提示
---@field public handly_pile? boolean @ 是否能够选择“如手牌使用或打出”的牌
---@field public click_count? boolean @ 是否在点击按钮瞬间就计数并播放特效和语音

---@class CardSkillSpec: UsableSkillSpec
---@field public mod_target_filter? fun(self: ActiveSkill, player: Player, to_select: Player, selected: Player[], card: Card, extra_data: any): any @ 判定目标是否合法（例如不能杀自己，火攻无手牌目标）
---@field public target_filter? fun(self: CardSkill, player: Player?, to_select: Player, selected: Player[], selected_cards: integer[], card?: Card, extra_data: any): any @ 判定目标能否选择
---@field public feasible? fun(self: CardSkill, player: Player, selected: Player[], selected_cards: integer[]): any @ 判断卡牌和目标是否符合技能限制
---@field public can_use? fun(self: CardSkill, player: Player, card: Card, extra_data: any): any @ 判断卡牌技能否发动
---@field public on_use? fun(self: CardSkill, room: Room, cardUseEvent: UseCardData): any
---@field public fix_targets? fun(self: CardSkill, player: Player, card: Card, extra_data: any): Player[]? @ 设置固定目标
---@field public on_action? fun(self: CardSkill, room: Room, cardUseEvent: UseCardData, finished: boolean): any
---@field public about_to_effect? fun(self: CardSkill, room: Room, effect: CardEffectData): boolean? @ 生效前判断，返回true则取消效果
---@field public on_effect? fun(self: CardSkill, room: Room, effect: CardEffectData): any
---@field public on_nullified? fun(self: CardSkill, room: Room, effect: CardEffectData): any @ (仅用于延时锦囊)被抵消时执行内容
---@field public offset_func? fun(self: CardSkill, room: Room, effect: CardEffectData): any @ 重新定义抵消方式
---@field public prompt? string|fun(self: CardSkill, player: Player, selected_cards: integer[], selected_targets: Player[], extra_data: any): string @ 提示信息
---@field public interaction? any
---@field public target_tip? fun(self: CardSkill, player: Player, to_select: Player, selected: Player[], selected_cards: integer[], card?: Card, selectable: boolean, extra_data: any): string|TargetTipDataSpec? @ 显示在目标武将牌脸上的提示

---@class ViewAsSkillSpec: UsableSkillSpec
---@field public filter_pattern? table|fun(self: ViewAsSkill, player: Player): table
---@field public card_filter? fun(self: ViewAsSkill, player: Player, to_select: integer, selected: integer[], selected_targets: Player[]): any @ 判断卡牌能否选择
---@field public view_as fun(self: ViewAsSkill, player: Player, cards: integer[]): Card? @ 判断转化为什么牌
---@field public pattern? string
---@field public enabled_at_play? fun(self: ViewAsSkill, player: Player): any
---@field public enabled_at_response? fun(self: ViewAsSkill, player: Player, response: boolean): any
---@field public before_use? fun(self: ViewAsSkill, player: ServerPlayer, use: UseCardDataSpec): string? @ 使用/打出前执行的内容，返回字符串则取消此次使用，返回技能名则在本次询问中禁止使用此技能
---@field public after_use? fun(self: ViewAsSkill, player: ServerPlayer, use: UseCardData | RespondCardData): string? @ 使用/打出此牌后执行的内容
---@field public prompt? string|fun(self: ViewAsSkill, player: Player, selected_cards: integer[], selected: Player[]): string
---@field public interaction? fun(self: ViewAsSkill, player: Player): table? @ 选项框
---@field public handly_pile? boolean @ 是否能够选择“如手牌使用或打出”的牌
---@field public mute_card? boolean @ 是否不播放卡牌特效和语音。一个牌名的默认不播放，其他默认播放
---@field public click_count? boolean @ 是否在点击按钮瞬间就计数并播放特效和语音
---@field public enabled_at_nullification? fun(self: ViewAsSkill, player: Player, data: CardEffectData): boolean? @ 判断一张牌是否能被此技能转化无懈来响应

---@class DistanceSpec: StatusSkillSpec
---@field public correct_func? fun(self: DistanceSkill, from: Player, to: Player): integer?
---@field public fixed_func? fun(self: DistanceSkill, from: Player, to: Player): integer?

---@class ProhibitSpec: StatusSkillSpec
---@field public is_prohibited? fun(self: ProhibitSkill, from: Player?, to: Player, card: Card): any
---@field public prohibit_use? fun(self: ProhibitSkill, player: Player, card: Card): any
---@field public prohibit_response? fun(self: ProhibitSkill, player: Player, card: Card): any
---@field public prohibit_discard? fun(self: ProhibitSkill, player: Player, card: Card): any
---@field public prohibit_pindian? fun(self: ProhibitSkill, from: Player, to: Player): any

---@class AttackRangeSpec: StatusSkillSpec
---@field public correct_func? fun(self: AttackRangeSkill, from: Player, to: Player): number?
---@field public fixed_func? fun(self: AttackRangeSkill, player: Player): number?  @ 判定角色的锁定攻击范围初值
---@field public final_func? fun(self: AttackRangeSkill, player: Player): number?  @ 判定角色的锁定攻击范围终值
---@field public within_func? fun(self: AttackRangeSkill, from: Player, to: Player): any @ 判定to角色是否锁定在角色from攻击范围内
---@field public without_func? fun(self: AttackRangeSkill, from: Player, to: Player): any @ 判定to角色是否锁定在角色from攻击范围外

---@class MaxCardsSpec: StatusSkillSpec
---@field public correct_func? fun(self: MaxCardsSkill, player: Player): number?
---@field public fixed_func? fun(self: MaxCardsSkill, player: Player): number?
---@field public exclude_from? fun(self: MaxCardsSkill, player: Player, card: Card): any @ 判定某牌是否不计入手牌上限

---@class TargetModSpec: StatusSkillSpec
---@field public bypass_times? fun(self: TargetModSkill, player: Player, skill: ActiveSkill, scope: integer, card?: Card, to?: Player): any @ 是否无次数限制
---@field public residue_func? fun(self: TargetModSkill, player: Player, skill: ActiveSkill, scope: integer, card?: Card, to?: Player): number? @ 令使用次数上限增加多少
---@field public fix_times_func? fun(self: TargetModSkill, player: Player, skill: ActiveSkill, scope: integer, card?: Card, to?: Player): number? @ 锁定使用次数上限
---@field public fix_target_func? fun(self: TargetModSkill, player: Player, skill: ActiveSkill, card?: Card, extra_data: UseExtraData): integer[]? @ 修改默认目标
---@field public bypass_distances? fun(self: TargetModSkill, player: Player, skill: ActiveSkill, card?: Card, to?: Player): any @ 是否无距离限制
---@field public distance_limit_func? fun(self: TargetModSkill, player: Player, skill: ActiveSkill, card?: Card, to?: Player): number?
---@field public extra_target_func? fun(self: TargetModSkill, player: Player, skill: ActiveSkill, card?: Card): number?
---@field public target_tip_func? fun(self: TargetModSkill, player: Player, to_select: Player, selected: Player[], selected_cards: integer[], card?: Card, selectable: boolean, extra_data: any): string|TargetTipDataSpec?

---@class FilterSpec: StatusSkillSpec
---@field public card_filter? fun(self: FilterSkill, card: Card, player: Player, isJudgeEvent: boolean?): any
---@field public view_as? fun(self: FilterSkill, player: Player, card: Card): Card?
---@field public equip_skill_filter? fun(self: FilterSkill, skill: Skill, player: Player): string?
---@field public handly_cards? fun(self: FilterSkill, player: Player): integer[]? @ 视为拥有可以如手牌般使用或打出的牌


---@class InvaliditySpec: StatusSkillSpec
---@field public invalidity_func? fun(self: InvaliditySkill, from: Player, skill: Skill): any @ 判定角色的技能是否无效
---@field public invalidity_attackrange? fun(self: InvaliditySkill, player: Player, card: Weapon): any @ 判定武器的攻击范围是否无效
---@field public recheck_invalidity? boolean @ 是否涉及其他技能的失效性

---@class VisibilitySpec: StatusSkillSpec
---@field public card_visible? fun(self: VisibilitySkill, player: Player, card: Card): any @ 某牌的可见性
---@field public move_visible? fun(self: VisibilitySkill, player: Player, info: MoveInfo, move: MoveCardsDataSpec): any @ 某牌在某次移动中的可见性
---@field public role_visible? fun(self: VisibilitySkill, player: Player, target: Player): any @ 身份的可见性

---@class CardSpec
---@field public name string @ 卡牌的名字
---@field public suit? Suit @ 卡牌的花色（四色及无花色）
---@field public number? integer @ 卡牌的点数（0到K）
---@field public skill? ActiveSkill
---@field public special_skills? string[]
---@field public is_damage_card? boolean @ 是否为伤害类卡牌
---@field public multiple_targets? boolean @ 是否为多目标卡牌
---@field public stackable_delayed? boolean @ 是否为可堆叠的延时锦囊牌
---@field public is_passive? boolean @ 是否为被动使用的卡牌，如闪、无懈
---@field public extra_data? table @ 保存其他信息的键值表，如“合纵”、“应变”、“赠予”等

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
  card.stackable_delayed = spec.stackable_delayed
  card.is_passive = spec.is_passive
  card.extra_data = spec.extra_data
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
---@field public minComp? integer @ 最小电脑数，负数为实际玩家数+此数。创建房间后自动添加，无视服务器设置
---@field public maxComp? integer @ 最大电脑数，负数为实际玩家数+此数
---@field public rule? string @ 规则（通过技能完成，通常用来为特定角色及特定时机提供触发事件）
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
---@field public friend_enemy_judge? fun(self: GameMode, targetOne: ServerPlayer | Player, targetTwo: ServerPlayer | Player): boolean? @ 敌友判断
---@field public build_draw_pile? fun(self: GameMode): integer[], integer[]

---@param spec GameModeSpec
---@return GameMode
function fk.CreateGameMode(spec)
  assert(type(spec.name) == "string")
  assert(type(spec.minPlayer) == "number")
  assert(type(spec.maxPlayer) == "number")
  local ret = GameMode:new(spec.name, spec.minPlayer, spec.maxPlayer)
  ret.minComp = spec.minComp or 0
  ret.maxComp = spec.maxComp or -1
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
  if spec.friend_enemy_judge then
    assert(type(spec.winner_getter) == "function")
    ret.friendEnemyJudge = spec.friend_enemy_judge
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
---@field qml_path? string | fun(name: string, value?: any, player?: Player): string
---@field qml_data? fun(name: string, value?: any, player?: Player): any
---@field how_to_show? fun(name: string, value?: any, player?: Player): string?

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
---@field target_tip fun(self: ActiveSkill, player: Player, to_select: Player, selected: Player[], selected_cards: integer[], card: Card, selectable: boolean, extra_data: any): string|TargetTipDataSpec?

---@class ChooseGeneralSpec
---@field name string
---@field card_filter fun(to_select: string, selected: string[], data: string[], extra_data: any): boolean?
---@field feasible fun(selected: string[], data: string[], extra_data: any): boolean?
---@field default_choice? fun(data: string[], extra_data: any): string[]
---@field prompt? string | fun(data: string[], extra_data: any): string
