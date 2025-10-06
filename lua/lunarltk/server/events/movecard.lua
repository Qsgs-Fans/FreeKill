-- SPDX-License-Identifier: GPL-3.0-or-later

---@class MoveEventWrappers: Object
local MoveEventWrappers = {} -- mixin

---@return boolean
local function exec(tp, ...)
  local event = tp:create(...)
  local _, ret = event:exec()
  return ret
end

---@param info MoveCardsData | CardsMoveInfo
local function infoCheck(info)
  assert(table.contains({ Card.PlayerHand, Card.PlayerEquip, Card.PlayerJudge, Card.PlayerSpecial, Card.Processing, Card.DrawPile, Card.DiscardPile, Card.Void }, info.toArea))
  assert(info.toArea ~= Card.PlayerSpecial or type(info.specialName) == "string")
  assert(type(info.moveReason) == "number")
end

---@class GameEvent.MoveCards : GameEvent
---@field public data MoveCardsData[]
local MoveCards = GameEvent:subclass("GameEvent.MoveCards")

function MoveCards:__tostring()
  local data = self.data
  local ret = "<MoveCards "
  for _, move in ipairs(data) do
    local r = string.format(" of %s => %s of %s", move.from, move.toArea, move.to)
    local cards = {} ---@type table<CardArea, integer[]>
    for _, info in ipairs(move.moveInfo) do
      cards[info.fromArea] = cards[info.fromArea] or {}
      table.insert(cards[info.fromArea], info.cardId)
    end
    for area, cs in pairs(cards) do
      ret = ret .. string.format("[%s]: %s",
        table.concat(table.map(cs, function(id)
          return Fk:getCardById(id):__tostring()
        end), ", "), area) .. r
    end
  end
  ret = ret .. string.format(" #%d>", self.id)
  return ret
end

function MoveCards:main()
  local room = self.room
  local moveCardsData = self.data

  room.logic:trigger(fk.BeforeCardsMove, nil, moveCardsData)

  local new_data = {}
  for _, data in ipairs(moveCardsData) do
    local new_move = {}
    if #data.moveInfo > 0 and data.toArea ~= Card.Void then
      local orig_info, new_info, destruct_ids = {}, {}, {}
      for i = 1, #data.moveInfo do
        local info = data.moveInfo[i]
        local will_destruct = false
        local card = Fk:getCardById(info.cardId)
        if card:getMark(MarkEnum.DestructIntoDiscard) ~= 0 and data.toArea == Card.DiscardPile then
          will_destruct = true
        end
        if card:getMark(MarkEnum.DestructOutMyEquip) ~= 0 and info.fromArea == Card.PlayerEquip then
          will_destruct = info.fromArea == Card.PlayerEquip
        end
        if card:getMark(MarkEnum.DestructOutEquip) ~= 0 and
          ((info.fromArea == Card.PlayerEquip or info.fromArea == Card.Processing) and
          data.toArea ~= Card.PlayerEquip and data.toArea ~= Card.Processing) then
          will_destruct = true
        end
        if will_destruct then
          room:setCardMark(card, MarkEnum.DestructIntoDiscard, 0)
          room:setCardMark(card, MarkEnum.DestructOutMyEquip, 0)
          room:setCardMark(card, MarkEnum.DestructOutEquip, 0)
          table.insert(destruct_ids, info.cardId)
          table.insert(new_info, info)
        else
          table.insert(orig_info, info)
        end
      end
      data.moveInfo = orig_info
      if #new_info > 0 then
        new_move = {
          moveInfo = new_info,
          from = data.from,
          to = nil,
          toArea = Card.Void,
          moveReason = fk.ReasonJustMove,
          proposer = nil,
          skillName = nil,
          moveVisible = true,
        }
      end
      if #destruct_ids > 0 then
        room:sendLog{
          type = "#DestructCards",
          card = destruct_ids,
        }
      end
    end
    if next(new_move) then
      table.insert(new_data, new_move)
    end
  end
  if next(new_data) then
    table.insertTable(moveCardsData, new_data)
  end

  for i = #moveCardsData, 1, -1 do
    local data = moveCardsData[i]
    if #data.moveInfo == 0 then
      table.remove(moveCardsData, i)
    end
  end
  if #moveCardsData == 0 then
    room.logic:breakEvent()
  end

  local uninstalls, installs = {}, {}

  for _, data in ipairs(moveCardsData) do
    if #data.moveInfo > 0 then
      infoCheck(data)

      for _, info in ipairs(data.moveInfo) do
        local realFromArea = room:getCardArea(info.cardId)
        room:applyMoveInfo(data, info)

        if data.from and data.from:getVirtualEquip(info.cardId) then
          data.from:removeVirtualEquip(info.cardId)
        end
        if realFromArea == Player.Equip and data.from and info.beforeCard.type == Card.TypeEquip then
          table.insert(uninstalls, {info.beforeCard, data.from})
        end

        Fk:filterCard(info.cardId, data.to)

        local currentCard = Fk:getCardById(info.cardId) --[[@as EquipCard]]
        for name, value in pairs(currentCard.mark) do
          if name:find("-inhand", 1, true) and
          realFromArea == Player.Hand and
          data.from
          then
            room:setCardMark(currentCard, name, 0)
          end
          if name:find("-inarea", 1, true) and
          type(value) == "table" and table.contains(value, realFromArea) and not table.contains(value, data.toArea)
          then
            room:setCardMark(currentCard, name, 0)
          end
        end
        if data.moveMark then
          local mark = data.moveMark
          if type(mark) == "string" then
            room:setCardMark(currentCard, mark, 1)
          elseif type(mark) == "table" then
            mark = table.clone(mark)
            room:setCardMark(currentCard, mark[1], mark[2])
          end
        end

        -- FIXME: 随便擦了几下 等设计师亲手鉴定
        local realCurrentCard = Fk:getCardById(info.cardId, true)
        if currentCard.type == Card.TypeEquip and realCurrentCard.type ~= Card.TypeEquip and not info.virtualEquip then
          info.virtualEquip = Fk:cloneCard(currentCard.name)
          info.virtualEquip:addSubcard(currentCard.id)
        end

        if info.virtualEquip and info.virtualEquip:getEffectiveId() == info.cardId and
          (data.toArea == Card.PlayerEquip or data.toArea == Card.PlayerJudge) then
          currentCard = info.virtualEquip
          ---@cast currentCard -nil
          data.to:addVirtualEquip(currentCard)
        end
        if data.toArea == Player.Equip and currentCard.type == Card.TypeEquip and data.to and data.to:isAlive() then
          table.insert(installs, {currentCard, data.to})
        end
      end
    end

  end

  room:notifyMoveCards(nil, moveCardsData, self.id)

  for _, v in ipairs(uninstalls) do
    local card, from = table.unpack(v)
    ---@cast card EquipCard
    card:onUninstall(room, from)
  end
  for _, v in ipairs(installs) do
    local card, to = table.unpack(v)
    card:onInstall(room, to)
  end

  room.logic:trigger(fk.AfterCardsMove, nil, moveCardsData)
  return true
