-- SPDX-License-Identifier: GPL-3.0-or-later

GameEvent.functions[GameEvent.MoveCards] = function(self)
  local args = self.data
  local self = self.room
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
      for _, id in ipairs(cardsMoveInfo.ids) do
        table.insert(infos, {
          cardId = id,
          fromArea = self:getCardArea(id),
          fromSpecialName = cardsMoveInfo.from and self:getPlayerById(cardsMoveInfo.from):getPileNameOfId(id),
        })
      end

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
  end

  if #cardsMoveStructs < 1 then
    return false
  end

  if self.logic:trigger(fk.BeforeCardsMove, nil, cardsMoveStructs) then
    self.logic:breakEvent(false)
  end

  self:notifyMoveCards(nil, cardsMoveStructs)

  for _, data in ipairs(cardsMoveStructs) do
    if #data.moveInfo > 0 then
      infoCheck(data)

      ---@param info MoveInfo
      for _, info in ipairs(data.moveInfo) do
        local realFromArea = self:getCardArea(info.cardId)
        local playerAreas = { Player.Hand, Player.Equip, Player.Judge, Player.Special }
        local virtualEquip

        if table.contains(playerAreas, realFromArea) and data.from then
          local from = self:getPlayerById(data.from)
          from:removeCards(realFromArea, { info.cardId }, info.fromSpecialName)
          virtualEquip = from:getVirualEquip(info.cardId)

        elseif realFromArea ~= Card.Unknown then
          local fromAreaIds = {}
          if realFromArea == Card.Processing then
            fromAreaIds = self.processing_area
          elseif realFromArea == Card.DrawPile then
            fromAreaIds = self.draw_pile
          elseif realFromArea == Card.DiscardPile then
            fromAreaIds = self.discard_pile
          elseif realFromArea == Card.Void then
            fromAreaIds = self.void
          end

          table.removeOne(fromAreaIds, info.cardId)
        end

        if table.contains(playerAreas, data.toArea) and data.to then
          local to = self:getPlayerById(data.to)
          if virtualEquip then to:addVirtualEquip(virtualEquip) end
          to:addCards(data.toArea, { info.cardId }, data.specialName)

        else
          local toAreaIds = {}
          if data.toArea == Card.Processing then
            toAreaIds = self.processing_area
          elseif data.toArea == Card.DrawPile then
            toAreaIds = self.draw_pile
          elseif data.toArea == Card.DiscardPile then
            toAreaIds = self.discard_pile
          elseif data.toArea == Card.Void then
            toAreaIds = self.void
          end

          if data.toArea == Card.DrawPile then
            local putIndex = data.drawPilePosition or 1
            if putIndex == -1 then
              putIndex = #self.draw_pile + 1
            elseif putIndex < 1 or putIndex > #self.draw_pile + 1 then
              putIndex = 1
            end

            table.insert(toAreaIds, putIndex, info.cardId)
          else
            table.insert(toAreaIds, info.cardId)
          end
        end
        self:setCardArea(info.cardId, data.toArea, data.to)
        if data.toArea == Card.DrawPile or realFromArea == Card.DrawPile then
          self:doBroadcastNotify("UpdateDrawPile", #self.draw_pile)
        end

        if not (data.to and data.toArea ~= Card.PlayerHand) then
          Fk:filterCard(info.cardId, self:getPlayerById(data.to))
        end

        local currentCard = Fk:getCardById(info.cardId)
        if
          data.toArea == Player.Equip and
          currentCard.type == Card.TypeEquip and
          data.to ~= nil and
          self:getPlayerById(data.to):isAlive() and
          currentCard.equip_skill
        then
          currentCard:onInstall(self, self:getPlayerById(data.to))
        end

        if
          realFromArea == Player.Equip and
          currentCard.type == Card.TypeEquip and
          data.from ~= nil and
          currentCard.equip_skill
        then
          currentCard:onUninstall(self, self:getPlayerById(data.from))
        end
      end
    end
  end

  self.logic:trigger(fk.AfterCardsMove, nil, cardsMoveStructs)
  return true
end
