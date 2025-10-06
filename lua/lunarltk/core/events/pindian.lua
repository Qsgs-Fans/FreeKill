
--- PindianData 拼点的数据
---@class PindianDataSpec
---@field public from ServerPlayer @ 拼点发起者
---@field public tos ServerPlayer[] @ 拼点目标
---@field public fromCard? Card @ 拼点发起者的初始拼点牌
---@field public results table<ServerPlayer, PindianResult> @ 所有的拼点结果
---@field public reason string @ 拼点原因，一般为技能名
---@field public expandCards? table<ServerPlayer, AskToCardsParams> @ 修改的拼点选牌（暂行，先给手杀笮融使用，后面看有没别的法子）

--- PindianResult 拼点结果
---@class PindianResult
---@field public toCard? Card @ 被拼点者的拼点牌
---@field public winner? ServerPlayer @ 赢家，可能不存在

--- SinglePindianData 拼点的数据
---@class SinglePindianDataSpec
---@field public from ServerPlayer @ 拼点发起者
---@field public to ServerPlayer @ 拼点目标
---@field public fromCard Card @ 拼点发起者的拼点牌
---@field public toCard Card @ 拼点目标的拼点牌
---@field public reason string @ 拼点原因，一般为技能名
---@field public winner? ServerPlayer @ 拼点赢家，可能没有

--- 拼点的数据
---@class PindianData: PindianDataSpec, TriggerData
PindianData = TriggerData:subclass("PindianData")

--- 单次拼点的数据
---@class SinglePindianData: SinglePindianDataSpec, TriggerData
SinglePindianData = TriggerData:subclass("SinglePindianData")

---@class PindianEvent: TriggerEvent
---@field data PindianData
local PindianEvent = TriggerEvent:subclass("PindianEvent")

---@class SinglePindianEvent: TriggerEvent
---@field data SinglePindianData
local SinglePindianEvent = TriggerEvent:subclass("SinglePindianEvent")

---@class fk.StartPindian: PindianEvent
fk.StartPindian = PindianEvent:subclass("fk.StartPindian")
---@class fk.PindianCardsDisplayed: PindianEvent
fk.PindianCardsDisplayed = PindianEvent:subclass("fk.PindianCardsDisplayed")
---@class fk.PindianResultConfirmed: SinglePindianEvent
fk.PindianResultConfirmed = SinglePindianEvent:subclass("fk.PindianResultConfirmed")
---@class fk.PindianFinished: PindianEvent
fk.PindianFinished = PindianEvent:subclass("fk.PindianFinished")

---@alias PindianTrigFunc fun(self: TriggerSkill, event: PindianEvent,
---  target: ServerPlayer, player: ServerPlayer, data: PindianData): any
---@alias SinglePindianFunc fun(self: TriggerSkill, event: SinglePindianEvent,
---  target: ServerPlayer, player: ServerPlayer, data: SinglePindianData): any
---
---@class SkillSkeleton
---@field public addEffect fun(self: SkillSkeleton, key: PindianEvent,
---  data: TrigSkelSpec<PindianTrigFunc>, attr: TrigSkelAttribute?): SkillSkeleton
---@field public addEffect fun(self: SkillSkeleton, key: SinglePindianEvent,
---  data: TrigSkelSpec<SinglePindianFunc>, attr: TrigSkelAttribute?): SkillSkeleton
