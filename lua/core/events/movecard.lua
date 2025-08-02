

--- CardsMoveInfo 一组牌的移动信息
---@class CardsMoveInfo
---@field public ids integer[] @ 移动卡牌ID数组
---@field public from? ServerPlayer @ 移动来源玩家
---@field public to? ServerPlayer @ 移动终点玩家
---@field public toArea? CardArea @ 移动终点区域
---@field public moveReason? CardMoveReason @ 移动原因
---@field public proposer? ServerPlayer @ 移动执行者
---@field public skillName? string @ 移动技能名
---@field public moveVisible? boolean @ 控制移动是否可见
---@field public specialName? string @ 若终点区域为PlayerSpecial，则存至对应私人牌堆内
---@field public specialVisible? boolean @ 控制上述创建私人牌堆后是否令其可见
---@field public drawPilePosition? integer @ 移至牌堆的索引位置，值为-1代表置入牌堆底，或者牌堆牌数+1也为牌堆底
---@field public moveMark? table|string @ 移动后自动赋予标记，格式：{标记名(支持-inarea后缀，移出值代表区域后清除), 值}
---@field public visiblePlayers? ServerPlayer|ServerPlayer[] @ 控制移动对特定角色可见（在moveVisible为false时生效）

--- MoveInfo 一张牌的来源信息
---@class MoveInfo
---@field public cardId integer
---@field public fromArea CardArea
---@field public fromSpecialName? string

--- MoveCardsData 移动牌的数据
---@class MoveCardsDataSpec
---@field public moveInfo MoveInfo[] @ 移动信息
---@field public from? ServerPlayer @ 移动来源玩家
---@field public to? ServerPlayer @ 移动终点玩家
---@field public toArea CardArea @ 移动终点区域
---@field public moveReason CardMoveReason @ 移动原因
---@field public proposer? ServerPlayer @ 移动执行者
---@field public skillName? string @ 移动技能名
---@field public moveVisible? boolean @ 控制移动是否可见
---@field public specialName? string @ 若终点区域为PlayerSpecial，则存至对应私人牌堆内
---@field public specialVisible? boolean @ 控制上述创建私人牌堆后是否令其可见
---@field public drawPilePosition? integer @ 移至牌堆的索引位置，值为-1代表置入牌堆底，或者牌堆牌数+1也为牌堆底
---@field public moveMark? table|string @ 移动后自动赋予标记，格式：{标记名(支持-inarea后缀，移出值代表区域后清除), 值}
---@field public visiblePlayers? ServerPlayer | ServerPlayer[] @ 控制移动对特定角色可见（在moveVisible为false时生效）

--- 移动牌的数据（数组）
---@class MoveCardsData: MoveCardsDataSpec, TriggerData
MoveCardsData = TriggerData:subclass("MoveCardsData")

---@class MoveCardsEvent: TriggerEvent
---@field data MoveCardsData[]
local MoveCardsEvent = TriggerEvent:subclass("MoveCardsEvent")

function MoveCardsData:copy()
  local copy = {}
  for _, key in ipairs({
    "moveInfo", "from", "to", "toArea", "moveReason", "proposer", "skillName", "moveVisible",
    "specialName", "specialVisible", "drawPilePosition", "moveMark", "visiblePlayers"
  }) do
    copy[key] = self[key]
  end
  return copy
end

--- DrawData 关于摸牌的数据
---@class DrawDataSpec
---@field public who ServerPlayer @ 摸牌者
---@field public num integer @ 摸牌数
---@field public fromPlace? DrawPilePos @ 摸牌位置
---@field public skillName? string @ 技能名

---@alias DrawPilePos "top" | "bottom"

--- 关于摸牌的数据
---@class DrawData: DrawDataSpec, TriggerData
DrawData = TriggerData:subclass("DrawData")

---@class DrawEvent: TriggerEvent
---@field data DrawData
local DrawEvent = TriggerEvent:subclass("DrawEvent")

--- 牌移动前
---@class fk.BeforeCardsMove: MoveCardsEvent
fk.BeforeCardsMove = MoveCardsEvent:subclass("fk.BeforeCardsMove")
--- 牌移动后
---@class fk.AfterCardsMove: MoveCardsEvent
fk.AfterCardsMove = MoveCardsEvent:subclass("fk.AfterCardsMove")

--- 摸牌前
---@class fk.BeforeDrawCard: DrawEvent
fk.BeforeDrawCard = DrawEvent:subclass("fk.BeforeDrawCard")

---@alias MoveCardsFunc fun(self: TriggerSkill, event: MoveCardsEvent,
---  target: nil, player: ServerPlayer, data: MoveCardsData[]): any
---@alias DrawFunc fun(self: TriggerSkill, event: DrawEvent,
---  target: ServerPlayer, player: ServerPlayer, data: DrawData): any

---@class SkillSkeleton
---@field public addEffect fun(self: SkillSkeleton, key: MoveCardsEvent,
---  data: TrigSkelSpec<MoveCardsFunc>, attr: TrigSkelAttribute?): SkillSkeleton
---@field public addEffect fun(self: SkillSkeleton, key: DrawEvent,
---  data: TrigSkelSpec<DrawFunc>, attr: TrigSkelAttribute?): SkillSkeleton
