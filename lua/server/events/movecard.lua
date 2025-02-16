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
function MoveCards:main()
  local room = self.room
  local moveCardsData = self.data

  if room.logic:trigger(fk.BeforeCardsMove, nil, moveCardsData) then
    room.logic:breakEvent(false)
  end

  room:notifyMoveCards(nil, moveCardsData)

  for _, data in ipairs(moveCardsData) do
    if #data.moveInfo > 0 then
      infoCheck(data)

      for _, info in ipairs(data.moveInfo) do
        local realFromArea = room:getCardArea(info.cardId)
        room:applyMoveInfo(data, info)
        if data.toArea == Card.DrawPile or realFromArea == Card.DrawPile then
          room:doBroadcastNotify("UpdateDrawPile", #room.draw_pile)
        end

        local beforeCard = Fk:getCardById(info.cardId)
        if
          realFromArea == Player.Equip and
          beforeCard.type == Card.TypeEquip and
          data.from ~= nil and
          #beforeCard:getEquipSkills(data.from) > 0
        then
          beforeCard:onUninstall(room, data.from)
        end

        Fk:filterCard(info.cardId, data.to)

        local currentCard = Fk:getCardById(info.cardId)
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
        if
          data.toArea == Player.Equip and
          currentCard.type == Card.TypeEquip and
          data.to ~= nil and
          data.to:isAlive() and
          #currentCard:getEquipSkills(data.to) > 0
        then
          currentCard:onInstall(room, data.to)
        end
      end
    end
  end

  room.logic:trigger(fk.AfterCardsMove, nil, moveCardsData)
  return true
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
    if type(info.visiblePlayers) == "table" then
      info.visiblePlayers = table.map(info.visiblePlayers, Util.Id2PlayerMapper)
    elseif type(info.visiblePlayers) == "number" then
      info.visiblePlayers = room:getPlayerById(info.visiblePlayers)
    end
  end
end

--- 将填入room:moveCards的参数，根据情况转为正确的data（防止非法移动）
---@param room Room
---@param ... CardsMoveInfo
---@return MoveCardsData[]
local function moveInfoTranslate(room, ...)
  ---@type MoveCardsData[]
  local ret = {}
  for _, cardsMoveInfo in ipairs{ ... } do
    convertOldMoveInfo(cardsMoveInfo)
    if #cardsMoveInfo.ids == 0 then goto continue end
    infoCheck(cardsMoveInfo)

    -- 若移动到被废除的装备栏，则修改，否则原样
    local infos = {} ---@type MoveInfo[]
    local abortMoveInfos = {} ---@type MoveInfo[]
    for _, id in ipairs(cardsMoveInfo.ids) do
      local toAbortDrop = false
      if cardsMoveInfo.toArea == Card.PlayerEquip and cardsMoveInfo.to then
        local moveToPlayer = cardsMoveInfo.to
        ---@cast moveToPlayer -nil 防止判空波浪线
        local card = moveToPlayer:getVirualEquip(id) or Fk:getCardById(id)
        if card.type == Card.TypeEquip and #moveToPlayer:getAvailableEquipSlots(card.sub_type) == 0 then
          table.insert(abortMoveInfos, {
            cardId = id,
            fromArea = room:getCardArea(id),
            fromSpecialName = cardsMoveInfo.from and cardsMoveInfo.from:getPileNameOfId(id),
          })
          toAbortDrop = true
        end
      end

      if not toAbortDrop then
        table.insert(infos, {
          cardId = id,
          fromArea = room:getCardArea(id),
          fromSpecialName = cardsMoveInfo.from and cardsMoveInfo.from:getPileNameOfId(id),
        })
      end
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
    ::continue::
  end
  return ret
end

--- 传入一系列移牌信息，去实际移动这些牌
---@param ... CardsMoveInfo
---@return boolean?
function MoveEventWrappers:moveCards(...)
  local datas = moveInfoTranslate(self, ...)
  if #datas == 0 then
    return false
  end
  return exec(MoveCards, datas)
end

--- 向多名玩家告知一次移牌行为。
---@param players? ServerPlayer[] @ 要被告知的玩家列表，默认为全员
---@param moveDatas MoveCardsData[] @ 要告知的移牌信息列表
function MoveEventWrappers:notifyMoveCards(players, moveDatas)
  if players == nil or #players == 0 then players = self.players end
  for _, p in ipairs(players) do
    local arg = {}
    for _, move in ipairs(moveDatas) do
      for _, info in ipairs(move.moveInfo) do
        local realFromArea = self:getCardArea(info.cardId)
        local playerAreas = { Player.Hand, Player.Equip, Player.Judge, Player.Special }
        local virtualEquip

        if table.contains(playerAreas, realFromArea) and move.from then
          virtualEquip = move.from:getVirualEquip(info.cardId)
        end

        if table.contains(playerAreas, move.toArea) and move.to and virtualEquip then
          move.to:addVirtualEquip(virtualEquip)
        end
      end

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
    p:doNotify("MoveCards", json.encode(arg))
  end
end

--- 让一名玩家获得一张牌
---@param player integer|ServerPlayer @ 要拿牌的玩家
---@param card integer|integer[]|Card|Card[] @ 要拿到的卡牌
---@param unhide? boolean @ 是否明着拿
---@param reason? CardMoveReason @ 卡牌移动的原因
---@param proposer? integer @ 移动操作者的id
---@param skill_name? string @ 技能名
---@param moveMark? table|string @ 移动后自动赋予标记，格式：{标记名(支持-inarea后缀，移出值代表区域后清除), 值}
---@param visiblePlayers? integer|integer[] @ 控制移动对特定角色可见（在moveVisible为false时生效）
function MoveEventWrappers:obtainCard(player, card, unhide, reason, proposer, skill_name, moveMark, visiblePlayers)
  local pid = type(player) == "number" and player or player.id
  self:moveCardTo(card, Card.PlayerHand, player, reason, skill_name, nil, unhide, proposer or pid, moveMark, visiblePlayers)
end

--- 让玩家摸牌
---@param player ServerPlayer @ 摸牌的玩家
---@param num integer @ 摸牌数
---@param skillName? string @ 技能名
---@param fromPlace? DrawPilePos @ 摸牌的位置，默认牌堆顶
---@param moveMark? table|string @ 移动后自动赋予标记，格式：{标记名(支持-inarea后缀，移出值代表区域后清除), 值}
---@return integer[] @ 摸到的牌
function MoveEventWrappers:drawCards(player, num, skillName, fromPlace, moveMark)
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
---@param proposer? integer @ 移动操作者的id
---@param moveMark? table|string @ 移动后自动赋予标记，格式：{标记名(支持-inarea后缀，移出值代表区域后清除), 值}
---@param visiblePlayers? integer|integer[] @ 控制移动对特定角色可见（在moveVisible为false时生效）
function MoveEventWrappers:moveCardTo(card, to_place, target, reason, skill_name, special_name, visible, proposer, moveMark, visiblePlayers)
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
      return move.from == self.owner_map[cardId]
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
  self:moveCards({
    ids = Card:getIdList(card_ids),
    from = who,
    toArea = Card.DiscardPile,
    moveReason = fk.ReasonDiscard,
    proposer = thrower.id,
    skillName = skillName
  })
end

--- 重铸一名角色的牌。
---@param card_ids integer[] @ 被重铸的牌
---@param who ServerPlayer @ 重铸的角色
---@param skillName? string @ 技能名，默认为“重铸”
---@return integer[] @ 摸到的牌
function MoveEventWrappers:recastCard(card_ids, who, skillName)
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
    proposer = who.id
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
  return self:drawCards(who, #card_ids, skillName)
end

--- 将一些卡牌同时分配给一些角色。
---@param list table<integer, integer[]> @ 分配牌和角色的数据表，键为角色id，值为分配给其的牌id数组
---@param proposer? integer @ 操作者的id。默认为空
---@param skillName? string @ 技能名。默认为“分配”
---@return table<integer[]> @ 返回成功分配的卡牌
function MoveEventWrappers:doYiji(list, proposer, skillName)
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
        })
      end
    end
  end
  if #moveInfos > 0 then
    self:moveCards(table.unpack(moveInfos))
  end
  return move_ids
