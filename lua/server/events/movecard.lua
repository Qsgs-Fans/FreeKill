-- SPDX-License-Identifier: GPL-3.0-or-later

GameEvent.functions[GameEvent.MoveCards] = function(self)
  local args = self.data
  local room = self.room
  ---@type CardsMoveStruct[]
  local cardsMoveStructs = {}
  local infoCheck = function(info)
    assert(table.contains({ Card.PlayerHand, Card.PlayerEquip, Card.PlayerJudge, Card.PlayerSpecial, Card.Processing, Card.DrawPile, Card.DiscardPile, Card.Void }, info.toArea))
    assert(info.toArea ~= Card.PlayerSpecial or type(info.specialName) == "string")
    assert(type(info.moveReason) == "number")
  end

  for _, cardsMoveInfo in ipairs(args) do
    if #cardsMoveInfo.ids > 0 then
      infoCheck(cardsMoveInfo)

      ---@type MoveInfo[]
      local infos = {}
      local abortMoveInfos = {}
      for _, id in ipairs(cardsMoveInfo.ids) do
        local toAbortDrop = false
        if cardsMoveInfo.toArea == Card.PlayerEquip and cardsMoveInfo.to then
          local moveToPlayer = room:getPlayerById(cardsMoveInfo.to)
          local card = moveToPlayer:getVirualEquip(id) or Fk:getCardById(id)
          if card.type == Card.TypeEquip and #moveToPlayer:getAvailableEquipSlots(card.sub_type) == 0 then
            table.insert(abortMoveInfos, {
              cardId = id,
              fromArea = room:getCardArea(id),
              fromSpecialName = cardsMoveInfo.from and room:getPlayerById(cardsMoveInfo.from):getPileNameOfId(id),
            })
            toAbortDrop = true
          end
        end

        if not toAbortDrop then
          table.insert(infos, {
            cardId = id,
            fromArea = room:getCardArea(id),
            fromSpecialName = cardsMoveInfo.from and room:getPlayerById(cardsMoveInfo.from):getPileNameOfId(id),
          })
        end
      end

      if #infos > 0 then
        ---@type CardsMoveStruct
        local cardsMoveStruct = {
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
        }

        table.insert(cardsMoveStructs, cardsMoveStruct)
      end

      if #abortMoveInfos > 0 then
        ---@type CardsMoveStruct
        local cardsMoveStruct = {
          moveInfo = abortMoveInfos,
          from = cardsMoveInfo.from,
          toArea = Card.DiscardPile,
          moveReason = fk.ReasonPutIntoDiscardPile,
          specialName = cardsMoveInfo.specialName,
          specialVisible = cardsMoveInfo.specialVisible,
          drawPilePosition = cardsMoveInfo.drawPilePosition,
        }

        table.insert(cardsMoveStructs, cardsMoveStruct)
      end
    end
  end

  self.data = cardsMoveStructs

  if #cardsMoveStructs < 1 then
    return false
  end

  if room.logic:trigger(fk.BeforeCardsMove, nil, cardsMoveStructs) then
    room.logic:breakEvent(false)
  end

  room:notifyMoveCards(nil, cardsMoveStructs)

  for _, data in ipairs(cardsMoveStructs) do
    if #data.moveInfo > 0 then
      infoCheck(data)

      ---@param info MoveInfo
      for _, info in ipairs(data.moveInfo) do
        local realFromArea = room:getCardArea(info.cardId)
        local playerAreas = { Player.Hand, Player.Equip, Player.Judge, Player.Special }

        if table.contains(playerAreas, realFromArea) and data.from then
          local from = room:getPlayerById(data.from)
          from:removeCards(realFromArea, { info.cardId }, info.fromSpecialName)

        elseif realFromArea ~= Card.Unknown then
          local fromAreaIds = {}
          if realFromArea == Card.Processing then
            fromAreaIds = room.processing_area
          elseif realFromArea == Card.DrawPile then
            fromAreaIds = room.draw_pile
          elseif realFromArea == Card.DiscardPile then
            fromAreaIds = room.discard_pile
          elseif realFromArea == Card.Void then
            fromAreaIds = room.void
          end

          table.removeOne(fromAreaIds, info.cardId)
        end

        if table.contains(playerAreas, data.toArea) and data.to then
          local to = room:getPlayerById(data.to)
          to:addCards(data.toArea, { info.cardId }, data.specialName)

        else
          local toAreaIds = {}
          if data.toArea == Card.Processing then
            toAreaIds = room.processing_area
          elseif data.toArea == Card.DrawPile then
            toAreaIds = room.draw_pile
          elseif data.toArea == Card.DiscardPile then
            toAreaIds = room.discard_pile
          elseif data.toArea == Card.Void then
            toAreaIds = room.void
          end

          if data.toArea == Card.DrawPile then
            local putIndex = data.drawPilePosition or 1
            if putIndex == -1 then
              putIndex = #room.draw_pile + 1
            elseif putIndex < 1 or putIndex > #room.draw_pile + 1 then
              putIndex = 1
            end

            table.insert(toAreaIds, putIndex, info.cardId)
          else
            table.insert(toAreaIds, info.cardId)
          end
        end
        room:setCardArea(info.cardId, data.toArea, data.to)
        if data.toArea == Card.DrawPile or realFromArea == Card.DrawPile then
          room:doBroadcastNotify("UpdateDrawPile", #room.draw_pile)
        end

        if not (data.to and data.toArea ~= Card.PlayerHand) then
          Fk:filterCard(info.cardId, room:getPlayerById(data.to))
        end

        local currentCard = Fk:getCardById(info.cardId)
        for name, _ in pairs(currentCard.mark) do
          if name:endsWith("-inhand") and
          realFromArea == Player.Hand and
          data.from
          then
            room:setCardMark(currentCard, name, 0)
          end
        end
        if
          data.toArea == Player.Equip and
          currentCard.type == Card.TypeEquip and
          data.to ~= nil and
          room:getPlayerById(data.to):isAlive() and
          currentCard.equip_skill
        then
          currentCard:onInstall(room, room:getPlayerById(data.to))
        end

        if
          realFromArea == Player.Equip and
          currentCard.type == Card.TypeEquip and
          data.from ~= nil and
          currentCard.equip_skill
        then
          currentCard:onUninstall(room, room:getPlayerById(data.from))
        end
      end
    end
  end

  room.logic:trigger(fk.AfterCardsMove, nil, cardsMoveStructs)
  return true
end
