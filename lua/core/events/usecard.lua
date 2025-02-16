
--- RespondCardData 打出牌的数据
---@class RespondCardDataSpec
---@field public from ServerPlayer @ 使用/打出者
---@field public card Card @ 卡牌本牌
---@field public responseToEvent? CardEffectData @ 响应事件目标
---@field public skipDrop? boolean @ 是否不进入弃牌堆
---@field public customFrom? ServerPlayer @ 新响应者

--- 打出牌的数据
---@class RespondCardData: RespondCardDataSpec, TriggerData
RespondCardData = TriggerData:subclass("RespondCardData")

---@class RespondCardEvent: TriggerEvent
---@field data RespondCardData
local RespondCardEvent = TriggerEvent:subclass("RespondCardEvent")

---@class fk.PreCardRespond: RespondCardEvent
fk.PreCardRespond = RespondCardEvent:subclass("fk.PreCardRespond")
---@class fk.CardResponding: RespondCardEvent
fk.CardResponding = RespondCardEvent:subclass("fk.CardResponding")
---@class fk.CardRespondFinished: RespondCardEvent
fk.CardRespondFinished = RespondCardEvent:subclass("fk.CardRespondFinished")

--- UseCardData 使用牌的数据
---@class UseCardDataSpec
---@field public from ServerPlayer @ 使用/打出者
---@field public card Card @ 卡牌本牌
---@field public tos ServerPlayer[] 目标列表
---@field public subTos? ServerPlayer[][] 子目标列表，借刀最爱的一集
---@field public toCard? Card @ 卡牌目标
---@field public toPutSlot? string @ 使用的装备牌所置入的装备栏
---@field public responseToEvent? CardEffectData @ 响应事件目标
---@field public nullifiedTargets? ServerPlayer[] @ 对这些角色无效
---@field public extraUse? boolean @ 是否不计入次数
---@field public disresponsiveList? ServerPlayer[] @ 这些角色不可响应此牌
---@field public unoffsetableList? ServerPlayer[] @ 这些角色不可抵消此牌
---@field public additionalDamage? integer @ 额外伤害值（如酒之于杀）
---@field public additionalRecover? integer @ 额外回复值
---@field public extra_data? any @ 额外数据（如目标过滤等）
---@field public cardsResponded? Card[] @ 响应此牌的牌
---@field public prohibitedCardNames? string[] @ 这些牌名的牌不可响应此牌
---@field public damageDealt? table<ServerPlayer, number> @ 此牌造成的伤害
---@field public additionalEffect? integer @ 额外结算次数
---@field public noIndicate? boolean @ 隐藏指示线

--- 使用牌的数据
---@class UseCardData: UseCardDataSpec, TriggerData
UseCardData = TriggerData:subclass("UseCardData")

---@param player ServerPlayer
function UseCardData:hasTarget(player)
  return table.contains(self.tos, player)
end

---@param player ServerPlayer
function UseCardData:removeTarget(player)
  self.subTos = self.subTos or {}
  for index, target in ipairs(self.tos) do
    if (target == player) then
      table.remove(self.tos, index)
      table.remove(self.subTos, index)
      return
    end
  end
end

function UseCardData:removeAllTargets()
  self.tos = {}
end

---@param player ServerPlayer
---@param sub? ServerPlayer[]
function UseCardData:addTarget(player, sub)
  table.insert(self.tos, player)
  self.subTos = self.subTos or {}
  table.insert(self.subTos, sub or {})
end

---@param player ServerPlayer
---@return ServerPlayer[]
function UseCardData:getSubTos(player)
  self.subTos = self.subTos or {}
  for i, p in ipairs(self.tos) do
    if p == player then
      self.subTos[i] = self.subTos[i] or {}
      return self.subTos[i]
    end
  end
  return {}
end

---@class UseCardEvent: TriggerEvent
---@field data UseCardData
local UseCardEvent = TriggerEvent:subclass("UseCardEvent")

---@class fk.PreCardUse: UseCardEvent
fk.PreCardUse = UseCardEvent:subclass("fk.PreCardUse")
---@class fk.AfterCardUseDeclared: UseCardEvent
fk.AfterCardUseDeclared = UseCardEvent:subclass("fk.AfterCardUseDeclared")
---@class fk.AfterCardTargetDeclared: UseCardEvent
fk.AfterCardTargetDeclared = UseCardEvent:subclass("fk.AfterCardTargetDeclared")
---@class fk.CardUsing: UseCardEvent
fk.CardUsing = UseCardEvent:subclass("fk.CardUsing")
---@class fk.BeforeCardUseEffect: UseCardEvent
fk.BeforeCardUseEffect = UseCardEvent:subclass("fk.BeforeCardUseEffect")
---@class fk.CardUseFinished: UseCardEvent
fk.CardUseFinished = UseCardEvent:subclass("fk.CardUseFinished")

