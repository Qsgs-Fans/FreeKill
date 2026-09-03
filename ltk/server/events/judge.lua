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
---@field public data JudgeData
local Judge = GameEvent:subclass("GameEvent.Judge")

function Judge:__tostring()
  local data = self.data
  return string.format("<Judge %s: %s #%d>",
    data.reason, data.who, self.id)
end

function Judge:main()
  local data = self.data
  local room = self.room
  local logic = room.logic
  local who = data.who
  data.results = {}

  logic:trigger(fk.StartJudge, who, data)
  if not data.card then
    local card = Fk:getCardById(room:getNCards(1)[1])
    data.card = Fk:cloneCard(card.name)
    data.card:addSubcard(card.id)
    data.card = card
  end

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
    arg = data.card,
  }
  room:moveCardTo(data.card, Card.Processing, nil, fk.ReasonJudge)
  room:sendFootnote({ data.card:getEffectiveId() }, {
    type = "##JudgeCard",
    arg = data.reason,
  })
  local cid = data.card:getEffectiveId()
  if cid and room:getCardArea(cid) == Card.Processing then
    data.card = room:filterCard(cid, who, true)
  end

  logic:trigger(fk.AskForRetrial, who, data)
  logic:trigger(fk.FinishRetrial, who, data)
  room:sendLog{
    type = "#JudgeResult",
    from = who.id,
    arg = data.card,
  }

  cid = data.card:getEffectiveId()  ---@cast cid integer
  if cid and room:getCardArea(cid) == Card.Processing then
    room:sendFootnote({ cid }, {
      type = "##JudgeCard",
      arg = data.reason,
    })
    room:delay(300)
  end

  local results = data.results  ---@cast results table
  -- 对现有的string做分歧处理
  if not next(results) then
    for pattern, result in pairs(data.pattern) do
      if data.card:matchPattern(pattern) then
        table.insertTableIfNeed(results,
        type(result) == "table" and result or { result })
      end
    end
    if not next(results) then
      local result = data.pattern["else"]
      table.insertTableIfNeed(results,
        type(result) == "table" and result or { result })
    end
  end

  if cid and room:getCardArea(cid) == Card.Processing then
    if table.contains(results, "good") then
      room:setCardEmotion(cid, "judgegood")
    elseif table.contains(results, "bad") then
      room:setCardEmotion(cid, "judgebad")
    end
    room:delay(900)
  end

  if logic:trigger(fk.FinishJudge, who, data) then
    logic:breakEvent()
  end
end

function Judge:clear()
  local data = self.data
  local room = self.room
  if (self.interrupted or not data.skipDrop) and data.card and room:getCardArea(data.card:getEffectiveId()) == Card.Processing then
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
---@param data JudgeDataSpec
function JudgeEventWrappers:judge(data)
  data = JudgeData:new(data)
  return exec(Judge, data)
end


--- 改判参数集
---@class RetrialParams
---@field card Card @ 新的判定牌
---@field player ServerPlayer @ 改判的发动者
---@field data JudgeData @ 要被改判的判定数据
---@field skillName? string @ 技能名
---@field exchange? boolean @ 改判者是否获得原判定牌（鬼道）。默认否
---@field response? boolean @ 是否以打出方式改判（老诸葛瑾）。默认否


--- 改变判定牌
---@param params RetrialParams
function JudgeEventWrappers:changeJudge(params)
  local card, player, data, skillName = params.card, params.player, params.data, params.skillName
  if not card then return end
  ---@cast self Room

  local newId = card:getEffectiveId()
  local oldId = data.card:getEffectiveId()
  if newId and self:getCardArea(newId) ~= Card.Processing then
    self:moveCards{
      ids = {newId},
      from = self:getCardOwner(newId),
      toArea = Card.Processing,
      moveReason = params.response and fk.ReasonResponse or fk.ReasonJustMove,
      skillName = skillName,
    }
  end
  data.card = card

  self:sendLog{
    type = "#ChangedJudge",
    from = player.id,
    to = { data.who.id },
    arg2 = card,
    arg = skillName,
  }

  if newId and self:getCardArea(newId) == Card.Processing then
    data.card = self:filterCard(newId, data.who, true)
  end

  if oldId and self:getCardArea(oldId) == Card.Processing then
    local exchange = params.exchange and not player.dead
    self:moveCards{
      ids = { oldId },
      toArea = exchange and Card.PlayerHand or Card.DiscardPile,
      moveReason = exchange and fk.ReasonJustMove or fk.ReasonJudge,
      to = exchange and player or nil,
      skillName = skillName,
    }
  end

end

return { Judge, JudgeEventWrappers }
