
--- DrawInitialData 关于摸起始手牌的数据
---@class DrawInitialDataSpec
---@field public num integer @ 摸牌数
---@field public fix_ids integer[]? @ 起始手牌固定牌池，若数量不足则从牌堆补至num

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

--- RoundData 轮次的数据
---@class RoundDataSpec
---@field public from ServerPlayer @ 上个执行额定回合的角色
---@field public to ServerPlayer @ 即将执行额定回合的角色
---@field public turn_table? ServerPlayer[] @ 额定回合表，对于通常模式是所有玩家
---@field public skipped? boolean @ 是否跳过额定回合

--- 轮次的数据
---@class RoundData: RoundDataSpec, TriggerData
---@field turn_table ServerPlayer[] @ 额定回合表
RoundData = TriggerData:subclass("RoundData")

---@class RoundEvent: TriggerEvent
---@field data RoundData
local RoundEvent = TriggerEvent:subclass("RoundEvent")

--- 轮次开始时
---@class fk.RoundStart: RoundEvent
fk.RoundStart = RoundEvent:subclass("fk.RoundStart")
--- 轮次结束时
---@class fk.RoundEnd: RoundEvent
fk.RoundEnd = RoundEvent:subclass("fk.RoundEnd")
--- 游戏开始时（第一轮开始时之前）
---@class fk.GameStart: RoundEvent
fk.GameStart = RoundEvent:subclass("fk.GameStart")
--- 回合变化时
---@class fk.EventTurnChanging: RoundEvent
fk.EventTurnChanging = RoundEvent:subclass("fk.EventTurnChanging")

--- TurnData 回合的数据
---@class TurnDataSpec -- TODO: 发挥想象力，填写这个Spec吧
---@field who ServerPlayer @ 本回合的执行者
---@field reason string @ 当前额外回合的原因，不为额外回合则为game_rule
---@field phase_table PhaseData[] @ 回合进行的阶段列表（包含额定与额外阶段），填空则为正常流程
---@field phase_index integer @ 当前进行的阶段索引值
---@field turn_end? boolean @ 是否结束此回合

--- 回合的数据
---@class TurnData: TurnDataSpec, TriggerData
TurnData = TriggerData:subclass("TurnData")

--- 构造函数，不可随意调用。
---@param who ServerPlayer @ 本回合的执行者
---@param reason? string @ 当前额外回合的原因，不为额外回合则为game_rule
---@param phases? Phase[] @ 回合进行的额定阶段列表
function TurnData:initialize(who, reason, phases)
  TriggerData.initialize(self, {})
  self.who = who
  self.reason = reason or "game_rule"
  self.phase_table = table.map(
    phases or {
      Player.Start,
      Player.Judge,
      Player.Draw,
      Player.Play,
      Player.Discard,
      Player.Finish
    },
    function(phase)
      return
        PhaseData:new{
          who = who,
          reason = "game_rule",
          phase = phase
        }
    end
  )
  self.phase_index = 0
  self.turn_end = false
end

---@param phase Phase @ 阶段名称
---@param reason? string @ 额外阶段的原因，不为额外阶段则为game_rule
---@param who? ServerPlayer @ 额外阶段的执行者（默认为当前回合角色）
---@param extra_data? table @ 额外信息
function TurnData:gainAnExtraPhase(phase, reason, who, extra_data)
  table.insert(self.phase_table, self.phase_index + 1, PhaseData:new{
    who = who or self.who,
    reason = reason or "game_rule",
    phase = phase,
    extra_data = extra_data
  })
end

---@class TurnEvent: TriggerEvent
---@field data TurnData
local TurnEvent = TriggerEvent:subclass("TurnEvent")

---（规则集“回合开始后④”，已弃用）
---@class fk.PreTurnStart: TurnEvent
fk.PreTurnStart = TurnEvent:subclass("fk.PreTurnStart")
--- 回合开始前（规则集“回合开始后⑦”）
---@class fk.BeforeTurnStart: TurnEvent
fk.BeforeTurnStart = TurnEvent:subclass("fk.BeforeTurnStart")
--- 回合开始时（规则集“回合开始后⑨”）
---@class fk.TurnStart: TurnEvent
fk.TurnStart = TurnEvent:subclass("fk.TurnStart")
--- 回合结束时（规则集“回合结束前”）
---@class fk.TurnEnd: TurnEvent
fk.TurnEnd = TurnEvent:subclass("fk.TurnEnd")

