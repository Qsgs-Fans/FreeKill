
--- PropertyChangeData 武将牌属性变化的数据
---@class PropertyChangeDataSpec
---@field public from ServerPlayer @ 要变动的角色
---@field public general? string @ 要变更的主武将
---@field public deputyGeneral? string @ 要变更的副武将
---@field public gender? integer @ 要变更的性别
---@field public kingdom? string @ 要变更的势力
---@field public sendLog? boolean @ 是否发Log
---@field public results? table @ 这次改变的结果

--- 武将牌属性变化的数据
---@class PropertyChangeData: PropertyChangeDataSpec, TriggerData
PropertyChangeData = TriggerData:subclass("PropertyChangeData")

---@class PropertyChangeEvent: TriggerEvent
---@field data PropertyChangeData
local PropertyChangeEvent = TriggerEvent:subclass("PropertyChangeEvent")

---@class fk.BeforePropertyChange: PropertyChangeEvent
fk.BeforePropertyChange = PropertyChangeEvent:subclass("fk.BeforePropertyChange")
---@class fk.PropertyChange: PropertyChangeEvent
fk.PropertyChange = PropertyChangeEvent:subclass("fk.PropertyChange")
---@class fk.AfterPropertyChange: PropertyChangeEvent
fk.AfterPropertyChange = PropertyChangeEvent:subclass("fk.AfterPropertyChange")

---@class NilEvent: TriggerEvent
---@field data nil
local NilEvent = TriggerEvent:subclass("NilEvent")

---@class fk.BeforeTurnOver: NilEvent
fk.BeforeTurnOver = NilEvent:subclass("fk.BeforeTurnOver")
---@class fk.TurnedOver: NilEvent
fk.TurnedOver = NilEvent:subclass("fk.TurnedOver")
---@class fk.BeforeChainStateChange: NilEvent
fk.BeforeChainStateChange = NilEvent:subclass("fk.BeforeChainStateChange")
---@class fk.ChainStateChanged: NilEvent
fk.ChainStateChanged = NilEvent:subclass("fk.ChainStateChanged")
---@class fk.AfterDrawPileShuffle: NilEvent
fk.AfterDrawPileShuffle = NilEvent:subclass("fk.AfterDrawPileShuffle")

---@class BeforeTriggerSkillUseData
---@field skill TriggerSkill
---@field willUse boolean

---@class fk.BeforeTriggerSkillUse: TriggerEvent
---@field data BeforeTriggerSkillUseData
fk.BeforeTriggerSkillUse = TriggerEvent:subclass("fk.BeforeTriggerSkillUse")

---@class CardShownData
---@field cardIds integer[]

---@class fk.CardShown: TriggerEvent
---@field data CardShownData
fk.CardShown = TriggerEvent:subclass("fk.CardShown")

---@class AreaAbortResumeData
---@field slots string[] 被废除/恢复的区域名称

---@class AreaAbortResumeEvent: TriggerEvent
local AreaAbortResumeEvent = TriggerEvent:subclass("AreaAbortResumeEvent")

---@class fk.AreaAborted: AreaAbortResumeEvent
fk.AreaAborted = AreaAbortResumeEvent:subclass("fk.AreaAborted")
---@class fk.AreaResumed: AreaAbortResumeEvent
fk.AreaResumed = AreaAbortResumeEvent:subclass("fk.AreaResumed")

---@class ShowGeneralData
---@field m? string 主将？可能不是
---@field d? string 副将？也可能不是

---@class ShowGeneralEvent: TriggerEvent
---@field data ShowGeneralData
local ShowGeneralEvent = TriggerEvent:subclass("ShowGeneralEvent")

--- 武将牌明置时（注意不应该触发技能）
---@class fk.GeneralShown: ShowGeneralEvent
fk.GeneralShown = ShowGeneralEvent:subclass("fk.GeneralShown")
--- 武将牌明置后
---@class fk.GeneralRevealed: ShowGeneralEvent
fk.GeneralRevealed = ShowGeneralEvent:subclass("fk.GeneralRevealed")

---@class StringEvent: TriggerEvent
---@field data string
local StringEvent = TriggerEvent:subclass("StringEvent")

---@class fk.GeneralHidden: StringEvent
fk.GeneralHidden = StringEvent:subclass("fk.GeneralHidden")

---@class fk.GamePrepared: NilEvent
fk.GamePrepared = NilEvent:subclass("fk.GamePrepared")
---@class fk.GameFinished : StringEvent
fk.GameFinished = StringEvent:subclass("fk.GameFinished")

