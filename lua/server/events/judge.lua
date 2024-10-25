-- SPDX-License-Identifier: GPL-3.0-or-later

---@class JudgeEventWrappers: Object
local JudgeEventWrappers = {} -- mixin

---@return boolean
local function exec(tp, ...)
  local event = tp:create(...)
  local _, ret = event:exec()
  return ret
end

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

-- 判定

--- 根据判定数据进行判定。判定的结果直接保存在这个数据中。
---@param data JudgeStruct
function JudgeEventWrappers:judge(data)
  return exec(Judge, data)
end

--- 改判。
---@param card Card @ 改判的牌
---@param player ServerPlayer @ 改判的玩家
---@param judge JudgeStruct @ 要被改判的判定数据
---@param skillName? string @ 技能名
---@param exchange? boolean @ 是否要替换原有判定牌（即类似鬼道那样）
function JudgeEventWrappers:retrial(card, player, judge, skillName, exchange)
  if not card then return end
  local triggerResponded = self.owner_map[card:getEffectiveId()] == player
  local isHandcard = (triggerResponded and self:getCardArea(card:getEffectiveId()) == Card.PlayerHand)

  if triggerResponded then
    local resp = {} ---@type CardResponseEvent
    resp.from = player.id
    resp.card = card
    resp.skipDrop = true
    self:responseCard(resp)
  else
    local move1 = {} ---@type CardsMoveInfo
    move1.ids = { card:getEffectiveId() }
    move1.from = player.id
    move1.toArea = Card.Processing
    move1.moveReason = fk.ReasonJustMove
    move1.skillName = skillName
    self:moveCards(move1)
  end

  local oldJudge = judge.card
  judge.card = card
  local rebyre = judge.retrial_by_response
  judge.retrial_by_response = player

  self:sendLog{
    type = "#ChangedJudge",
    from = player.id,
    to = { judge.who.id },
    arg2 = card:toLogString(),
    arg = skillName,
  }

  Fk:filterCard(judge.card.id, judge.who, judge)

  exchange = exchange and not player.dead

  local move2 = {} ---@type CardsMoveInfo
  move2.ids = { oldJudge:getEffectiveId() }
  move2.toArea = exchange and Card.PlayerHand or Card.DiscardPile
  move2.moveReason = exchange and fk.ReasonJustMove or fk.ReasonJudge
  move2.to = exchange and player.id or nil
  move2.skillName = skillName

  self:moveCards(move2)
end

return { Judge, JudgeEventWrappers }
