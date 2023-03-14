GameEvent.functions[GameEvent.Pindian] = function(self)
  local pindianData = table.unpack(self.data)
  local self = self.room
  self.logic:trigger(fk.StartPindian, pindianData.from, pindianData)

  if pindianData.reason ~= "" then
    self:sendLog{
      type = "#StartPindianReason",
      from = pindianData.from.id,
      arg = pindianData.reason,
    }
  end

  local extraData = {
    num = 1,
    min_num = 1,
    include_equip = false,
    reason = pindianData.reason
  }
  local prompt = "#askForPindian"
  local data = { "choose_cards_skill", prompt, true, json.encode(extraData) }

  local targets = {}
  if not pindianData.fromCard then
    table.insert(targets, pindianData.from)
    pindianData.from.request_data = json.encode(data)
  end
  for _, to in ipairs(pindianData.tos) do
    if not (pindianData.results[to.id] and pindianData.results[to.id].toCard) then
      table.insert(targets, to)
      to.request_data = json.encode(data)
    end
  end

  self:notifyMoveFocus(targets, "AskForPindian")
  self:doBroadcastRequest("AskForUseActiveSkill", targets)

  local moveInfos = {}
  for _, p in ipairs(targets) do
    local pindianCard
    if p.reply_ready then
      local replyCard = json.decode(p.client_reply).card
      pindianCard = Fk:getCardById(json.decode(replyCard).subcards[1])
    else
      pindianCard = Fk:getCardById(p:getCardIds(Player.Hand)[1])
    end

    if p == pindianData.from then
      pindianData.fromCard = pindianCard
    else
      pindianData.results[p.id] = pindianData.results[p.id] or {}
      pindianData.results[p.id].toCard = pindianCard
    end

    table.insert(moveInfos, {
      ids = { pindianCard.id },
      from = p.id,
      toArea = Card.Processing,
      moveReason = fk.ReasonPut,
      skillName = pindianData.reason,
      moveVisible = true,
    })
  end

  self:moveCards(table.unpack(moveInfos))

  self.logic:trigger(fk.PindianCardsDisplayed, nil, pindianData)

  for toId, result in pairs(pindianData.results) do
    if pindianData.fromCard.number > result.toCard.number then
      pindianData.results[toId].winner = pindianData.from
    elseif pindianData.fromCard.number > result.toCard.number then
      pindianData.results[toId].winner = Fk:getCardById(toId)
    end

    local singlePindianData = {
      from = pindianData.from,
      to = self:getPlayerById(toId),
      fromCard = pindianData.fromCard,
      toCard = result.toCard,
      winner = pindianData.results[toId].winner,
    }
    self.logic:trigger(fk.PindianResultConfirmed, nil, singlePindianData)
  end

  if self.logic:trigger(fk.PindianFinished, pindianData.from, pindianData) then
    self.logic:breakEvent()
  end
end

GameEvent.cleaners[GameEvent.Pindian] = function(self)
  local pindianData = table.unpack(self.data)
  local self = self.room

  local toProcessingArea = {}
  local leftFromCardIds = self:getSubcardsByRule(pindianData.fromCard, { Card.Processing })
  if #leftFromCardIds > 0 then
    table.insertTable(toProcessingArea, leftFromCardIds)
  end

  for _, result in pairs(pindianData.results) do
    local leftToCardIds = self:getSubcardsByRule(result.toCard, { Card.Processing })
    if #leftToCardIds > 0 then
      table.insertTable(toProcessingArea, leftToCardIds)
    end
  end

  if #toProcessingArea > 0 then
    self:moveCards({
      ids = toProcessingArea,
      toArea = Card.DiscardPile,
      moveReason = fk.ReasonPutIntoDiscardPile,
    })
  end
  if not self.interrupted then return end
end