end

--- 将一张牌移动至某角色的装备区，若不合法则置入弃牌堆。目前没做相同副类别装备同时置入的适配(甘露神典韦)
---@param target ServerPlayer @ 接受牌的角色
---@param cards integer|integer[] @ 移动的牌
---@param skillName? string @ 技能名
---@param convert? boolean @ 是否可以替换装备（默认可以）
---@param proposer? ServerPlayer | integer @ 操作者
function MoveEventWrappers:moveCardIntoEquip(target, cards, skillName, convert, proposer)
  convert = (convert == nil) and true or convert
  skillName = skillName or ""
  cards = type(cards) == "table" and cards or {cards}
  ---@cast cards integer[]
  proposer = type(proposer) == "number" and self:getPlayerById(proposer) or proposer
  local moves = {}
  for _, cardId in ipairs(cards) do
    local card = Fk:getCardById(cardId)
    local from = self:getCardOwner(cardId)
    if target:canMoveCardIntoEquip(cardId, convert) then
      if target:hasEmptyEquipSlot(card.sub_type) then
        table.insert(moves,{ids = {cardId}, from = from, to = target, toArea = Card.PlayerEquip, moveReason = fk.ReasonPut,skillName = skillName,proposer = proposer})
      else
        local existingEquip = target:getEquipments(card.sub_type)
        local throw = #existingEquip == 1 and existingEquip[1] or
        self:askToChooseCard(proposer or target, { target = target, flag = { card_data = { { Util.convertSubtypeAndEquipSlot(card.sub_type),existingEquip } } }, skill_name = "replaceEquip", prompt = "#replaceEquip" })
        table.insert(moves, { ids = { throw }, from = target.id, toArea = Card.DiscardPile, moveReason = fk.ReasonPutIntoDiscardPile, skillName = skillName, proposer = proposerId })
        table.insert(moves, { ids = { cardId }, from = fromId, to = target.id, toArea = Card.PlayerEquip, moveReason = fk.ReasonPut, skillName = skillName, proposer = proposerId })
      end
    else
      table.insert(moves,{ ids = { cardId }, from = fromId, toArea = Card.DiscardPile, moveReason = fk.ReasonPutIntoDiscardPile,skillName = skillName })
    end
  end
  self:moveCards(table.unpack(moves))
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
