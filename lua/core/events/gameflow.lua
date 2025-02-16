
--- DrawInitialData 关于摸起始手牌的数据
---@class DrawInitialDataSpec
---@field public num integer @ 摸牌数

--- 关于摸起始手牌的数据
---@class DrawInitialData: DrawInitialDataSpec, TriggerData
DrawInitialData = TriggerData:subclass("DrawInitialData")

---@class DrawInitialEvent: TriggerEvent
---@field data DrawInitialData
local DrawInitialEvent = TriggerEvent:subclass("DrawInitialEvent")

---@class fk.DrawInitialCards: DrawInitialEvent
fk.DrawInitialCards = DrawInitialEvent:subclass("fk.DrawInitialCards")
---@class fk.AfterDrawInitialCards: DrawInitialEvent
fk.AfterDrawInitialCards = DrawInitialEvent:subclass("fk.AfterDrawInitialCards")

---@class EventTurnChangingDataSpec
---@field public from ServerPlayer
---@field public to ServerPlayer
---@field public skipRoundPlus boolean?

---@class EventTurnChangingData: EventTurnChangingDataSpec, TriggerData
EventTurnChangingData = TriggerData:subclass("EventTurnChangingData")

---@class fk.EventTurnChanging: TriggerEvent
---@field data EventTurnChangingData
fk.EventTurnChanging = TriggerEvent:subclass("fk.EventTurnChanging")

--- RoundData 轮次的数据
---@class RoundDataSpec -- TODO: 发挥想象力，填写这个Spec吧
---@field turn_table? integer[] @ 额定回合表，填空则为正常流程

--- 轮次的数据
---@class RoundData: RoundDataSpec, TriggerData
---@field turn_table integer[] @ 额定回合表
RoundData = TriggerData:subclass("RoundData")

---@class RoundEvent: TriggerEvent
---@field data RoundData
local RoundEvent = TriggerEvent:subclass("RoundEvent")

---@class fk.RoundStart: RoundEvent
fk.RoundStart = RoundEvent:subclass("fk.RoundStart")
---@class fk.RoundEnd: RoundEvent
fk.RoundEnd = RoundEvent:subclass("fk.RoundEnd")
---@class fk.AfterRoundEnd: RoundEvent
fk.AfterRoundEnd = RoundEvent:subclass("fk.AfterRoundEnd")
---@class fk.GameStart: RoundEvent
fk.GameStart = RoundEvent:subclass("fk.GameStart")

--- TurnData 回合的数据
---@class TurnDataSpec -- TODO: 发挥想象力，填写这个Spec吧
---@field who ServerPlayer @ 本回合的执行者
---@field reason string @ 当前额外回合的原因，不为额外回合则为game_rule
---@field phase_table? Phase[] @ 额定阶段表，填空则为正常流程

--- 回合的数据
---@class TurnData: TurnDataSpec, TriggerData
TurnData = TriggerData:subclass("TurnData")

---@class TurnEvent: TriggerEvent
---@field data TurnData
local TurnEvent = TriggerEvent:subclass("TurnEvent")

---@class fk.PreTurnStart: TurnEvent
fk.PreTurnStart = TurnEvent:subclass("fk.PreTurnStart")
---@class fk.BeforeTurnStart: TurnEvent
fk.BeforeTurnStart = TurnEvent:subclass("fk.BeforeTurnStart")
---@class fk.TurnStart: TurnEvent
fk.TurnStart = TurnEvent:subclass("fk.TurnStart")
---@class fk.TurnEnd: TurnEvent
fk.TurnEnd = TurnEvent:subclass("fk.TurnEnd")
---@class fk.AfterTurnEnd: TurnEvent
fk.AfterTurnEnd = TurnEvent:subclass("fk.AfterTurnEnd")

--- PhaseData 阶段的数据
---@class PhaseDataSpec -- TODO: 发挥想象力，填写这个Spec吧
---@field who ServerPlayer @ 本阶段的执行者
---@field reason string @ 当前额外阶段的原因，不为额外阶段则为game_rule
---@field phase Phase
---@field phase_end? boolean @ 该阶段是否即将结束

--- 阶段的数据
---@class PhaseData: PhaseDataSpec, TriggerData
PhaseData = TriggerData:subclass("PhaseData")

---@class PhaseEvent: TriggerEvent
---@field data PhaseData
local PhaseEvent = TriggerEvent:subclass("PhaseEvent")

