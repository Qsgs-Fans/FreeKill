---@class CardsMoveInfo
---@field ids integer[]
---@field from integer|null
---@field to integer|null
---@field toArea CardArea
---@field moveReason CardMoveReason
---@field proposer integer
---@field skillName string|null
---@field moveVisible boolean|null
---@field specialName string|null
---@field specialVisible boolean|null

---@class MoveInfo
---@field cardId integer
---@field fromArea CardArea
---@field fromSpecialName string|null

---@class CardsMoveStruct
---@field moveInfo MoveInfo[]
---@field from integer|null
---@field to integer|null
---@field toArea CardArea
---@field moveReason CardMoveReason
---@field proposer integer|null
---@field skillName string|null
---@field moveVisible boolean|null
---@field specialName string|null
---@field specialVisible boolean|null

---@class PindianResult
---@field toCard Card
---@field winner ServerPlayer|null

---@class HpChangedData
---@field num integer
---@field reason string
---@field skillName string
---@field damageEvent DamageStruct|null

---@class HpLostData
---@field num integer
---@field skillName string

---@alias DamageType integer

fk.NormalDamage = 1
fk.ThunderDamage = 2
fk.FireDamage = 3

---@class DamageStruct
---@field from ServerPlayer|null
---@field to ServerPlayer
---@field damage integer
---@field card Card
---@field chain boolean
---@field damageType DamageType
---@field skillName string
---@field beginnerOfTheDamage boolean|null

---@class RecoverStruct
---@field who ServerPlayer
---@field num integer
---@field recoverBy ServerPlayer|null
---@field skillName string|null
---@field card Card|null

---@class DyingStruct
---@field who integer
---@field damage DamageStruct

---@class DeathStruct
---@field who integer
---@field damage DamageStruct

---@class CardUseStruct
---@field from integer
---@field tos TargetGroup
---@field card Card
---@field toCard Card|null
---@field responseToEvent CardUseStruct|null
---@field nullifiedTargets interger[]|null
---@field extraUse boolean|null
---@field disresponsiveList integer[]|null
---@field unoffsetableList integer[]|null
---@field additionalDamage integer|null
---@field customFrom integer|null
---@field cardsResponded Card[]|null

---@class AimStruct
---@field from integer
---@field card Card
---@field tos AimGroup
---@field to integer
---@field subTargets integer[]|null
---@field targetGroup TargetGroup|null
---@field nullifiedTargets integer[]|null
---@field firstTarget boolean
---@field additionalDamage integer|null
---@field disresponsive boolean|null
---@field unoffsetableList boolean|null
---@field additionalResponseTimes table<string, integer>|integer|null
---@field fixedAddTimesResponsors integer[]

---@class CardEffectEvent
---@field from integer
---@field to integer
---@field subTargets integer[]|null
---@field tos TargetGroup
---@field card Card
---@field toCard Card|null
---@field responseToEvent CardEffectEvent|null
---@field nullifiedTargets interger[]|null
---@field extraUse boolean|null
---@field disresponsiveList integer[]|null
---@field unoffsetableList integer[]|null
---@field additionalDamage integer|null
---@field customFrom integer|null
---@field cardsResponded Card[]|null
---@field disresponsive boolean|null
---@field unoffsetable boolean|null
---@field isCancellOut boolean|null
---@field fixedResponseTimes table<string, integer>|integer|null
---@field fixedAddTimesResponsors integer[]

---@class SkillEffectEvent
---@field from integer
---@field tos integer[]
---@field cards integer[]

---@class JudgeStruct
---@field who ServerPlayer
---@field card Card
---@field reason string
---@field pattern string

---@class CardResponseEvent
---@field from integer
---@field card Card
---@field responseToEvent CardEffectEvent|null
---@field skipDrop boolean|null
---@field customFrom integer|null

---@class AskForCardUse
---@field user ServerPlayer
---@field cardName string
---@field pattern string
---@field result CardUseStruct

---@class AskForCardResponse
---@field user ServerPlayer
---@field cardName string
---@field pattern string
---@field result Card

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
---@field from ServerPlayer
---@field tos ServerPlayer[]
---@field fromCard Card
---@field results table<integer, PindianResult>
---@field reason string

---@class LogMessage
---@field type string
---@field from integer
---@field to integer[]
---@field card integer[]
---@field arg any
---@field arg2 any
---@field arg3 any
