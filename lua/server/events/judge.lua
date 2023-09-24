-- SPDX-License-Identifier: GPL-3.0-or-later

GameEvent.functions[GameEvent.Judge] = function(self)
  local data = table.unpack(self.data)
  local room = self.room
  local logic = room.logic
  local who = data.who
  data.good = data.good ~= false --为了以后实现判定反转的效果
  data.negative = data.negative == true
  logic:trigger(fk.StartJudge, who, data)
  data.card = data.card or Fk:getCardById(room:getNCards(1)[1])

  if data.reason ~= "" then
    room:sendLog{
      type = "#StartJudgeReason",
      from = who.id,
      arg = data.reason,
    }
  end

  room:sendLog{
    type = "#InitialJudge",
    from = who.id,
    card = {data.card.id},
  }
  room:moveCardTo(data.card, Card.Processing, nil, fk.ReasonJudge)
  room:sendFootnote({ data.card.id }, {
    type = "##JudgeCard",
    arg = data.reason,
  })

  data.isgood = data.good == data.card:matchPattern(data.pattern)

  logic:trigger(fk.AskForRetrial, who, data)
  logic:trigger(fk.FinishRetrial, who, data)
  Fk:filterCard(data.card.id, who, data)
  room:sendLog{
    type = "#JudgeResult",
    from = who.id,
    card = {data.card.id},
  }
  room:sendFootnote({ data.card.id }, {
    type = "##JudgeCard",
    arg = data.reason,
  })

  if data.pattern then
    room:delay(400);
    if data.negative
    then
      room:setCardEmotion(data.card.id, data.card:matchPattern(data.pattern) and "judgebad" or "judgegood")
    else
      room:setCardEmotion(data.card.id, data.card:matchPattern(data.pattern) and "judgegood" or "judgebad")
    end
    room:delay(900);
  end
  data.isgood = data.good == data.card:matchPattern(data.pattern)

  if logic:trigger(fk.FinishJudge, who, data) then
    logic:breakEvent()
  end
end

GameEvent.cleaners[GameEvent.Judge] = function(self)
  local data = table.unpack(self.data)
  local room = self.room
  if (self.interrupted or not data.skipDrop) and room:getCardArea(data.card.id) == Card.Processing then
    room:moveCardTo(data.card, Card.DiscardPile, nil, fk.ReasonJudge)
  end
  if not self.interrupted then return end

  -- prohibit access to judge.card
  setmetatable(data, {
    __index = function(s, key)
      if key == "card" then
        error("__manuallyBreak")
      end
      return rawget(s, key)
    end
  })
end
