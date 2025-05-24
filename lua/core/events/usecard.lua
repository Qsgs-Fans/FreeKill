
--- RespondCardData 打出牌的数据
---@class RespondCardDataSpec
---@field public from ServerPlayer @ 使用/打出者
---@field public card Card @ 卡牌本牌
---@field public responseToEvent? CardEffectData @ 响应事件目标
---@field public skipDrop? boolean @ 是否不进入弃牌堆
---@field public customFrom? ServerPlayer @ 新响应者
---@field public attachedSkillAndUser? { user: integer, skillName: string, muteCard: boolean } @ 附加技能、使用者与卡牌静音，用于转化技

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
---@field public tos ServerPlayer[] @ 目标列表
---@field public subTos? ServerPlayer[][] @ 子目标列表，借刀最爱的一集
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
---@field public attachedSkillAndUser? { user: integer, skillName: string, muteCard: boolean } @ 附加技能、使用者与卡牌静音，用于转化技

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
  self.tos = {} ---@type ServerPlayer[] @ 目标列表
end

---@return ServerPlayer[]
function UseCardData:getAllTargets()
  return table.simpleClone(self.tos)
end

-- 获取使用牌的合法额外目标（为简化结算，不允许与已有目标重复、且【借刀杀人】等带副目标的卡牌使用首个目标的副目标）
---@param extra_data? table
---@return ServerPlayer[]
function UseCardData:getExtraTargets(extra_data)
  if self.card.type == Card.TypeEquip or self.card.sub_type == Card.SubtypeDelayedTrick then return {} end
  local tos = {}
  local sub_tos = self:getSubTos(self.tos[1])
  for _, p in ipairs(RoomInstance.alive_players) do
    if not (table.contains(self.tos, p) or self.from:isProhibited(p, self.card)) and
    self.card.skill:modTargetFilter(self.from, p, {}, self.card, extra_data) then
      if #sub_tos > 0 then
        local mod_tos = {p}
        if table.every(sub_tos, function (sub_to)
          if self.card.skill:modTargetFilter(self.from, sub_to, mod_tos, self.card, extra_data) then
            table.insert(mod_tos, sub_to)
            return true
          end
        end) then
          table.insert(tos, p)
        end
      else
        table.insert(tos, p)
      end
    end
  end
  return tos
end

