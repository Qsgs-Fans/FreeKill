---@class CardsMoveInfo
---@field public ids integer[]
---@field public from integer|null
---@field public to integer|null
---@field public toArea CardArea
---@field public moveReason CardMoveReason
---@field public proposer integer
---@field public skillName string|null
---@field public moveVisible boolean|null
---@field public specialName string|null
---@field public specialVisible boolean|null

---@class MoveInfo
---@field public cardId integer
---@field public fromArea CardArea
---@field public fromSpecialName string|null

---@class CardsMoveStruct
---@field public moveInfo MoveInfo[]
---@field public from integer|null
---@field public to integer|null
---@field public toArea CardArea
---@field public moveReason CardMoveReason
---@field public proposer integer|null
---@field public skillName string|null
---@field public moveVisible boolean|null
---@field public specialName string|null
---@field public specialVisible boolean|null

---@class PindianResult
---@field public toCard Card
---@field public winner ServerPlayer|null

---@class HpChangedData
---@field public num integer
---@field public reason string
---@field public skillName string
---@field public damageEvent DamageStruct|null

---@class HpLostData
---@field public num integer
---@field public skillName string

---@alias DamageType integer

fk.NormalDamage = 1
fk.ThunderDamage = 2
fk.FireDamage = 3

---@class DamageStruct
---@field public from ServerPlayer|null
---@field public to ServerPlayer
---@field public damage integer
---@field public card Card
---@field public chain boolean
---@field public damageType DamageType
---@field public skillName string
---@field public beginnerOfTheDamage boolean|null

---@class RecoverStruct
---@field public who ServerPlayer
---@field public num integer
---@field public recoverBy ServerPlayer|null
---@field public skillName string|null
---@field public card Card|null

---@class DyingStruct
---@field public who integer
---@field public damage DamageStruct

---@class DeathStruct
---@field public who integer
---@field public damage DamageStruct

---@class CardUseStruct
---@field public from integer
---@field public tos TargetGroup
---@field public card Card
---@field public toCard Card|null
---@field public responseToEvent CardUseStruct|null
---@field public nullifiedTargets interger[]|null
---@field public extraUse boolean|null
---@field public disresponsiveList integer[]|null
---@field public unoffsetableList integer[]|null
---@field public additionalDamage integer|null
---@field public customFrom integer|null
---@field public cardsResponded Card[]|null

---@class AimStruct
---@field public from integer
---@field public card Card
---@field public tos AimGroup
---@field public to integer
---@field public subTargets integer[]|null
---@field public targetGroup TargetGroup|null
---@field public nullifiedTargets integer[]|null
---@field public firstTarget boolean
---@field public additionalDamage integer|null
---@field public disresponsive boolean|null
---@field public unoffsetableList boolean|null
---@field public additionalResponseTimes table<string, integer>|integer|null
---@field public fixedAddTimesResponsors integer[]

---@class CardEffectEvent
---@field public from integer
---@field public to integer
---@field public subTargets integer[]|null
---@field public tos TargetGroup
---@field public card Card
---@field public toCard Card|null
---@field public responseToEvent CardEffectEvent|null
---@field public nullifiedTargets interger[]|null
---@field public extraUse boolean|null
---@field public disresponsiveList integer[]|null
---@field public unoffsetableList integer[]|null
---@field public additionalDamage integer|null
---@field public customFrom integer|null
---@field public cardsResponded Card[]|null
---@field public disresponsive boolean|null
---@field public unoffsetable boolean|null
---@field public isCancellOut boolean|null
---@field public fixedResponseTimes table<string, integer>|integer|null
---@field public fixedAddTimesResponsors integer[]

---@class SkillEffectEvent
---@field public from integer
---@field public tos integer[]
---@field public cards integer[]

---@class JudgeStruct
---@field public who ServerPlayer
---@field public card Card
---@field public reason string
---@field public pattern string

---@class CardResponseEvent
---@field public from integer
---@field public card Card
---@field public responseToEvent CardEffectEvent|null
---@field public skipDrop boolean|null
---@field public customFrom integer|null

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

---@class PindianStruct
---@field public from ServerPlayer
---@field public tos ServerPlayer[]
---@field public fromCard Card
---@field public results table<integer, PindianResult>
---@field public reason string

---@class LogMessage
---@field public type string
---@field public from integer
---@field public to integer[]
---@field public card integer[]
---@field public arg any
---@field public arg2 any
---@field public arg3 any