---@class AskForCardData
---@field user ServerPlayer
---@field skillName? string @ 烧条显示的技能名称
---@field pattern string
---@field extraData UseExtraData
---@field eventData? CardEffectData @ 询问此响应的事件，例如借刀之于问杀
---@field result? any
---@field isResponse? boolean @ 是否为打出事件
---@field afterRequest? boolean @ 是否已询问
---@field overtimes? ServerPlayer[] @ 此响应超时的玩家

---@class AskForCardEvent : TriggerEvent
---@field data AskForCardData
local AskForCardEvent = TriggerEvent:subclass("AskForCardEvent")

---@class fk.AskForCardUse : AskForCardEvent
fk.AskForCardUse = AskForCardEvent:subclass("fk.AskForCardUse")
---@class fk.AskForCardResponse : AskForCardEvent
fk.AskForCardResponse = AskForCardEvent:subclass("fk.AskForCardResponse")
---@class fk.HandleAskForPlayCard : AskForCardEvent
fk.HandleAskForPlayCard = AskForCardEvent:subclass("fk.HandleAskForPlayCard")
---@class fk.AfterAskForCardUse : AskForCardEvent
fk.AfterAskForCardUse = AskForCardEvent:subclass("fk.AfterAskForCardUse")
---@class fk.AfterAskForCardResponse : AskForCardEvent
fk.AfterAskForCardResponse = AskForCardEvent:subclass("fk.AfterAskForCardResponse")
---@class fk.AfterAskForNullification : AskForCardEvent
fk.AfterAskForNullification = AskForCardEvent:subclass("fk.AfterAskForNullification")

---@alias PropertyChangeFunc fun(self: TriggerSkill, event: PropertyChangeEvent,
---  target: ServerPlayer, player: ServerPlayer, data: PropertyChangeData): any
---@alias NilEventFunc fun(self: TriggerSkill, event: NilEvent,
---  target: ServerPlayer, player: ServerPlayer, data: nil): any
---@alias StringEventFunc fun(self: TriggerSkill, event: StringEvent,
---  target: ServerPlayer, player: ServerPlayer, data: string): any
---@alias BeforeTriggerSkillUseFunc fun(self: TriggerSkill, event: fk.BeforeTriggerSkillUse,
---  target: ServerPlayer, player: ServerPlayer, data: BeforeTriggerSkillUseData): any
---@alias CardShownFunc fun(self: TriggerSkill, event: fk.CardShown,
---  target: ServerPlayer, player: ServerPlayer, data: CardShownData): any
---@alias AreaAbortResumeFunc fun(self: TriggerSkill, event: AreaAbortResumeEvent,
---  target: ServerPlayer, player: ServerPlayer, data: AreaAbortResumeData): any
---@alias ShowGeneralFunc fun(self: TriggerSkill, event: ShowGeneralEvent,
---  target: ServerPlayer, player: ServerPlayer, data: ShowGeneralData): any
---@alias AskForCardFunc fun(self: TriggerSkill, event: AskForCardEvent,
---  target: ServerPlayer, player: ServerPlayer, data: AskForCardData): any

---@class SkillSkeleton
---@field public addEffect fun(self: SkillSkeleton, key: PropertyChangeEvent,
---  data: TrigSkelSpec<PropertyChangeFunc>, attr: TrigSkelAttribute?): SkillSkeleton
---@field public addEffect fun(self: SkillSkeleton, key: NilEvent,
---  data: TrigSkelSpec<NilEventFunc>, attr: TrigSkelAttribute?): SkillSkeleton
---@field public addEffect fun(self: SkillSkeleton, key: StringEvent,
---  data: TrigSkelSpec<StringEventFunc>, attr: TrigSkelAttribute?): SkillSkeleton
---@field public addEffect fun(self: SkillSkeleton, key: fk.BeforeTriggerSkillUse,
---  data: TrigSkelSpec<BeforeTriggerSkillUseFunc>, attr: TrigSkelAttribute?): SkillSkeleton
---@field public addEffect fun(self: SkillSkeleton, key: fk.CardShown,
---  data: TrigSkelSpec<CardShownFunc>, attr: TrigSkelAttribute?): SkillSkeleton
---@field public addEffect fun(self: SkillSkeleton, key: AreaAbortResumeEvent,
---  data: TrigSkelSpec<AreaAbortResumeFunc>, attr: TrigSkelAttribute?): SkillSkeleton
---@field public addEffect fun(self: SkillSkeleton, key: ShowGeneralEvent,
---  data: TrigSkelSpec<ShowGeneralFunc>, attr: TrigSkelAttribute?): SkillSkeleton
---@field public addEffect fun(self: SkillSkeleton, key: AskForCardEvent,
---  data: TrigSkelSpec<AskForCardFunc>, attr: TrigSkelAttribute?): SkillSkeleton
