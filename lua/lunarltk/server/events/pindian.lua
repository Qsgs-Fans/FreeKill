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

function Pindian:__tostring()
  local data = self.data
  return string.format("<Pindian %s: %s => [%s] #%d>",
    data.reason, data.from, table.concat(
      table.map(data.tos or {}, ServerPlayer.__tostring), ", "), self.id)
end

function Pindian:main()
  local pindianData = self.data
  local room = self.room
  local logic = room.logic
  local from = pindianData.from
  local results = pindianData.results
  for _, to in pairs(pindianData.tos) do
    results[to] = results[to] or {}
  end

  logic:trigger(fk.StartPindian, from, pindianData)

  if pindianData.reason ~= "" then
    room:sendLog{
      type = "#StartPindianReason",
      from = from.id,
      arg = pindianData.reason,
    }
  end

  -- 将拼点牌变为虚拟牌
  ---@param card Card
  local virtualize = function (card)
    local _card = card:clone(card.suit, card.number)
    if card:getEffectiveId() then
      _card.subcards = { card:getEffectiveId() }
    end
    return _card
  end

  ---@type ServerPlayer[]
  local targets = {}
  local moveInfos = {} ---@type MoveInfo[]
  if pindianData.fromCard then
    pindianData.fromCard = virtualize(pindianData.fromCard)
    local cid = pindianData.fromCard:getEffectiveId()
    if cid and room:getCardArea(cid) ~= Card.Processing and
      not table.find(moveInfos, function (info)
        return table.contains(info.ids, cid)
      end) then
      table.insert(moveInfos, {
        ids = { cid },
        from = room:getCardOwner(cid),
        toArea = Card.Processing,
        moveReason = fk.ReasonPindian,
        skillName = pindianData.reason,
        moveVisible = true,
      })
    end
  elseif not from:isKongcheng() then
    table.insert(targets, from)
  end
  for _, to in ipairs(pindianData.tos) do
    if results[to] and results[to].toCard then
      results[to].toCard = virtualize(results[to].toCard)

      local cid = results[to].toCard:getEffectiveId()
      if cid and room:getCardArea(cid) ~= Card.Processing and
        not table.find(moveInfos, function (info)
          return table.contains(info.ids, cid)
        end) then
        table.insert(moveInfos, {
          ids = { cid },
          from = room:getCardOwner(cid),
          toArea = Card.Processing,
          moveReason = fk.ReasonPindian,
          skillName = pindianData.reason,
          moveVisible = true,
        })
      end
    elseif not to:isKongcheng() then
      table.insert(targets, to)
    end
  end

  if #targets ~= 0 then
    local extraData = {
      num = 1,
      min_num = 1,
      include_equip = false,
      pattern = ".",
      reason = pindianData.reason,
    }
    local prompt = "#askForPindian:::" .. pindianData.reason
    local req_data = { "choose_cards_skill", prompt, false, extraData }

    local req = Request:new(targets, "AskForUseActiveSkill")
    for _, to in ipairs(targets) do
      if pindianData.expandCards and pindianData.expandCards[to] then
        req_data[4] = pindianData.expandCards[to]
      end
      req:setData(to, req_data)
      req:setDefaultReply(to, {card = {subcards = {to:getCardIds(Player.Hand)[1]}}})
    end
    req.focus_text = "AskForPindian"

    for _, to in ipairs(targets) do
      local result = req:getResult(to)
      local card = Fk:getCardById(result.card.subcards[1])

      card = virtualize(card)

      if to == from then
        pindianData.fromCard = card
      else
        pindianData.results[to].toCard = card
      end

      if not table.find(moveInfos, function (info)
        return table.contains(info.ids, card:getEffectiveId())
      end) then
        table.insert(moveInfos, {
          ids = { card:getEffectiveId() },
          from = to,
          toArea = Card.Processing,
          moveReason = fk.ReasonPindian,
          skillName = pindianData.reason,
          moveVisible = true,
        })
      end

    end
  end

  if #moveInfos > 0 then
    room:moveCards(table.unpack(moveInfos))
  end

  room:sendLog{
    type = "#ShowPindianCard",
    from = from.id,
    arg = pindianData.fromCard:toLogString(),
  }
  for _, to in ipairs(pindianData.tos) do
    room:sendLog{
      type = "#ShowPindianCard",
      from = to.id,
      arg = pindianData.results[to].toCard:toLogString(),
    }
  end

  local cid = pindianData.fromCard:getEffectiveId()
  if cid then
    room:sendFootnote({ cid }, {
      type = "##PindianCard",
      from = from.id,
    })
  end
  for _, to in ipairs(pindianData.tos) do
    cid = pindianData.results[to].toCard:getEffectiveId()
    if cid then
      room:sendFootnote({ cid }, {
        type = "##PindianCard",
        from = to.id,
      })
    end
  end

  logic:trigger(fk.PindianCardsDisplayed, nil, pindianData)

  for _, to in ipairs(pindianData.tos) do
    local result = pindianData.results[to]
    local fromCard, toCard = pindianData.fromCard, result.toCard
    if fromCard and toCard then
      if fromCard.number > toCard.number then
        result.winner = from
      elseif fromCard.number < toCard.number then
        result.winner = to
      end

      local singlePindianData = {
        from = from,
        to = to,
        fromCard = pindianData.fromCard,
        toCard = result.toCard,
        winner = result.winner,
        reason = pindianData.reason,
      }

      room:sendLog{
        type = "#ShowPindianResult",
        from = from.id,
        to = { to.id },
        arg = result.winner == from and "pindianwin" or "pindiannotwin"
      }

      -- room:setCardEmotion(pindianData._fromCard.id, result.winner == from and "pindianwin" or "pindiannotwin")
      -- room:setCardEmotion(pindianData.results[to]._toCard.id, result.winner == to and "pindianwin" or "pindiannotwin")

      logic:trigger(fk.PindianResultConfirmed, nil, singlePindianData)
    end
  end

  if logic:trigger(fk.PindianFinished, from, pindianData) then
    logic:breakEvent()
  end
end

function Pindian:clear()
  local data = self.data
  local room = self.room

  local toThrow = {}
  local cid = data.fromCard and data.fromCard:getEffectiveId()
  if cid and room:getCardArea(cid) == Card.Processing then
    table.insertIfNeed(toThrow, cid)
  end

  for _, result in pairs(data.results) do
    cid = result.toCard and result.toCard:getEffectiveId()
    if cid and room:getCardArea(cid) == Card.Processing then
      table.insertIfNeed(toThrow, cid)
    end
  end

  if #toThrow > 0 then
    room:moveCards({
      ids = toThrow,
      toArea = Card.DiscardPile,
      moveReason = fk.ReasonPindian,
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
---@param pindianData PindianData
---@param player ServerPlayer @ 拼点角色
---@param number integer @ 加减的点数
---@param skill_name string @ 技能名
function PindianEventWrappers:changePindianNumber(pindianData, player, number, skill_name)
  ---@cast self Room
  local orig_num, new_num
  if player == pindianData.from then
    orig_num = pindianData.fromCard.number
    new_num = math.max(1, math.min(13, orig_num + number))
    pindianData.fromCard.number = new_num
  elseif pindianData.results[player] then
    orig_num = pindianData.results[player].toCard.number
    new_num = math.max(1, math.min(13, orig_num + number))
    pindianData.results[player].toCard.number = new_num
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
