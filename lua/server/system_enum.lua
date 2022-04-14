---@alias CardsMoveInfo {ids: integer[], from: integer|null, to: integer|null, toArea: CardArea, moveReason: CardMoveReason, proposer: integer, skillName: string|null, moveVisible: boolean|null, specialName: string|null, specialVisible: boolean|null }
---@alias MoveInfo {cardId: integer, fromArea: CardArea}
---@alias CardsMoveStruct {moveInfo: MoveInfo[], from: integer|null, to: integer|null, toArea: CardArea, moveReason: CardMoveReason, proposer: integer|null, skillName: string|null, moveVisible: boolean|null, specialName: string|null, specialVisible: boolean|null, fromSpecialName: string|null }

---@alias HpChangedData { num: integer, reason: string, skillName: string }
---@alias HpLostData { num: integer, skillName: string }
---@alias DamageStruct { from: integer|null, to: integer, damage: integer, damageType: DamageType, skillName: string }
---@alias RecoverStruct { who: integer, num: integer, recoverBy: integer|null, skillName: string|null }

---@alias DyingStruct { who: integer, damage: DamageStruct }
---@alias DeathStruct { who: integer, damage: DamageStruct }


---@alias MoveReason integer

fk.ReasonJustMove = 1
fk.ReasonDraw = 2
fk.ReasonDiscard = 3
fk.ReasonGive = 4
fk.ReasonPut = 5
fk.ReasonPutIntoDiscardPile = 6
fk.ReasonPrey = 7
fk.ReasonExchange = 8

---@alias DamageType integer

fk.NormalDamage = 1
fk.ThunderDamage = 2
fk.FireDamage = 3