--- AimStruct 处理使用牌目标的数据
---@class AimDataSpec
---@field public from ServerPlayer @ 使用者
---@field public card Card @ 卡牌本牌
---@field public tos AimGroup @ 总角色目标
---@field public to ServerPlayer @ 当前角色目标
---@field public subTargets? ServerPlayer[] @ 子目标（借刀！）
---@field public useTos? ServerPlayer[] @ 目标组
---@field public useSubTos? ServerPlayer[][] @ 目标组
---@field public nullifiedTargets? ServerPlayer[] @ 对这些角色无效
---@field public firstTarget boolean @ 是否是第一个目标
---@field public additionalDamage? integer @ 额外伤害值（如酒之于杀）
---@field public additionalRecover? integer @ 额外回复值
---@field public disresponsive? boolean @ 是否不可响应
---@field public unoffsetable? boolean @ 是否不可抵消
---@field public fixedResponseTimes? table<string, integer>|integer @ 额外响应请求
---@field public fixedAddTimesResponsors? integer[] @ 额外响应请求次数
---@field public additionalEffect? integer @额外结算次数
---@field public extraData? UseExtraData | any @ 额外数据

--- 使用牌的数据
---@class AimData: AimDataSpec, TriggerData
AimData = TriggerData:subclass("AimData")

AimData.Undone = 1
AimData.Done = 2
AimData.Cancelled = 3

---@class AimGroup
---@field public [1] ServerPlayer[] 未完成的目标
---@field public [2] ServerPlayer[] 已完成的目标
---@field public [3] ServerPlayer[] 取消的目标

---@param players ServerPlayer[]
---@return AimGroup
function AimData.static:initAimGroup(players)
  return { [AimGroup.Undone] = players, [AimGroup.Done] = {}, [AimGroup.Cancelled] = {} }
end

---@param players ServerPlayer[]
---@return AimGroup
function AimData:initAimGroup(players)
  error("Please use AimData:initAimGroup.")
end

---@return ServerPlayer[]
function AimData:getAllTargets()
  local targets = {}
  table.insertTable(targets, self.tos[AimData.Undone])
  table.insertTable(targets, self.tos[AimData.Done])
  return targets
end

function AimData:getUndoneTargets()
  return self.tos[AimData.Undone]
end

function AimData:getDoneTargets()
  return self.tos[AimData.Done]
end

function AimData:getCancelledTargets()
  return self.tos[AimData.Cancelled]
end

---@param player ServerPlayer
function AimData:setTargetDone(player)
  local aimGroup = self.tos
  local index = table.indexOf(aimGroup[AimData.Undone], player)
  if index ~= -1 then
    table.remove(aimGroup[AimData.Undone], index)
    table.insert(aimGroup[AimData.Done], player)
  end
end

---@param player ServerPlayer
---@param sub? ServerPlayer[]
function AimData:addTarget(player, sub)
  table.insert(self.tos[AimData.Undone], player)

  if sub then
    self.subTargets = self.subTargets or {}
    table.insertTable(self.subTargets, sub)
  end

  RoomInstance:sortByAction(self.tos[AimData.Undone])
  if self.useTos then
    table.insert(self.useTos, player)
    table.insert(self.useSubTos, sub or {})
  end
end

---@param player ServerPlayer
function AimData:cancelTarget(player)
  local cancelled = false
  for status = AimData.Undone, AimData.Done do
    local indexList = {}
    for index, p in ipairs(self.tos[status]) do
      if p == player then
        table.insert(indexList, index)
      end
    end

    if #indexList > 0 then
      cancelled = true
      for i = 1, #indexList do
        table.remove(self.tos[status], indexList[i])
      end
    end
  end

  if cancelled then
    table.insert(self.tos[AimData.Cancelled], player)
    if self.useTos then
      for i, p in ipairs(self.useTos) do
        if p == player then
          table.remove(self.useTos, i)
          table.remove(self.useSubTos, i)
          break
        end
      end
    end
  end
end

function AimData:removeDeadTargets()
  for index = AimData.Undone, AimData.Done do
    self.tos[index] = RoomInstance:deadPlayerFilter(self.tos[index])
  end

  if self.useTos then
    for i, target in ipairs(self.useTos) do
      if not target:isAlive() then
        table.remove(self.useTos, i)
        table.remove(self.useSubTos, i)
      end
    end
  end
end

---@param target ServerPlayer
---@return boolean
function AimData:isOnlyTarget(target)
  if self.tos == nil then return false end
  local tos = self:getAllTargets()
  return table.contains(tos, target) and not table.find(target.room.alive_players, function (p)
    return p ~= target and table.contains(tos, p)
  end)
end

---@class AimEvent: TriggerEvent
---@field data AimData
local AimEvent = TriggerEvent:subclass("AimData")