end

function MoveCards:clear()
  local e = self.parent
  while e do
    if table.contains({GameEvent.SkillEffect, GameEvent.UseCard, GameEvent.RespondCard}, e.event) then
      return
    end
    e = e.parent
  end
  self.room:destroyTableCardByEvent(self.id)
end

local function convertOldMoveInfo(info)
  local room = Fk:currentRoom()
  if type(info.from) == "number" then
    info.from = room:getPlayerById(info.from)
  end
  if type(info.to) == "number" then
    info.to = room:getPlayerById(info.to)
  end
  if type(info.proposer) == "number" then
    info.proposer = room:getPlayerById(info.proposer)
  end
  if info.visiblePlayers then
    if type(info.visiblePlayers) == "table" and #info.visiblePlayers > 0 and type(info.visiblePlayers[1]) == "number" then
      info.visiblePlayers = table.map(info.visiblePlayers, Util.Id2PlayerMapper)
    elseif type(info.visiblePlayers) == "number" then
      info.visiblePlayers = room:getPlayerById(info.visiblePlayers)
    end
  end
end

--- 将填入room:moveCards的参数（类型CardsMoveInfo），根据情况转为正确的移动数据（类型MoveCardsData）（并防止非法移动）
---@param room Room
---@param ... CardsMoveInfo
---@return MoveCardsData[]
local function moveInfoTranslate(room, ...)
  -- 获取移动前此牌在原区域内的卡牌信息
  local markBeforeCard = function (id)
    local card = Fk:getCardById(id)
    local owner = room:getCardOwner(id)
    if owner then
      card = owner:getVirtualEquip(id) or card
    end
    local c = Fk:cloneCard(card.name, card.suit, card.number)
    local markTable = card:isVirtual() and card.mark or room.card_marks[card.id]
    if markTable then
      for k, v in pairs(markTable) do
        c.mark[k] = v
      end
    end
    return c
  end

  ---@type MoveCardsData[]
  local ret = {}
  for _, cardsMoveInfo in ipairs{ ... } do
    convertOldMoveInfo(cardsMoveInfo)
    if #cardsMoveInfo.ids == 0 then goto continue1 end
    infoCheck(cardsMoveInfo)

    local infos = {} ---@type MoveInfo[] -- 正常移动数据
    local abortMoveInfos = {} ---@type MoveInfo[] -- 因废除被修改的移动数据

    for _, id in ipairs(cardsMoveInfo.ids) do
      -- 从来源判断，为虚拟装备信息赋值
      local info = { ---@type MoveInfo
        beforeCard = markBeforeCard(id),
        cardId = id,
        fromArea = room:getCardArea(id),
        fromSpecialName = cardsMoveInfo.from and cardsMoveInfo.from:getPileNameOfId(id),
      }
      local vequip -- 移动到目标区域时，将转化为的虚拟装备

      if cardsMoveInfo.virtualEquip then
        vequip = cardsMoveInfo.virtualEquip
      -- 虚拟装备/延时锦囊在装备区/判定区内移动时，保留虚拟数据
      elseif (cardsMoveInfo.toArea == Card.PlayerJudge or cardsMoveInfo.toArea == Card.PlayerEquip)
        and cardsMoveInfo.toArea == room:getCardArea(id)
        and cardsMoveInfo.to
        and cardsMoveInfo.from and cardsMoveInfo.from:getVirtualEquip(id) then
        vequip = cardsMoveInfo.from:getVirtualEquip(id)
      -- 受锁视影响视为装备牌的情况，加上牌的锁视信息
      elseif Fk:getCardById(id, true).name ~= info.beforeCard.name then
        local c = info.beforeCard
        vequip = Fk:cloneCard(c.name, c.suit, c.number)
        vequip:addSubcard(id)
      end
      info.virtualEquip = vequip

      -- 若移动到被废除的装备栏，则修改为置入弃牌堆
      local toAbortDrop = false
      if cardsMoveInfo.toArea == Card.PlayerEquip and cardsMoveInfo.to then
        local moveToPlayer = cardsMoveInfo.to
        ---@cast moveToPlayer -nil 防止判空波浪线
        local card = cardsMoveInfo.virtualEquip or Fk:getCardById(id)
        if card.type == Card.TypeEquip and #moveToPlayer:getAvailableEquipSlots(card.sub_type) == 0 then
          table.insert(abortMoveInfos, info)
          toAbortDrop = true
        end
      end

      if toAbortDrop then
        goto continue2
      end

      table.insert(infos, info)

      ::continue2::
    end

    -- 为普通移动设置正确数据
    if #infos > 0 then
      table.insert(ret, MoveCardsData:new {
        moveInfo = infos,
        from = cardsMoveInfo.from,
        to = cardsMoveInfo.to,
        toArea = cardsMoveInfo.toArea,
        moveReason = cardsMoveInfo.moveReason,
        proposer = cardsMoveInfo.proposer,
        skillName = cardsMoveInfo.skillName,
        moveVisible = cardsMoveInfo.moveVisible,
        specialName = cardsMoveInfo.specialName,
        specialVisible = cardsMoveInfo.specialVisible,
        drawPilePosition = cardsMoveInfo.drawPilePosition,
        moveMark = cardsMoveInfo.moveMark,
        visiblePlayers = cardsMoveInfo.visiblePlayers,
        extra_data = cardsMoveInfo.extra_data,
      })
    end

    -- 为因为移动到废除区域而改为丢掉的设置正确数据
    if #abortMoveInfos > 0 then
      table.insert(ret, MoveCardsData:new {
        moveInfo = abortMoveInfos,
        from = cardsMoveInfo.from,
        toArea = Card.DiscardPile,
        moveReason = fk.ReasonPutIntoDiscardPile,
        moveVisible = true,
      })
    end

    ::continue1::
  end
  return ret
