-- SPDX-License-Identifier: GPL-3.0-or-later

GameEvent.functions[GameEvent.Pindian] = function(self)
  local pindianData = table.unpack(self.data)
  local room = self.room
  local logic = room.logic
  logic:trigger(fk.StartPindian, pindianData.from, pindianData)

  if pindianData.reason ~= "" then
    room:sendLog{
      type = "#StartPindianReason",
      from = pindianData.from.id,
      arg = pindianData.reason,
    }
  end

  local extraData = {
    num = 1,
    min_num = 1,
    include_equip = false,
    pattern = ".",
    reason = pindianData.reason,
  }
  local prompt = "#askForPindian:::" .. pindianData.reason
  local data = { "choose_cards_skill", prompt, false, json.encode(extraData) }

  local targets = {}
  local moveInfos = {}
  if not pindianData.fromCard then
    table.insert(targets, pindianData.from)
    pindianData.from.request_data = json.encode(data)
  else
    local _pindianCard = pindianData.fromCard
    local pindianCard = _pindianCard:clone(_pindianCard.suit, _pindianCard.number)
    pindianCard:addSubcard(_pindianCard.id)

    pindianData.fromCard = pindianCard

    table.insert(moveInfos, {
      ids = { _pindianCard.id },
      from = pindianData.from.id,
      fromArea = room:getCardArea(_pindianCard.id),
      toArea = Card.Processing,
      moveReason = fk.ReasonPut,
      skillName = pindianData.reason,
      moveVisible = true,
    })
  end
  for _, to in ipairs(pindianData.tos) do
    if pindianData.results[to.id] and pindianData.results[to.id].toCard then
      local _pindianCard = pindianData.results[to.id].toCard
      local pindianCard = _pindianCard:clone(_pindianCard.suit, _pindianCard.number)
      pindianCard:addSubcard(_pindianCard.id)

      pindianData.results[to.id].toCard = pindianCard

      table.insert(moveInfos, {
        ids = { _pindianCard.id },
        from = to.id,
        fromArea = room:getCardArea(_pindianCard.id),
        toArea = Card.Processing,
        moveReason = fk.ReasonPut,
        skillName = pindianData.reason,
        moveVisible = true,
      })
    else
      table.insert(targets, to)
      to.request_data = json.encode(data)
    end
  end

  room:notifyMoveFocus(targets, "AskForPindian")
  room:doBroadcastRequest("AskForUseActiveSkill", targets)

  for _, p in ipairs(targets) do
    local _pindianCard
    if p.reply_ready then
      local replyCard = json.decode(p.client_reply).card
      _pindianCard = Fk:getCardById(json.decode(replyCard).subcards[1])
    else
      _pindianCard = Fk:getCardById(p:getCardIds(Player.Hand)[1])
    end

    local pindianCard = _pindianCard:clone(_pindianCard.suit, _pindianCard.number)
    pindianCard:addSubcard(_pindianCard.id)

    if p == pindianData.from then
      pindianData.fromCard = pindianCard
    else
      pindianData.results[p.id] = pindianData.results[p.id] or {}
      pindianData.results[p.id].toCard = pindianCard
    end

    table.insert(moveInfos, {
      ids = { _pindianCard.id },
      from = p.id,
      toArea = Card.Processing,
      moveReason = fk.ReasonPut,
      skillName = pindianData.reason,
      moveVisible = true,
    })

    room:sendLog{
      type = "#ShowPindianCard",
      from = p.id,
      card = { _pindianCard.id },
    }
  end

  room:moveCards(table.unpack(moveInfos))

  logic:trigger(fk.PindianCardsDisplayed, nil, pindianData)

  for toId, result in pairs(pindianData.results) do
    local to = room:getPlayerById(toId)
    if pindianData.fromCard.number > result.toCard.number then
      result.winner = pindianData.from
    elseif pindianData.fromCard.number < result.toCard.number then
      result.winner = to
    end

    local singlePindianData = {
      from = pindianData.from,
      to = to,
      fromCard = pindianData.fromCard,
      toCard = result.toCard,
      winner = result.winner,
      reason = pindianData.reason,
    }

    room:sendLog{
      type = "#ShowPindianResult",
      from = pindianData.from.id,
      to = { toId },
      arg = result.winner == pindianData.from and "pindianwin" or "pindiannotwin"
    }
    logic:trigger(fk.PindianResultConfirmed, nil, singlePindianData)
  end

  if logic:trigger(fk.PindianFinished, pindianData.from, pindianData) then
    logic:breakEvent()
  end
end

GameEvent.cleaners[GameEvent.Pindian] = function(self)
  local pindianData = table.unpack(self.data)
  local room = self.room

  local toProcessingArea = {}
  local leftFromCardIds = room:getSubcardsByRule(pindianData.fromCard, { Card.Processing })
  if #leftFromCardIds > 0 then
    table.insertTable(toProcessingArea, leftFromCardIds)
  end

  for _, result in pairs(pindianData.results) do
    local leftToCardIds = room:getSubcardsByRule(result.toCard, { Card.Processing })
    if #leftToCardIds > 0 then
      table.insertTable(toProcessingArea, leftToCardIds)
    end
  end

  if #toProcessingArea > 0 then
    room:moveCards({
      ids = toProcessingArea,
      toArea = Card.DiscardPile,
      moveReason = fk.ReasonPutIntoDiscardPile,
    })
  end
  if not self.interrupted then return end
end
