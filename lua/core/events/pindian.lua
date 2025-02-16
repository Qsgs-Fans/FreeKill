
--- PindianData 拼点的数据
---@class PindianDataSpec
---@field public from ServerPlayer @ 拼点发起者
---@field public tos ServerPlayer[] @ 拼点目标
---@field public fromCard Card @ 拼点发起者拼点牌
---@field public _fromCard Card @ 拼点发起者的拼点牌（实体）
---@field public results table<integer, PindianResult> @ 结果
---@field public reason string @ 拼点原因

--- PindianResult 拼点结果
---@class PindianResult
---@field public toCard Card @ 被拼点者的拼点牌
---@field public _toCard Card @ 被拼点者的拼点牌（实体）
---@field public winner? ServerPlayer @ 赢家，可能不存在

--- 拼点的数据
---@class PindianData: PindianDataSpec, TriggerData
PindianData = TriggerData:subclass("PindianData")

---@class PindianEvent: TriggerEvent
---@field data PindianData
local PindianEvent = TriggerEvent:subclass("PindianEvent")


---@class fk.StartPindian: PindianEvent
fk.StartPindian = PindianEvent:subclass("fk.StartPindian")
---@class fk.PindianCardsDisplayed: PindianEvent
fk.PindianCardsDisplayed = PindianEvent:subclass("fk.PindianCardsDisplayed")
---@class fk.PindianResultConfirmed: PindianEvent
fk.PindianResultConfirmed = PindianEvent:subclass("fk.PindianResultConfirmed")
---@class fk.PindianFinished: PindianEvent
fk.PindianFinished = PindianEvent:subclass("fk.PindianFinished")

---@alias PindianTrigFunc fun(self: TriggerSkill, event: PindianEvent,
---  target: ServerPlayer, player: ServerPlayer, data: PindianData): any

---@class SkillSkeleton
---@field public addEffect fun(self: SkillSkeleton, key: PindianEvent,
---  data: TrigSkelSpec<PindianTrigFunc>, attr: TrigSkelAttribute?): SkillSkeleton
