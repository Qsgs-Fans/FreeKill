---@alias CardsMoveInfo {ids: integer[], from: integer|null, to: integer|null, toArea: CardArea, moveReason: CardMoveReason, proposer: integer, skillName: string|null, moveVisible: boolean|null, specialName: string|null, specialVisible: boolean|null }
---@alias MoveInfo {cardId: integer, fromArea: CardArea}
---@alias CardsMoveStruct {moveInfo: MoveInfo[], from: integer|null, to: integer|null, toArea: CardArea, moveReason: CardMoveReason, proposer: integer|null, skillName: string|null, moveVisible: boolean|null, specialName: string|null, specialVisible: boolean|null, fromSpecialName: string|null }

---@alias HpChangedData { num: integer, reason: string, skillName: string }
---@alias HpLostData { num: integer, skillName: string }
---@alias DamageStruct { from: ServerPlayer|null, to: ServerPlayer, damage: integer, card: Card, damageType: DamageType, skillName: string }
---@alias RecoverStruct { who: ServerPlayer, num: integer, recoverBy: ServerPlayer|null, skillName: string|null, card: Card|null }

---@alias DyingStruct { who: integer, damage: DamageStruct }
---@alias DeathStruct { who: integer, damage: DamageStruct }

---@alias CardUseStruct { from: integer, tos: TargetGroup, card: Card, toCard: Card|null, responseToEvent: CardUseStruct|null, nullifiedTargets: interger[]|null, extraUse: boolean|null, disresponsiveList: integer[]|null, unoffsetableList: integer[]|null, addtionalDamage: integer|null, customFrom: integer|null, cardsResponded: Card[]|null }
---@alias AimStruct { from: integer, card: Card, tos: AimGroup, to: integer, subTargets: integer[]|null, targetGroup: TargetGroup|null, nullifiedTargets: integer[]|null, firstTarget: boolean, additionalDamage: integer|null, disresponsive: boolean|null, unoffsetableList: boolean|null }
---@alias CardEffectEvent { from: integer, to: integer, subTargets: integer[]|null, tos: TargetGroup, card: Card, toCard: Card|null, responseToEvent: CardUseStruct|null, nullifiedTargets: interger[]|null, extraUse: boolean|null, disresponsiveList: integer[]|null, unoffsetableList: integer[]|null, addtionalDamage: integer|null, customFrom: integer|null, cardsResponded: Card[]|null, disresponsive: boolean|null, unoffsetable: boolean|null }
---@alias SkillEffectEvent { from: integer, tos: integer[], cards: integer[] }

---@alias JudgeStruct { who: ServerPlayer, card: Card, reason: string, pattern: string }
---@alias CardResponseEvent { from: integer, card: Card, responseToEvent: CardEffectEvent|null, skipDrop: boolean|null, customFrom: integer|null }

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

---@alias DamageType integer

fk.NormalDamage = 1
fk.ThunderDamage = 2
fk.FireDamage = 3

---@alias LogMessage {type: string, from: integer, to: integer[], card: integer[], arg: any, arg2: any, arg3: any}
