
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

---@class fk.AfterDrawPileShuffle: TriggerEvent
fk.AfterDrawPileShuffle = TriggerEvent:subclass("fk.AfterDrawPileShuffle")

---@class fk.BeforeTriggerSkillUse: TriggerEvent
fk.BeforeTriggerSkillUse = TriggerEvent:subclass("fk.BeforeTriggerSkillUse")

---@class fk.CardShown: TriggerEvent
fk.CardShown = TriggerEvent:subclass("fk.CardShown")

---@class fk.AreaAborted: TriggerEvent
fk.AreaAborted = TriggerEvent:subclass("fk.AreaAborted")
---@class fk.AreaResumed: TriggerEvent
fk.AreaResumed = TriggerEvent:subclass("fk.AreaResumed")

---@class fk.GeneralShown: TriggerEvent
fk.GeneralShown = TriggerEvent:subclass("fk.GeneralShown")
---@class fk.GeneralRevealed: TriggerEvent
fk.GeneralRevealed = TriggerEvent:subclass("fk.GeneralRevealed")
---@class fk.GeneralHidden: TriggerEvent
fk.GeneralHidden = TriggerEvent:subclass("fk.GeneralHidden")

---@class fk.GamePrepared: TriggerEvent
fk.GamePrepared = TriggerEvent:subclass("fk.GamePrepared")
---@class fk.GameFinished : TriggerEvent
fk.GameFinished = TriggerEvent:subclass("fk.GameFinished")
---@class fk.AskForCardUse : TriggerEvent
fk.AskForCardUse = TriggerEvent:subclass("fk.AskForCardUse")
---@class fk.AskForCardResponse : TriggerEvent
fk.AskForCardResponse = TriggerEvent:subclass("fk.AskForCardResponse")
---@class fk.HandleAskForPlayCard : TriggerEvent
fk.HandleAskForPlayCard = TriggerEvent:subclass("fk.HandleAskForPlayCard")
---@class fk.AfterAskForCardUse : TriggerEvent
fk.AfterAskForCardUse = TriggerEvent:subclass("fk.AfterAskForCardUse")
---@class fk.AfterAskForCardResponse : TriggerEvent
fk.AfterAskForCardResponse = TriggerEvent:subclass("fk.AfterAskForCardResponse")
---@class fk.AfterAskForNullification : TriggerEvent
fk.AfterAskForNullification = TriggerEvent:subclass("fk.AfterAskForNullification")

---@alias PropertyChangeFunc fun(self: TriggerSkill, event: PropertyChangeEvent,
---  target: ServerPlayer, player: ServerPlayer, data: PropertyChangeData): any
---@alias NilEventFunc fun(self: TriggerSkill, event: NilEvent,
---  target: ServerPlayer, player: ServerPlayer, data: nil): any

---@class SkillSkeleton
---@field public addEffect fun(self: SkillSkeleton, key: PropertyChangeEvent,
---  data: TrigSkelSpec<PropertyChangeFunc>, attr: TrigSkelAttribute?): SkillSkeleton
---@field public addEffect fun(self: SkillSkeleton, key: NilEvent,
---  data: TrigSkelSpec<NilEventFunc>, attr: TrigSkelAttribute?): SkillSkeleton