end

--- 传入一系列移牌信息，去实际移动这些牌
---@param ... CardsMoveInfo
---@return boolean?
function MoveEventWrappers:moveCards(...)
  ---@cast self Room
  local datas = moveInfoTranslate(self, ...)
  if #datas == 0 then
    return false
  end
  return exec(MoveCards, datas)
end

--- 向多名玩家告知一次移牌行为。
---@param players? ServerPlayer[] @ 要被告知的玩家列表，默认为全员
---@param moveDatas MoveCardsData[] @ 要告知的移牌信息列表
---@param event_id? integer @ 当前事件id
function MoveEventWrappers:notifyMoveCards(players, moveDatas, event_id)
  ---@cast self Room
  if players == nil or #players == 0 then players = self.players end
  for _, p in ipairs(players) do
    local arg = {}
    for _, move in ipairs(moveDatas) do

      -- 在转成json传输之前先变一下
      local _data = rawget(move, "_data")
      local v = table.simpleClone(_data and _data or move)
      v.from = v.from and v.from.id
      v.to = v.to and v.to.id
      v.proposer = v.proposer and v.proposer.id
      if v.visiblePlayers then
        v.visiblePlayers = table.map(v.visiblePlayers, Util.IdMapper)
      end
      table.insert(arg, v)
    end
    p:doNotify("MoveCards", {arg, event_id or 0})
  end
