-- SPDX-License-Identifier: GPL-3.0-or-later

---@class GameEvent.Judge : GameEvent
local Judge = GameEvent:subclass("GameEvent.Judge")
function Judge:main()
  local data = table.unpack(self.data)
  local room = self.room
  local logic = room.logic
  local who = data.who

  data.isJudgeEvent = true
  logic:trigger(fk.StartJudge, who, data)
  data.card = data.card or Fk:getCardById(room:getNCards(1)[1])

  if data.reason ~= "" then
    room:sendLog{
      type = "#StartJudgeReason",
      from = who.id,
      arg = data.reason,
    }
  end
  Fk:filterCard(data.card.id, who, data)

  room:sendLog{
    type = "#InitialJudge",
    from = who.id,
    arg = data.card:toLogString(),
  }
  room:moveCardTo(data.card, Card.Processing, nil, fk.ReasonJudge)
  room:sendFootnote({ data.card.id }, {
    type = "##JudgeCard",
    arg = data.reason,
  })

  logic:trigger(fk.AskForRetrial, who, data)
  logic:trigger(fk.FinishRetrial, who, data)
  room:sendLog{
    type = "#JudgeResult",
    from = who.id,
    arg = data.card:toLogString(),
  }
  room:sendFootnote({ data.card.id }, {
    type = "##JudgeCard",
    arg = data.reason,
  })

  if data.pattern then
    room:delay(400);
    room:setCardEmotion(data.card.id, data.card:matchPattern(data.pattern) and "judgegood" or "judgebad")
    room:delay(900);
  end

  if logic:trigger(fk.FinishJudge, who, data) then
    logic:breakEvent()
  end
end

function Judge:clear()
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

return Judge