---@class fk.TargetSpecifying: AimEvent
fk.TargetSpecifying = AimEvent:subclass("fk.TargetSpecifying")
---@class fk.TargetConfirming: AimEvent
fk.TargetConfirming = AimEvent:subclass("fk.TargetConfirming")
---@class fk.TargetSpecified: AimEvent
fk.TargetSpecified = AimEvent:subclass("fk.TargetSpecified")
---@class fk.TargetConfirmed: AimEvent
fk.TargetConfirmed = AimEvent:subclass("fk.TargetConfirmed")

--- CardEffectData 卡牌效果的数据
---@class CardEffectDataSpec: RespondCardDataSpec
---@field public to ServerPlayer @ 角色目标
---@field public subTargets? ServerPlayer[] @ 子目标（借刀！）
---@field public tos ServerPlayer[] 目标列表
---@field public subTos? ServerPlayer[][] 子目标列表，借刀最爱的一集
---@field public toCard? Card @ 卡牌目标
---@field public responseToEvent? CardEffectData @ 响应事件目标
---@field public nullifiedTargets? ServerPlayer[] @ 对这些角色无效
---@field public extraUse? boolean @ 是否不计入次数
---@field public disresponsiveList? ServerPlayer[] @ 这些角色不可响应此牌
---@field public unoffsetableList? ServerPlayer[] @ 这些角色不可抵消此牌
---@field public additionalDamage? integer @ 额外伤害值（如酒之于杀）
---@field public additionalRecover? integer @ 额外回复值
---@field public extra_data? any @ 额外数据（如目标过滤等）
---@field public cardsResponded? Card[] @ 响应此牌的牌
---@field public disresponsive? boolean @ 是否不可响应
---@field public unoffsetable? boolean @ 是否不可抵消
---@field public isCancellOut? boolean @ 是否被抵消
---@field public fixedResponseTimes? table<string, integer>|integer @ 额外响应请求
---@field public fixedAddTimesResponsors? integer[] @ 额外响应请求次数
---@field public prohibitedCardNames? string[] @ 这些牌名的牌不可响应此牌

--- 卡牌效果的数据
---@class CardEffectData: CardEffectDataSpec, TriggerData
CardEffectData = TriggerData:subclass("CardEffectData")

---@param player ServerPlayer
---@return ServerPlayer[]
function CardEffectData:getSubTos(player)
  self.subTos = self.subTos or {}
  for i, p in ipairs(self.tos) do
    if p == player then
      self.subTos[i] = self.subTos[i] or {}
      return self.subTos[i]
    end
  end
  return {}
end

---@class CardEffectEvent: TriggerEvent
---@field data CardEffectData
local CardEffectEvent = TriggerEvent:subclass("CardEffectEvent")

---@class fk.PreCardEffect: CardEffectEvent
fk.PreCardEffect = CardEffectEvent:subclass("fk.PreCardEffect")
---@class fk.BeforeCardEffect: CardEffectEvent
fk.BeforeCardEffect = CardEffectEvent:subclass("fk.BeforeCardEffect")
---@class fk.CardEffecting: CardEffectEvent
fk.CardEffecting = CardEffectEvent:subclass("fk.CardEffecting")
---@class fk.CardEffectFinished: CardEffectEvent
fk.CardEffectFinished = CardEffectEvent:subclass("fk.CardEffectFinished")
---@class fk.CardEffectCancelledOut: CardEffectEvent
fk.CardEffectCancelledOut = CardEffectEvent:subclass("fk.CardEffectCancelledOut")

---@alias RespondCardFunc fun(self: TriggerSkill, event: RespondCardEvent,
---  target: ServerPlayer, player: ServerPlayer, data: RespondCardData): any
---@alias UseCardFunc fun(self: TriggerSkill, event: UseCardEvent,
---  target: ServerPlayer, player: ServerPlayer, data: UseCardData): any
---@alias AimFunc fun(self: TriggerSkill, event: AimEvent,
---  target: ServerPlayer, player: ServerPlayer, data: AimData): any
---@alias CardEffectFunc fun(self: TriggerSkill, event: CardEffectEvent,
---  target: ServerPlayer, player: ServerPlayer, data: CardEffectData): any

---@class SkillSkeleton
---@field public addEffect fun(self: SkillSkeleton, key: RespondCardEvent,
---  data: TrigSkelSpec<RespondCardFunc>, attr: TrigSkelAttribute?): SkillSkeleton
---@field public addEffect fun(self: SkillSkeleton, key: UseCardEvent,
---  data: TrigSkelSpec<UseCardFunc>, attr: TrigSkelAttribute?): SkillSkeleton
---@field public addEffect fun(self: SkillSkeleton, key: AimEvent,
---  data: TrigSkelSpec<AimFunc>, attr: TrigSkelAttribute?): SkillSkeleton
---@field public addEffect fun(self: SkillSkeleton, key: CardEffectEvent,
---  data: TrigSkelSpec<CardEffectFunc>, attr: TrigSkelAttribute?): SkillSkeleton