end

--- 让一名玩家获得一张牌
---@param player ServerPlayer @ 要拿牌的玩家
---@param card integer|integer[]|Card|Card[] @ 要拿到的卡牌
---@param visible? boolean @ 是否明着拿
---@param reason? CardMoveReason @ 卡牌移动的原因
---@param proposer? ServerPlayer @ 移动操作者
---@param skill_name? string @ 技能名
---@param moveMark? table|string @ 移动后自动赋予标记，格式：{标记名(支持-inarea后缀，移出值代表区域后清除), 值}
---@param visiblePlayers? ServerPlayer|ServerPlayer[] @ 控制移动对特定角色可见（在moveVisible为false时生效）
function MoveEventWrappers:obtainCard(player, card, visible, reason, proposer, skill_name, moveMark, visiblePlayers)
  self:moveCardTo(card, Card.PlayerHand, player, reason, skill_name, nil, visible, proposer or player, moveMark, visiblePlayers)
end

--- 让玩家摸牌
---@param player ServerPlayer @ 摸牌的玩家
---@param num integer @ 摸牌数
---@param skillName? string @ 技能名
---@param fromPlace? DrawPilePos @ 摸牌的位置，默认牌堆顶
---@param moveMark? table|string @ 移动后自动赋予标记，格式：{标记名(支持-inarea后缀，移出值代表区域后清除), 值}
---@return integer[] @ 摸到的牌
function MoveEventWrappers:drawCards(player, num, skillName, fromPlace, moveMark)
  ---@cast self Room
  if num < 1 then
    return {}
  end

  local drawData = DrawData:new{
    who = player,
    num = num,
    skillName = skillName,
    fromPlace = fromPlace or "top",
  }
  if self.logic:trigger(fk.BeforeDrawCard, player, drawData) then
    return {}
  end

  num = drawData.num
  fromPlace = drawData.fromPlace
  player = drawData.who

  local topCards = self:getNCards(num, fromPlace)
  self:moveCards({
    ids = topCards,
    to = player,
    toArea = Card.PlayerHand,
    moveReason = fk.ReasonDraw,
    proposer = player,
    skillName = skillName,
    moveMark = moveMark,
  })

  return { table.unpack(topCards) }
end

--- 将一张或多张牌移动到某处
---@param card integer | integer[] | Card | Card[] @ 要移动的牌
---@param to_place integer @ 移动的目标位置
---@param target? ServerPlayer @ 移动的目标角色
---@param reason? integer @ 移动时使用的移牌原因
---@param skill_name? string @ 技能名
---@param special_name? string @ 私人牌堆名
---@param visible? boolean @ 是否明置
---@param proposer? ServerPlayer @ 移动操作者
---@param moveMark? table|string @ 移动后自动赋予标记，格式：{标记名(支持-inarea后缀，移出值代表区域后清除), 值}
---@param visiblePlayers? ServerPlayer|ServerPlayer[] @ 控制移动对特定角色可见（在moveVisible为false时生效）
function MoveEventWrappers:moveCardTo(card, to_place, target, reason, skill_name, special_name, visible, proposer, moveMark, visiblePlayers)
  ---@cast self Room
  reason = reason or fk.ReasonJustMove
  skill_name = skill_name or ""
  special_name = special_name or ""
  local ids = Card:getIdList(card)

  local to
  if table.contains(
    {Card.PlayerEquip, Card.PlayerHand,
      Card.PlayerJudge, Card.PlayerSpecial}, to_place) then
    assert(target)
    if type(target) == "number" then
      to = self:getPlayerById(target)
    else
      to = target
    end
  end

  local movesSplitedByOwner = {}
  for _, cardId in ipairs(ids) do
    local moveFound = table.find(movesSplitedByOwner, function(move)
      return move.from == self:getCardOwner(cardId)
    end)

    if moveFound then
      table.insert(moveFound.ids, cardId)
    else
      table.insert(movesSplitedByOwner, {
        ids = { cardId },
        from = self:getCardOwner(cardId),
        to = to,
        toArea = to_place,
        moveReason = reason,
        skillName = skill_name,
        specialName = special_name,
        moveVisible = visible,
        proposer = proposer,
        moveMark = moveMark,
        visiblePlayers = visiblePlayers,
      })
    end
  end

  self:moveCards(table.unpack(movesSplitedByOwner))
end