--- PhaseData 阶段的数据
---@class PhaseDataSpec -- TODO: 发挥想象力，填写这个Spec吧
---@field who ServerPlayer @ 本阶段的执行者
---@field reason string @ 当前额外阶段的原因，不为额外阶段则为game_rule
---@field phase Phase
---@field phase_end? boolean @ 该阶段是否即将结束
---@field skipped? boolean @ 该阶段是否被跳过

--- 阶段的数据
---@class PhaseData: PhaseDataSpec, TriggerData
PhaseData = TriggerData:subclass("PhaseData")

---@class PhaseEvent: TriggerEvent
---@field data PhaseData
local PhaseEvent = TriggerEvent:subclass("PhaseEvent")

--- 阶段开始时
---@class fk.EventPhaseStart: PhaseEvent
fk.EventPhaseStart = PhaseEvent:subclass("fk.EventPhaseStart")
--- 阶段进行时
---@class fk.EventPhaseProceeding: PhaseEvent
fk.EventPhaseProceeding = PhaseEvent:subclass("fk.EventPhaseProceeding")
--- 阶段结束时
---@class fk.EventPhaseEnd: PhaseEvent
fk.EventPhaseEnd = PhaseEvent:subclass("fk.EventPhaseEnd")
--- 阶段变化时
---@class fk.EventPhaseChanging: PhaseEvent
fk.EventPhaseChanging = PhaseEvent:subclass("fk.EventPhaseChanging")
--- 阶段跳过时
---@class fk.EventPhaseSkipping: PhaseEvent
fk.EventPhaseSkipping = PhaseEvent:subclass("fk.EventPhaseSkipping")
--- 阶段跳过后
---@class fk.EventPhaseSkipped: PhaseEvent
fk.EventPhaseSkipped = PhaseEvent:subclass("fk.EventPhaseSkipped")
--- 进入出牌阶段空闲时点前
---@class fk.BeforePlayCard: PhaseEvent
fk.BeforePlayCard = PhaseEvent:subclass("fk.BeforePlayCard")

---@class DrawNCardsData: PhaseData
---@field public n integer 摸牌数量
DrawNCardsData = PhaseData:subclass("DrawNCardsData")

---@class DrawNCardsEvent: TriggerEvent
---@field data DrawNCardsData
local DrawNCardsEvent = TriggerEvent:subclass("DrawNCardsEvent")

--- 摸牌阶段摸牌前（描述为“摸牌阶段”）
---@class fk.DrawNCards: DrawNCardsEvent
fk.DrawNCards = DrawNCardsEvent:subclass("fk.DrawNCards")
--- 摸牌阶段摸牌后
---@class fk.AfterDrawNCards: DrawNCardsEvent
fk.AfterDrawNCards = DrawNCardsEvent:subclass("fk.AfterDrawNCards")

---@class StartPlayCardData
---@field timeout integer

--- 出牌阶段空闲时点开始
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
---@alias EventPhaseChangingFunc fun(self: TriggerSkill, event: fk.EventPhaseChanging,
---  target: ServerPlayer, player: ServerPlayer, data: PhaseData): any
---@alias EventTurnChangingFunc fun(self: TriggerSkill, event: fk.EventTurnChanging,
---  target: ServerPlayer, player: ServerPlayer, data: PhaseData): any
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
---@field public addEffect fun(self: SkillSkeleton, key: fk.EventPhaseChanging,
---  data: TrigSkelSpec<EventPhaseChangingFunc>, attr: TrigSkelAttribute?): SkillSkeleton
---@field public addEffect fun(self: SkillSkeleton, key: fk.EventTurnChanging,
---  data: TrigSkelSpec<EventTurnChangingFunc>, attr: TrigSkelAttribute?): SkillSkeleton
---@field public addEffect fun(self: SkillSkeleton, key: DrawNCardsEvent,
---  data: TrigSkelSpec<DrawNCardsFunc>, attr: TrigSkelAttribute?): SkillSkeleton
---@field public addEffect fun(self: SkillSkeleton, key: fk.StartPlayCard,
---  data: TrigSkelSpec<StartPlayCardFunc>, attr: TrigSkelAttribute?): SkillSkeleton