---@class fk.EventPhaseStart: PhaseEvent
fk.EventPhaseStart = PhaseEvent:subclass("fk.EventPhaseStart")
---@class fk.EventPhaseProceeding: PhaseEvent
fk.EventPhaseProceeding = PhaseEvent:subclass("fk.EventPhaseProceeding")
---@class fk.EventPhaseEnd: PhaseEvent
fk.EventPhaseEnd = PhaseEvent:subclass("fk.EventPhaseEnd")
---@class fk.AfterPhaseEnd: PhaseEvent
fk.AfterPhaseEnd = PhaseEvent:subclass("fk.AfterPhaseEnd")
---@class fk.EventPhaseChanging: PhaseEvent
fk.EventPhaseChanging = PhaseEvent:subclass("fk.EventPhaseChanging")
---@class fk.EventPhaseSkipping: PhaseEvent
fk.EventPhaseSkipping = PhaseEvent:subclass("fk.EventPhaseSkipping")
---@class fk.EventPhaseSkipped: PhaseEvent
fk.EventPhaseSkipped = PhaseEvent:subclass("fk.EventPhaseSkipped")

---@class DrawNCardsData: PhaseData
---@field public n integer 摸牌数量
DrawNCardsData = PhaseData:subclass("DrawNCardsData")

---@class DrawNCardsEvent: TriggerEvent
---@field data DrawNCardsData
local DrawNCardsEvent = TriggerEvent:subclass("DrawNCardsEvent")

---@class fk.DrawNCards: DrawNCardsEvent
fk.DrawNCards = DrawNCardsEvent:subclass("fk.DrawNCards")
---@class fk.AfterDrawNCards: DrawNCardsEvent
fk.AfterDrawNCards = DrawNCardsEvent:subclass("fk.AfterDrawNCards")

---@class StartPlayCardData
---@field timeout integer

---@class fk.StartPlayCard: TriggerEvent
---@field data StartPlayCardData
fk.StartPlayCard = TriggerEvent:subclass("fk.StartPlayCard")

---@alias RoundFunc fun(self: TriggerSkill, event: RoundEvent,
---  target: ServerPlayer, player: ServerPlayer, data: RoundData): any
---@alias TurnFunc fun(self: TriggerSkill, event: TurnEvent,
---  target: ServerPlayer, player: ServerPlayer, data: TurnData): any
---@alias PhaseFunc fun(self: TriggerSkill, event: PhaseEvent,
---  target: ServerPlayer, player: ServerPlayer, data: PhaseData): any
---@alias DrawInitFunc fun(self: TriggerSkill, event: DrawInitialEvent,
---  target: ServerPlayer, player: ServerPlayer, data: DrawInitialData): any
---@alias EventTurnChangingFunc fun(self: TriggerSkill, event: fk.EventTurnChanging,
---  target: ServerPlayer, player: ServerPlayer, data: EventTurnChangingData): any
---@alias DrawNCardsFunc fun(self: TriggerSkill, event: DrawNCardsEvent,
---  target: ServerPlayer, player: ServerPlayer, data: DrawNCardsData): any
---@alias StartPlayCardFunc fun(self: TriggerSkill, event: fk.StartPlayCard,
---  target: ServerPlayer, player: ServerPlayer, data: StartPlayCardData): any

---@class SkillSkeleton
---@field public addEffect fun(self: SkillSkeleton, key: RoundEvent,
---  data: TrigSkelSpec<RoundFunc>, attr: TrigSkelAttribute?): SkillSkeleton
---@field public addEffect fun(self: SkillSkeleton, key: TurnEvent,
---  data: TrigSkelSpec<TurnFunc>, attr: TrigSkelAttribute?): SkillSkeleton
---@field public addEffect fun(self: SkillSkeleton, key: PhaseEvent,
---  data: TrigSkelSpec<PhaseFunc>, attr: TrigSkelAttribute?): SkillSkeleton
---@field public addEffect fun(self: SkillSkeleton, key: DrawInitialEvent,
---  data: TrigSkelSpec<DrawInitFunc>, attr: TrigSkelAttribute?): SkillSkeleton
---@field public addEffect fun(self: SkillSkeleton, key: fk.EventTurnChanging,
---  data: TrigSkelSpec<EventTurnChangingFunc>, attr: TrigSkelAttribute?): SkillSkeleton
---@field public addEffect fun(self: SkillSkeleton, key: DrawNCardsEvent,
---  data: TrigSkelSpec<DrawNCardsFunc>, attr: TrigSkelAttribute?): SkillSkeleton
---@field public addEffect fun(self: SkillSkeleton, key: fk.StartPlayCard,
---  data: TrigSkelSpec<StartPlayCardFunc>, attr: TrigSkelAttribute?): SkillSkeleton