--- 弃置一名角色的牌。
---@param card_ids integer[]|integer|Card|Card[] @ 被弃掉的牌
---@param skillName? string @ 技能名
---@param who ServerPlayer @ 被弃牌的人
---@param thrower? ServerPlayer @ 弃别人牌的人
function MoveEventWrappers:throwCard(card_ids, skillName, who, thrower)
  skillName = skillName or ""
  thrower = thrower or who
  assert(table.every(Card:getIdList(card_ids), function(id)
    return self:getCardOwner(id) == who
  end), "Attempt to throw card from false owner!")
  self:moveCards({
    ids = Card:getIdList(card_ids),
    from = who,
    toArea = Card.DiscardPile,
    moveReason = fk.ReasonDiscard,
    proposer = thrower,
    skillName = skillName
  })
end

--- 重铸一名角色的牌。
---@param card_ids integer[] @ 被重铸的牌
---@param who ServerPlayer @ 重铸的角色
---@param skillName? string @ 技能名，默认为“重铸”
---@param moveMark? table|string @ 移动后自动赋予标记，格式：{标记名(支持-inarea后缀，移出值代表区域后清除), 值}
---@return integer[] @ 摸到的牌
function MoveEventWrappers:recastCard(card_ids, who, skillName, moveMark)
  ---@cast self Room
  if type(card_ids) == "number" then
    card_ids = {card_ids}
  end
  skillName = skillName or "recast"
  self:moveCards({
    ids = card_ids,
    from = who,
    toArea = Card.DiscardPile,
    skillName = skillName,
    moveReason = fk.ReasonRecast,
    proposer = who,
  })
  self:sendFootnote(card_ids, {
    type = "##RecastCard",
    from = who.id,
  })
  self:broadcastPlaySound("./audio/system/recast")
  self:sendLog{
    type = skillName == "recast" and "#Recast" or "#RecastBySkill",
    from = who.id,
    card = card_ids,
    arg = skillName,
  }
  if who.dead then return {} end
  return self:drawCards(who, #card_ids, skillName, "top", moveMark)
end

--- 将一些卡牌同时分配给一些角色。
---@param list table<integer, integer[]> @ 分配牌和角色的数据表，键为角色id，值为分配给其的牌id数组
---@param proposer? ServerPlayer @ 操作者的。默认为空
---@param skillName? string @ 技能名。默认为“分配”
---@param moveMark? table|string @ 移动后自动赋予标记，格式：{标记名(支持-inarea后缀，移出值代表区域后清除), 值}
---@return integer[] @ 返回成功分配的卡牌
function MoveEventWrappers:doYiji(list, proposer, skillName, moveMark)
  ---@cast self Room
  skillName = skillName or "distribution_skill"
  local moveInfos = {}
  local move_ids = {}
  for to, cards in pairs(list) do
    local toP = self:getPlayerById(to)
    local handcards = toP:getCardIds("h")
    cards = table.filter(cards, function (id) return not table.contains(handcards, id) end)
    if #cards > 0 then
      table.insertTable(move_ids, cards)
      local moveMap = {}
      local noFrom = {}
      for _, id in ipairs(cards) do
        local from = self.owner_map[id]
        if from then
          moveMap[from] = moveMap[from] or {}
          table.insert(moveMap[from], id)
        else
          table.insert(noFrom, id)
        end
      end
      for from, _cards in pairs(moveMap) do
        table.insert(moveInfos, {
          ids = _cards,
          moveInfo = table.map(_cards, function(id)
            return {cardId = id, fromArea = self:getCardArea(id), fromSpecialName = self:getPlayerById(from):getPileNameOfId(id)}
          end),
          from = from,
          to = to,
          toArea = Card.PlayerHand,
          moveReason = fk.ReasonGive,
          proposer = proposer,
          skillName = skillName,
          moveMark = moveMark,
        })
      end
      if #noFrom > 0 then
        table.insert(moveInfos, {
          ids = noFrom,
          to = to,
          toArea = Card.PlayerHand,
          moveReason = fk.ReasonGive,
          proposer = proposer,
          skillName = skillName,
          moveMark = moveMark,
        })
      end
    end
  end
  if #moveInfos > 0 then
    self:moveCards(table.unpack(moveInfos))
  end
  return move_ids
end

--- 将一张牌移动至某角色的装备区，若不合法则置入弃牌堆。
---@param target ServerPlayer @ 接受牌的角色
---@param cards integer|integer[]|Card|Card[] @ 移动的牌，这些牌同副类别不可相同
---@param skillName? string @ 技能名
---@param convert? boolean @ 是否可以替换装备（默认可以）
---@param proposer? ServerPlayer @ 操作者
---@return integer[] @ 成功置入装备区的牌
function MoveEventWrappers:moveCardIntoEquip(target, cards, skillName, convert, proposer)
  ---@cast self Room
  convert = (convert == nil) and true or convert
  skillName = skillName or ""
  cards = (type(cards) == "table" and cards[1] ~= nil) and cards or {cards}
  cards = table.map(cards, function (id)
    return type(id) == "number" and Fk:getCardById(id) or id
  end)
  ---@cast cards Card[]
  proposer = type(proposer) == "number" and self:getPlayerById(proposer) or proposer
  local moves = {}
  local ret = {}
  for _, card in ipairs(cards) do
    local cardId = card:getEffectiveId()
    local from = self:getCardOwner(card)
    if target:canMoveCardIntoEquip(card, convert) then
      if not target:hasEmptyEquipSlot(card.sub_type) then
        local existingEquip = target:getEquipments(card.sub_type)
        -- 选择被替换的装备
        local throw = #existingEquip == 1 and existingEquip[1] or
        self:askToChooseCard(proposer or target, {
          target = target,
          flag = { card_data = { { Util.convertSubtypeAndEquipSlot(card.sub_type), existingEquip } } },
          skill_name = "replaceEquip",
          prompt = "#replaceEquip",
        })
        table.insert(moves, {
          ids = { throw },
          from = target,
          toArea = Card.DiscardPile,
          moveReason = fk.ReasonPutIntoDiscardPile,
          skillName = skillName,
          proposer = proposer,
        })
      end
      table.insert(moves, {
        ids = { cardId },
        from = from,
        to = target,
        toArea = Card.PlayerEquip,
        moveReason = fk.ReasonPut,
        skillName = skillName,
        proposer = proposer,
        virtualEquip = card:isVirtual() and card or nil,
      })
      table.insert(ret, cardId)
    else
      table.insert(moves, {
        ids = { cardId },
        from = from,
        toArea = Card.DiscardPile,
        moveReason = fk.ReasonPutIntoDiscardPile,
        skillName = skillName,
        proposer = proposer,
      })
    end
  end
  self:moveCards(table.unpack(moves))
  return ret
end

--- 从牌堆亮出一些牌移动到处理区
---@param player ServerPlayer @ 进行操作的角色
---@param card_ids integer[] @ 要亮出的牌，通常用getNCards获得
---@param skillName string @ 技能名
---@param moveVisible? boolean @ 是否正面向上移动
---@param visiblePlayers? ServerPlayer[] @ 控制移动对特定角色可见（默认对自己可见，若想完全不可见则设为空表）
function MoveEventWrappers:turnOverCardsFromDrawPile(player, card_ids, skillName, moveVisible, visiblePlayers )
  ---@cast self Room
  self:moveCards {
    ids = card_ids,
    toArea = Card.Processing,
    moveReason = fk.ReasonJustMove,
    skillName = skillName,
    proposer = player,
    moveVisible = (moveVisible == nil or moveVisible == true),
    visiblePlayers = visiblePlayers or (moveVisible == false and { player } or nil),
  }
end

--将处理区的卡牌返回牌堆
---@param player ServerPlayer @ 进行操作的角色
---@param cards integer[] @ 返回牌堆的卡牌
---@param skillName string @ 技能名
---@param toPlace? DrawPilePos @ 返回牌堆的位置，默认牌堆顶
---@param moveVisible? boolean @ 是否正面向上移动
---@param visiblePlayers? ServerPlayer[] @ 控制移动对特定角色可见（默认对自己可见，若想完全不可见则设为空表）
function MoveEventWrappers:returnCardsToDrawPile(player, cards, skillName, toPlace, moveVisible, visiblePlayers)
  ---@cast self Room
  local to_drawpile = table.filter(cards, function (id)
    return self:getCardArea(id) == Card.Processing
  end)
  if #to_drawpile == 0 then return end
  if toPlace == nil then
    toPlace = "top"
  end
  if toPlace == "top" then
    to_drawpile = table.reverse(to_drawpile)
  end
  self:moveCards {
    ids = to_drawpile,
    toArea = Card.DrawPile,
    moveReason = fk.ReasonJustMove,
    skillName = skillName,
    proposer = player,
    moveVisible = (moveVisible == nil or moveVisible == true),
    visiblePlayers = visiblePlayers or (moveVisible == false and { player } or nil),
    drawPilePosition = toPlace == "top" and 1 or -1
  }
end

-- 令两名角色交换特定的牌（FIXME：暂时只能正面朝上移动过）
---@param player ServerPlayer @ 进行操作的角色
---@param card_data any @ {{角色1, 角色1的卡牌}, {角色2, 角色2的卡牌}}
---@param skillName string @ 技能名
---@param toArea integer? @ 交换牌的目标区域，默认为手牌
function MoveEventWrappers:swapCards(player, card_data, skillName, toArea)
  ---@cast self Room
  toArea = toArea or Card.PlayerHand
  local target1, cards1, target2, cards2 = card_data[1][1], card_data[1][2], card_data[2][1], card_data[2][2]
  local virtualData = {} -- 移动前的虚拟装备/延时锦囊数据
  local moveInfos = {}
  if #cards1 > 0 then
    for _, id in ipairs(cards1) do
      virtualData[id] = target1:getVirtualEquip(id)
    end
    table.insert(moveInfos, {
      from = target1,
      ids = cards1,
      toArea = Card.Processing,
      moveReason = fk.ReasonExchange,
      proposer = player,
      skillName = skillName,
      moveVisible = (toArea ~= Card.PlayerHand),  --交换蓄谋牌是否可见，待定
    })
  end
  if #cards2 > 0 then
    for _, id in ipairs(cards2) do
      virtualData[id] = target2:getVirtualEquip(id)
    end
    table.insert(moveInfos, {
      from = target2,
      ids = cards2,
      toArea = Card.Processing,
      moveReason = fk.ReasonExchange,
      proposer = player,
      skillName = skillName,
      moveVisible = (toArea ~= Card.PlayerHand),
    })
  end
  if #moveInfos > 0 then
    self:moveCards(table.unpack(moveInfos))
  end
  moveInfos = {}

  --- 筛选能够进入目标区域的牌
  --- 目前逻辑：不替换，多张同副类别牌进入区域时，自动保留最前的
  ---@param ids integer[]
  ---@param to ServerPlayer @ 目标角色
  ---@return integer[]
  local function canMoveIn(ids, to)
    local slotMap = {} -- 记录本次移动中，每种副类型的装备牌已移入了几张
    return table.filter(ids, function (id)
      if self:getCardArea(id) ~= Card.Processing then return false end
      local card = virtualData[id] or Fk:getCardById(id)
      if toArea == Card.PlayerEquip then
        if #to:getAvailableEquipSlots(card.sub_type) > (slotMap[card.sub_type] or 0) then
          slotMap[card.sub_type] = (slotMap[card.sub_type] or 0) + 1
          return true
        end
      elseif toArea == Card.PlayerJudge then
        if not to:isProhibitedTarget(card) then
          if card.stackable_delayed then return true end
          if slotMap[card.name] == nil then
            slotMap[card.name] = 1
            return true
          end
        end
      else
        return true
      end
      return false
    end)
  end

  ---@param ids integer[]
  ---@param to ServerPlayer @ 目标角色
  local function moveCardsIn(ids, to)
    if to.dead then return end
    local to_ex_cards = canMoveIn(ids, to)
    local realCards = {}
    for _, id in ipairs(to_ex_cards) do
      if virtualData[id] then
        table.insert(moveInfos, {
          ids = {id},
          fromArea = Card.Processing,
          to = to,
          toArea = toArea,
          moveReason = fk.ReasonExchange,
          proposer = player,
          skillName = skillName,
          moveVisible = (toArea ~= Card.PlayerHand),
          visiblePlayers = to,
          virtualEquip = virtualData[id],
        })
      else
        table.insert(realCards, id)
      end
    end
    if #realCards > 0 then
      table.insert(moveInfos, {
        ids = realCards,
        fromArea = Card.Processing,
        to = to,
        toArea = toArea,
        moveReason = fk.ReasonExchange,
        proposer = player,
        skillName = skillName,
        moveVisible = (toArea ~= Card.PlayerHand),
        visiblePlayers = to,
      })
    end
  end

  moveCardsIn(cards1, target2)
  moveCardsIn(cards2, target1)

  if #moveInfos > 0 then
    self:moveCards(table.unpack(moveInfos))
  end

  self:cleanProcessingArea(table.connect(cards1, cards2), skillName)
end

-- 令两名角色交换一个区域内所有牌
---@param player ServerPlayer @ 进行操作的角色
---@param targets ServerPlayer[] @ 交换手牌的两名角色
---@param skillName string @ 技能名
---@param flag? "h" | "e" | "j" @ 交换的区域。默认是手牌
function MoveEventWrappers:swapAllCards(player, targets, skillName, flag)
  ---@cast self Room
  flag = flag or "h"
  local toArea = Card.PlayerHand
  if flag == "e" then
    toArea = Card.PlayerEquip
  elseif flag == "j" then
    toArea = Card.PlayerJudge
  end
  self:swapCards(player, {
    {targets[1], targets[1]:getCardIds(flag)},
    {targets[2], targets[2]:getCardIds(flag)}
  }, skillName, toArea)
end

-- 将一名角色的卡牌与牌堆中的卡牌交换
---@param player ServerPlayer @ 移动的目标
---@param cards1 integer[] @ 将要放到牌堆的牌
---@param cards2 integer[] @ 将要收为手牌的牌
---@param skillName string @ 技能名
---@param pile_name string @ 交换的私有牌堆名，特别的，为"Top"则为牌堆顶，"Bottom"则为牌堆底，"discardPile"则为弃牌堆
---@param visible? boolean @ 是否明牌移动
---@param proposer? ServerPlayer @ 移动的操作者（默认同player）
function MoveEventWrappers:swapCardsWithPile(player, cards1, cards2, skillName, pile_name, visible, proposer)
  ---@cast self Room
  proposer = proposer or player
  visible = (visible ~= nil) and visible or false
  local handcards = player:getCardIds("he")
  if pile_name == "Top" or pile_name == "Bottom" then
    cards2 = table.filter(cards2, function (id)
      return not table.contains(handcards, id)
    end)
    local temp = table.simpleClone(cards1)
    table.insertTable(temp, cards2)
    self:moveCardTo(temp, Card.Processing, nil, fk.ReasonExchange, skillName, nil, visible, player, nil, proposer)
    cards1 = table.filter(cards1, function (id)
      return self:getCardArea(id) == Card.Processing
    end)
    local moveInfos = {}
    if #cards1 > 0 then
      local drawPilePosition = -1
      if pile_name == "Top" then
        cards1 = table.reverse(cards1)
        drawPilePosition = 1
      end
      table.insert(moveInfos, {
        ids = cards1,
        toArea = Card.DrawPile,
        moveReason = fk.ReasonExchange,
        proposer = proposer,
        skillName = skillName,
        moveVisible = visible,
        visiblePlayers = proposer,
        drawPilePosition = drawPilePosition,
      })
    end
    if player.dead then
      table.insert(moveInfos, {
        ids = cards2,
        toArea = Card.DiscardPile,
        moveReason = fk.ReasonPutIntoDiscardPile,
      })
    else
      table.insert(moveInfos, {
        ids = cards2,
        to = player,
        toArea = Card.PlayerHand,
        moveReason = fk.ReasonExchange,
        proposer = proposer,
        skillName = skillName,
        moveVisible = visible,
        visiblePlayers = proposer,
      })
    end
    if #moveInfos > 0 then
      self:moveCards(table.unpack(moveInfos))
    end
  elseif pile_name == "discardPile" then
    cards1 = table.filter(cards1, function (id)
      return table.contains(handcards, id)
    end)
    cards2 = table.filter(cards2, function (id)
      return not table.contains(handcards, id)
    end)
    local temp = table.simpleClone(cards1)
    table.insertTable(temp, cards2)
    self:moveCardTo(temp, Card.Processing, nil, fk.ReasonExchange, skillName, nil, visible, player, nil, proposer)
    cards2 = table.filter(cards2, function (id)
      return self:getCardArea(id) == Card.Processing
    end)
    local moveInfos = {}
    temp = table.simpleClone(cards1)

    if #cards2 > 0 then
      if player.dead then
        table.insertTable(temp, cards2)
      else
        table.insert(moveInfos, {
          ids = cards2,
          to = player,
          toArea = Card.PlayerHand,
          moveReason = fk.ReasonExchange,
          proposer = proposer,
          skillName = skillName,
          moveVisible = visible,
          visiblePlayers = proposer,
        })
      end
    end
    if #temp > 0 then
      table.insert(moveInfos, {
        ids = temp,
        toArea = Card.DiscardPile,
        moveReason = fk.ReasonPutIntoDiscardPile,
      })
    end
    if #moveInfos > 0 then
      self:moveCards(table.unpack(moveInfos))
    end
  else
    cards1 = table.filter(cards1, function (id)
      return table.contains(handcards, id)
    end)
    if #cards1 > 0 then
      player:addToPile(pile_name, cards1, visible, skillName)
      if player.dead then return end
    end
    cards2 = table.filter(player:getPile(pile_name), function (id)
      return table.contains(cards2, id)
    end)
    if #cards2 > 0 then
      self:moveCardTo(cards2, Card.PlayerHand, player, fk.ReasonExchange, skillName, nil, visible, proposer, nil, player)
    end
  end
end

--- 取消一些牌的移动。请仅用于BeforeCardsMove时机
---@param data MoveCardsData[]
---@param ids? integer[] @ 取消移动的牌的id列表，填nil则取消所有
---@param func? fun(move: MoveCardsData, info: MoveInfo): boolean @ 筛选取消移动的函数，与ids取并集，填nil则取消所有
---@return integer[] @ 成功取消移动的牌id列表
function MoveEventWrappers:cancelMove(data, ids, func)
  local ret = {}
  for _, move in ipairs(data) do
    local infos = {}
    for _, info in ipairs(move.moveInfo) do
      if (ids == nil or table.contains(ids, info.cardId)) and (func == nil or func(move, info)) then
        table.insert(ret, info.cardId)
      else
        table.insert(infos, info)
      end
    end
    move.moveInfo = infos
  end
  return ret
end

return { MoveCards, MoveEventWrappers }
