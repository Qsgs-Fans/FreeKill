-- SPDX-License-Identifier: GPL-3.0-or-later

---@alias PlayerId integer

---@class CardsMoveInfo
---@field public ids integer[]
---@field public from? integer
---@field public to? integer
---@field public toArea? CardArea
---@field public moveReason? CardMoveReason
---@field public proposer? integer
---@field public skillName? string
---@field public moveVisible? boolean
---@field public specialName? string
---@field public specialVisible? boolean

---@class MoveInfo
---@field public cardId integer
---@field public fromArea CardArea
---@field public fromSpecialName? string

---@class CardsMoveStruct
---@field public moveInfo MoveInfo[]
---@field public from? integer
---@field public to? integer
---@field public toArea CardArea
---@field public moveReason CardMoveReason
---@field public proposer? integer
---@field public skillName? string
---@field public moveVisible? boolean
---@field public specialName? string
---@field public specialVisible? boolean
---@field public drawPilePosition? integer @ 移至牌堆的索引位置，值为-1代表置入牌堆底，或者牌堆牌数+1也为牌堆底

---@class PindianResult
---@field public toCard Card
---@field public winner? ServerPlayer

--- 描述和一次体力变化有关的数据
---@class HpChangedData
---@field public num integer @ 体力变化量，可能是正数或者负数
---@field public shield_lost integer|nil
---@field public reason string @ 体力变化原因
---@field public skillName string @ 引起体力变化的技能名
---@field public damageEvent? DamageStruct @ 引起这次体力变化的伤害数据
---@field public preventDying? boolean @ 是否阻止本次体力变更流程引发濒死流程

--- 描述跟失去体力有关的数据
---@class HpLostData
---@field public num integer @ 失去体力的数值
---@field public skillName string @ 导致这次失去的技能名

---@alias DamageType integer

fk.NormalDamage = 1
fk.ThunderDamage = 2
fk.FireDamage = 3
fk.IceDamage = 4

--- DamageStruct 用来描述和伤害事件有关的数据。
---@class DamageStruct
---@field public from? ServerPlayer @ 伤害来源
---@field public to ServerPlayer @ 伤害目标
---@field public damage integer @ 伤害值
---@field public card? Card @ 造成伤害的牌
---@field public chain? boolean @ 伤害是否是铁索传导的伤害
---@field public damageType? DamageType @ 伤害的属性
---@field public skillName? string @ 造成本次伤害的技能名
---@field public beginnerOfTheDamage? boolean @ 是否是本次铁索传导的起点

--- 用来描述和回复体力有关的数据。
---@class RecoverStruct
---@field public who ServerPlayer @ 回复体力的角色
---@field public num integer @ 回复值
---@field public recoverBy? ServerPlayer @ 此次回复的回复来源
---@field public skillName? string @ 因何种技能而回复
---@field public card? Card @ 造成此次回复的卡牌

---@class DyingStruct
---@field public who integer
---@field public damage DamageStruct
---@field public ignoreDeath? boolean

---@class DeathStruct
---@field public who integer
---@field public damage DamageStruct

--- askForUseCard中的extra_data
---@class UseExtraData
---@field public must_targets? integer[] @ 必须选择这些目标
---@field public include_targets? integer[] @ 必须选其中一个目标
---@field public exclusive_targets? integer[] @ 只能选择这些目标
---@field public bypass_distances? boolean @ 无距离限制？
---@field public bypass_times? boolean @ 无次数限制？
---@field public playing? boolean @ (AI专用) 出牌阶段？

---@class CardUseStruct
---@field public from integer
---@field public tos TargetGroup
---@field public card Card
---@field public toCard? Card
---@field public responseToEvent? CardUseStruct
---@field public nullifiedTargets? integer[]
---@field public extraUse? boolean
---@field public disresponsiveList? integer[]
---@field public unoffsetableList? integer[]
---@field public additionalDamage? integer
---@field public additionalRecover? integer
---@field public customFrom? integer
---@field public cardsResponded? Card[]
---@field public prohibitedCardNames? string[]
---@field public damageDealt? table<PlayerId, number>

---@class AimStruct
---@field public from integer
---@field public card Card
---@field public tos AimGroup
---@field public to integer
---@field public subTargets? integer[]
---@field public targetGroup? TargetGroup
---@field public nullifiedTargets? integer[]
---@field public firstTarget boolean
---@field public additionalDamage? integer
---@field public additionalRecover? integer
---@field public disresponsive? boolean
---@field public unoffsetableList? boolean
---@field public additionalResponseTimes? table<string, integer>|integer
---@field public fixedAddTimesResponsors? integer[]

---@class CardEffectEvent
---@field public from integer
---@field public to integer
---@field public subTargets? integer[]
---@field public tos TargetGroup
---@field public card Card
---@field public toCard? Card
---@field public responseToEvent? CardEffectEvent
---@field public nullifiedTargets? integer[]
---@field public extraUse? boolean
---@field public disresponsiveList? integer[]
---@field public unoffsetableList? integer[]
---@field public additionalDamage? integer
---@field public additionalRecover? integer
---@field public customFrom? integer
---@field public cardsResponded? Card[]
---@field public disresponsive? boolean
---@field public unoffsetable? boolean
---@field public isCancellOut? boolean
---@field public fixedResponseTimes? table<string, integer>|integer
---@field public fixedAddTimesResponsors? integer[]
---@field public prohibitedCardNames? string[]

---@class SkillEffectEvent
---@field public from integer
---@field public tos integer[]
---@field public cards integer[]

---@class JudgeStruct
---@field public who ServerPlayer
---@field public card Card
---@field public reason string
---@field public pattern string
---@field public skipDrop? boolean

---@class CardResponseEvent
---@field public from integer
---@field public card Card
---@field public responseToEvent? CardEffectEvent
---@field public skipDrop? boolean
---@field public customFrom? integer

---@class AskForCardUse
---@field public user ServerPlayer
---@field public cardName string
---@field public pattern string
---@field public result CardUseStruct

---@class AskForCardResponse
---@field public user ServerPlayer
---@field public cardName string
---@field public pattern string
---@field public result Card

---@alias CardMoveReason integer

fk.ReasonJustMove = 1
fk.ReasonDraw = 2
fk.ReasonDiscard = 3
fk.ReasonGive = 4
fk.ReasonPut = 5
fk.ReasonPutIntoDiscardPile = 6
fk.ReasonPrey = 7
fk.ReasonExchange = 8
fk.ReasonUse = 9
fk.ReasonResonpse = 10
fk.ReasonJudge = 11
fk.ReasonRecast = 12

---@class PindianStruct
---@field public from ServerPlayer
---@field public tos ServerPlayer[]
---@field public fromCard Card
---@field public results table<integer, PindianResult>
---@field public reason string

---@class LogMessage
---@field public type string
---@field public from? integer
---@field public to? integer[]
---@field public card? integer[]
---@field public arg? any
---@field public arg2? any
---@field public arg3? any

---@class SkillUseStruct
---@field public skill Skill
---@field public willUse boolean

---@class DrawCardStruct
---@field public who ServerPlayer
---@field public num number
---@field public skillName string
---@field public fromPlace "top"|"bottom"
