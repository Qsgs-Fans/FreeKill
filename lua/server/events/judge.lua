GameEvent.functions[GameEvent.Judge] = function(self)
  local data = table.unpack(self.data)
  local self = self.room
  local who = data.who
  self.logic:trigger(fk.StartJudge, who, data)
  data.card = data.card or Fk:getCardById(self:getNCards(1)[1])

  if data.reason ~= "" then
    self:sendLog{
      type = "#StartJudgeReason",
      from = who.id,
      arg = data.reason,
    }
  end

  self:sendLog{
    type = "#InitialJudge",
    from = who.id,
    card = {data.card.id},
  }
  self:moveCardTo(data.card, Card.Processing, nil, fk.ReasonPut)

  self.logic:trigger(fk.AskForRetrial, who, data)
  self.logic:trigger(fk.FinishRetrial, who, data)
  Fk:filterCard(data.card.id, who, data)
  self:sendLog{
    type = "#JudgeResult",
    from = who.id,
    card = {data.card.id},
  }

  if data.pattern then
    self:delay(400);
    self:setCardEmotion(data.card.id, data.card:matchPattern(data.pattern) and "judgegood" or "judgebad")
    self:delay(900);
  end

  if self.logic:trigger(fk.FinishJudge, who, data) then
    self.logic:breakEvent()
  end
  if self:getCardArea(data.card.id) == Card.Processing then
    self:moveCardTo(data.card, Card.DiscardPile, nil, fk.ReasonPutIntoDiscardPile)
  end
end

GameEvent.cleaners[GameEvent.Judge] = function(self)
  local data = table.unpack(self.data)
  local self = self.room
  if self:getCardArea(data.card.id) == Card.Processing then
    self:moveCardTo(data.card, Card.DiscardPile, nil, fk.ReasonPutIntoDiscardPile)
  end
  if not self.interrupted then return end

  -- prohibit access to judge.card
  setmetatable(data, {
    __index = function(self, key)
      if key == "card" then
        error("__manuallyBreak")
      end
      return rawget(self, key)
    end
  })
end
