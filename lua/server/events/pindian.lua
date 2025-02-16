-- SPDX-License-Identifier: GPL-3.0-or-later

---@class PindianEventWrappers: Object
local PindianEventWrappers = {} -- mixin

---@return boolean
local function exec(tp, ...)
  local event = tp:create(...)
  local _, ret = event:exec()
  return ret
end

---@class GameEvent.Pindian : GameEvent
---@field public data PindianData
local Pindian = GameEvent:subclass("GameEvent.Pindian")
function Pindian:main()
  local pindianData = self.data
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
  local data = { "choose_cards_skill", prompt, false, extraData }

  local targets = {}
  local moveInfos = {}
  if not pindianData.fromCard then
    table.insert(targets, pindianData.from)
  else
    if not pindianData._fromCard then
      local _pindianCard = pindianData.fromCard
      local pindianCard = _pindianCard:clone(_pindianCard.suit, _pindianCard.number)
      pindianCard:addSubcard(_pindianCard.id)

      pindianData.fromCard = pindianCard
      pindianData._fromCard = _pindianCard
    end

    table.insert(moveInfos, {
      ids = { pindianData._fromCard.id },
      from = room.owner_map[pindianData._fromCard.id],
      fromArea = room:getCardArea(pindianData._fromCard.id),
      toArea = Card.Processing,
      moveReason = fk.ReasonPut,
      skillName = pindianData.reason,
      moveVisible = true,
    })
  end
  for _, to in ipairs(pindianData.tos) do
    if pindianData.results[to] and pindianData.results[to].toCard then
      if not pindianData.results[to]._toCard then
        local _pindianCard = pindianData.results[to].toCard
        local pindianCard = _pindianCard:clone(_pindianCard.suit, _pindianCard.number)
        pindianCard:addSubcard(_pindianCard.id)

        pindianData.results[to].toCard = pindianCard
        pindianData.results[to]._toCard = _pindianCard
      end

      table.insert(moveInfos, {
        ids = { pindianData.results[to]._toCard.id },
        from = room.owner_map[pindianData.results[to]._toCard.id],
        fromArea = room:getCardArea(pindianData.results[to]._toCard.id),
        toArea = Card.Processing,
        moveReason = fk.ReasonPut,
        skillName = pindianData.reason,
        moveVisible = true,
      })
    else
      table.insert(targets, to)
    end
  end

  if #targets ~= 0 then
    local req = Request:new(targets, "AskForUseActiveSkill")
    for _, p in ipairs(targets) do
      req:setData(p, data)
      req:setDefaultReply(p, p:getCardIds(Player.Hand)[1])
    end
    req.focus_text = "AskForPindian"

    for _, p in ipairs(targets) do
      local _pindianCard
      local result = req:getResult(p)
      if type(result) == "table" then
        _pindianCard = Fk:getCardById(result.card.subcards[1])
      else
        _pindianCard = Fk:getCardById(result)
      end

      local pindianCard = _pindianCard:clone(_pindianCard.suit, _pindianCard.number)
      pindianCard:addSubcard(_pindianCard.id)

      if p == pindianData.from then
        pindianData.fromCard = pindianCard
        pindianData._fromCard = _pindianCard
      else
        pindianData.results[p.id] = pindianData.results[p.id] or {}
        pindianData.results[p.id].toCard = pindianCard
        pindianData.results[p.id]._toCard = _pindianCard
      end

      table.insert(moveInfos, {
        ids = { _pindianCard.id },
        from = p,
        toArea = Card.Processing,
        moveReason = fk.ReasonPut,
        skillName = pindianData.reason,
        moveVisible = true,
      })

      room:sendLog{
        type = "#ShowPindianCard",
        from = p.id,
        arg = _pindianCard:toLogString(),
      }
    end
  end

  room:moveCards(table.unpack(moveInfos))

  room:sendFootnote({ pindianData._fromCard.id }, {
    type = "##PindianCard",
    from = pindianData.from.id,
  })
  for _, to in ipairs(pindianData.tos) do
    room:sendFootnote({ pindianData.results[to]._toCard.id }, {
      type = "##PindianCard",
      from = to.id,
    })
  end

  logic:trigger(fk.PindianCardsDisplayed, nil, pindianData)

  for _, to in ipairs(pindianData.tos) do
    local result = pindianData.results[to]
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
      to = { to.id },
      arg = result.winner == pindianData.from and "pindianwin" or "pindiannotwin"
    }

    -- room:setCardEmotion(pindianData._fromCard.id, result.winner == pindianData.from and "pindianwin" or "pindiannotwin")
    -- room:setCardEmotion(pindianData.results[to.id]._toCard.id, result.winner == to and "pindianwin" or "pindiannotwin")

    logic:trigger(fk.PindianResultConfirmed, nil, singlePindianData)
  end

  if logic:trigger(fk.PindianFinished, pindianData.from, pindianData) then
    logic:breakEvent()
  end
end

function Pindian:clear()
  local pindianData = self.data
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


--- 根据拼点信息开始拼点。
---@param pindianData PindianDataSpec
function PindianEventWrappers:pindian(pindianData)
  return exec(Pindian, PindianData:new(pindianData))
end

--- 加减拼点牌点数（最小为1，最大为13）。
---@param pindianData PindianStruct
---@param player ServerPlayer @ 拼点角色
---@param number integer @ 加减的点数
---@param skill_name string @ 技能名
function PindianEventWrappers:changePindianNumber(pindianData, player, number, skill_name)
  local orig_num, new_num
  if player == pindianData.from then
    orig_num = pindianData.fromCard.number
    new_num = math.max(1, math.min(13, orig_num + number))
    pindianData.fromCard.number = new_num
  elseif pindianData.results[player.id] then
    orig_num = pindianData.results[player.id].toCard.number
    new_num = math.max(1, math.min(13, orig_num + number))
    pindianData.results[player.id].toCard.number = new_num
  end
  self:sendLog{
    type = "#ChangePindianNumber",
    to = { player.id },
    arg = skill_name,
    arg2 = orig_num,
    arg3 = new_num,
    toast = true,
  }
end

return { Pindian, PindianEventWrappers }