-- 将角色添加至目标列表（若不指定副目标则继承首个目标的副目标）
---@param player ServerPlayer
---@param sub? ServerPlayer[]
function UseCardData:addTarget(player, sub)
  table.insert(self.tos, player)
  self.subTos = self.subTos or {}
  table.insert(self.subTos, sub or (#self.tos > 0 and self:getSubTos(self.tos[1]) or {}))
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


-- 改变使用的卡牌
---@param name? string
---@param suit? Suit
---@param number? integer
---@param skill_name? string
function UseCardData:changeCard(name, suit, number, skill_name)
  if self.card.name == name and self.card.suit == suit and self.card.number == number then
    return
  end
  name = name or self.card.name
  suit = suit or self.card.suit
  number = number or self.card.number
  local card = Fk:cloneCard(name, suit, number)
  for k, v in pairs(self.card) do
    if card[k] == nil then
      card[k] = v
    end
  end
  if self.card:isVirtual() then
    card.subcards = self.card.subcards
  else
    card.id = self.card.id
  end
  card.skillNames = self.card.skillNames
  if skill_name then
    table.insertIfNeed(card.skillNames, skill_name)
  end
  if RoomInstance then
    RoomInstance:sendCardVirtName(Card:getIdList(card), name)
  end
  self.card = card
end

--- 判断使用事件是否是在使用手牌
---@param player ServerPlayer @ 要判断的使用者
---@return boolean
function UseCardData:isUsingHandcard(player)
  local useEvent = player.room.logic:getCurrentEvent()
  local cards = Card:getIdList(self.card)
  if #cards == 0 then return false end
  local moveEvents = useEvent:searchEvents(GameEvent.MoveCards, 1, function(e)
    return e.parent and e.parent.id == useEvent.id
  end)
  if #moveEvents == 0 then return false end
  local subcheck = table.simpleClone(cards)
  for _, move in ipairs(moveEvents[1].data) do
    if move.moveReason == fk.ReasonUse then
      for _, info in ipairs(move.moveInfo) do
        if table.removeOne(subcheck, info.cardId) and info.fromArea ~= Card.PlayerHand then
          return false
        end
      end
    end
  end
  return #subcheck == 0
end

--- 判断打出事件是否是在打出手牌
---@param player ServerPlayer @ 要判断的使用者
---@return boolean
function RespondCardData:isUsingHandcard(player)
  local useEvent = player.room.logic:getCurrentEvent()
  local cards = Card:getIdList(self.card)
  if #cards == 0 then return false end
  local moveEvents = useEvent:searchEvents(GameEvent.MoveCards, 1, function(e)
    return e.parent and e.parent.id == useEvent.id
  end)
  if #moveEvents == 0 then return false end
  local subcheck = table.simpleClone(cards)
  for _, move in ipairs(moveEvents[1].data) do
    if move.moveReason == fk.ReasonResponse then
      for _, info in ipairs(move.moveInfo) do
        if table.removeOne(subcheck, info.cardId) and info.fromArea ~= Card.PlayerHand then
          return false
        end
      end
    end
  end
  return #subcheck == 0
end

--- 判断一名角色是否是该使用事件的唯一目标
--- 其实这个应该是AimData的，但普通的使用牌有时也得用
---@param target ServerPlayer
---@return boolean
function UseCardData:isOnlyTarget(target)
  if self.tos == nil then return false end
  local tos = self:getAllTargets()
  return table.contains(tos, target) and not table.find(target.room.alive_players, function (p)
    return p ~= target and table.contains(tos, p)
  end)
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
---@field public use UseCardData @ 使用流程信息
---@field public subTargets? ServerPlayer[] @ 子目标（借刀！）
---@field public firstTarget boolean @ 是否是第一个目标
---@field public additionalDamage? integer @ 额外伤害值（如酒之于杀）
---@field public additionalRecover? integer @ 额外回复值
---@field public disresponsive? boolean @ 是否不可响应
---@field public unoffsetable? boolean @ 是否不可抵消
---@field public nullified? boolean @ 是否对此目标无效
---@field public fixedResponseTimes? integer @ 响应此事件需要的牌张数（如杀之于决斗），默认1张
---@field public fixedAddTimesResponsors? ServerPlayer[] @ 需要应用额外响应的角色们，用于单向多次响应（无双决斗），为nil则应用所有角色
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
  return { [AimData.Undone] = table.simpleClone(players), [AimData.Done] = {}, [AimData.Cancelled] = {} }
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

-- 获取使用牌的合法额外目标（为简化结算，不允许与已有目标重复、且【借刀杀人】等带副目标的卡牌使用当前目标的副目标）
---@param extra_data? table
---@return ServerPlayer[]
function AimData:getExtraTargets(extra_data)
  if self.card.type == Card.TypeEquip or self.card.sub_type == Card.SubtypeDelayedTrick then return {} end
  local tos = {}
  local sub_tos = self.subTargets
  for _, p in ipairs(RoomInstance.alive_players) do
    if not (table.contains(self.use.tos, p) or self.from:isProhibited(p, self.card)) and
    self.card.skill:modTargetFilter(self.from, p, {}, self.card, extra_data) then
      if sub_tos and #sub_tos > 0 then
        local mod_tos = {p}
        if table.every(sub_tos, function (sub_to)
          if self.card.skill:modTargetFilter(self.from, sub_to, mod_tos, self.card, extra_data) then
            table.insert(mod_tos, sub_to)
            return true
          end
        end) then
          table.insert(tos, p)
        end
      else
        table.insert(tos, p)
      end
    end
  end
  return tos
end

-- 改变使用的卡牌
---@param name? string
---@param suit? Suit
---@param number? integer
---@param skill_name? string
function AimData:changeCard(name, suit, number, skill_name)
  if self.card.name == name and self.card.suit == suit and self.card.number == number then
    return
  end
  name = name or self.card.name
  suit = suit or self.card.suit
  number = number or self.card.number
  local card = Fk:cloneCard(name, suit, number)
  for k, v in pairs(self.card) do
    if card[k] == nil then
      card[k] = v
    end
  end
  if self.card:isVirtual() then
    card.subcards = self.card.subcards
  else
    card.id = self.card.id
  end
  card.skillNames = self.card.skillNames
  if skill_name then
    table.insertIfNeed(card.skillNames, skill_name)
  end
  if RoomInstance then
    RoomInstance:sendCardVirtName(Card:getIdList(card), name)
  end
  self.card = card
end

-- 将角色添加至目标列表（若不指定副目标则继承当前目标的副目标）
---@param player ServerPlayer
---@param sub? ServerPlayer[]
function AimData:addTarget(player, sub)
  table.insert(self.tos[AimData.Undone], player)

  RoomInstance:sortByAction(self.tos[AimData.Undone])
  table.insert(self.use.tos, player)
  table.insert(self.use.subTos, sub or self.subTargets)

  RoomInstance:sendLog{
    type = "#TargetAdded",
    from = self.from.id,
    to = {player.id},
    arg = self.card:toLogString(),
  }
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
    for i, p in ipairs(self.use.tos) do
      if p == player then
        table.remove(self.use.tos, i)
        table.remove(self.use.subTos, i)
        break
      end
    end
  end

  RoomInstance:sendLog{
    type = "#TargetCancelled",
    from = self.from.id,
    to = {player.id},
    arg = self.card:toLogString(),
  }
end

function AimData:removeDeadTargets()
  for index = AimData.Undone, AimData.Done do
    self.tos[index] = RoomInstance:deadPlayerFilter(self.tos[index])
  end

  for i, target in ipairs(self.use.tos) do
    if not target:isAlive() then
      table.remove(self.use.tos, i)
      table.remove(self.use.subTos, i)
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

---@param target? ServerPlayer
---@return boolean
function AimData:isDisresponsive(target)
  target = target or self.to
  return self.disresponsive or (target and table.contains((self.use.disresponsiveList or Util.DummyTable), target))
end

---@param target? ServerPlayer
---@return boolean
function AimData:isUnoffsetable(target)
  target = target or self.to
  return self.unoffsetable or (target and table.contains((self.use.unoffsetableList or Util.DummyTable), target))
end

---@return boolean
function AimData:isNullified()
  return self.nullified or (self.to and table.contains((self.use.nullifiedTargets or Util.DummyTable), self.to))
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
---@field public use? UseCardData @ 使用流程信息（注意：延迟锦囊在处理时的use不存在！）
---@field public responseToEvent? CardEffectData @ 响应事件目标
---@field public additionalDamage? integer @ 额外伤害值（如酒之于杀）
---@field public additionalRecover? integer @ 额外回复值
---@field public extra_data? any @ 额外数据（如目标过滤等）
---@field public cardsResponded? Card[] @ 响应此牌的牌
---@field public disresponsive? boolean @ 是否不可响应
---@field public unoffsetable? boolean @ 是否不可抵消
---@field public nullified? boolean @ 是否对此目标无效
---@field public isCancellOut? boolean @ 是否被抵消
---@field public fixedResponseTimes? integer @ 响应此事件需要的牌张数（如杀之于决斗），默认1张
---@field public fixedAddTimesResponsors? ServerPlayer[] @ 需要应用额外响应的角色们，用于单向多次响应（无双），为nil则应用所有角色
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

---@return ServerPlayer[]
function CardEffectData:getAllTargets()
  return table.simpleClone(self.tos)
end

---@param target ServerPlayer
---@return boolean
function CardEffectData:isOnlyTarget(target)
  if self.tos == nil then return false end
  local tos = self:getAllTargets()
  return table.contains(tos, target) and not table.find(target.room.alive_players, function (p)
    return p ~= target and table.contains(tos, p)
  end)
end

--- 当前生效目标是否不可抵消此牌
---@param target? ServerPlayer
---@return boolean
function CardEffectData:isDisresponsive(target)
  target = target or self.to
  return self.disresponsive or (target and self.use ~= nil and table.contains((self.use.disresponsiveList or Util.DummyTable), target))
end

--- 当前生效目标是否不可响应此牌
---@param target? ServerPlayer
---@return boolean
function CardEffectData:isUnoffsetable(target)
  target = target or self.to
  return self.unoffsetable or (target and self.use ~= nil and table.contains((self.use.unoffsetableList or Util.DummyTable), target))
end

--- 判断此牌是否对当前目标无效
---@return boolean
function CardEffectData:isNullified()
  return self.nullified or (self.to and self.use ~= nil and table.contains((self.use.nullifiedTargets or Util.DummyTable), self.to))
end

--- 响应当前牌需要的牌张数，默认1
---@param target? ServerPlayer @ 需要响应的角色，默认为生效目标
---@return integer
function CardEffectData:getResponseTimes(target)
  if self.fixedResponseTimes then
    if self.fixedAddTimesResponsors == nil or table.contains(self.fixedAddTimesResponsors, target or self.to) then
      return self.fixedResponseTimes
    end
  end
  return 1
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
