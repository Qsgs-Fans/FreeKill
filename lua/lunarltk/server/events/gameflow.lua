-- SPDX-License-Identifier: GPL-3.0-or-later

local function drawInit(room, player, n, fix_ids)
  -- TODO: need a new function to call the UI
  local cardIds = table.random(room.draw_pile, n)
  if fix_ids then
    cardIds = table.random(fix_ids, n)
    if #cardIds < n then
      table.insertTable(cardIds, table.random(room.draw_pile, n - #cardIds))
    end
  end
  player:addCards(Player.Hand, cardIds)
  for _, id in ipairs(cardIds) do
    Fk:filterCard(id, player)
  end

  local move_to_notify = {   ---@type MoveCardsDataSpec
    moveInfo = {},
    to = player,
    toArea = Card.PlayerHand,
    moveReason = fk.ReasonDraw
  }
  for _, id in ipairs(cardIds) do
    table.insert(move_to_notify.moveInfo,
    { cardId = id, fromArea = room:getCardArea(id) })
  end
  room:notifyMoveCards(nil, {move_to_notify})

  for _, id in ipairs(cardIds) do
    table.removeOne(room.draw_pile, id)
    room:setCardArea(id, Card.PlayerHand, player.id)
  end
  room:syncDrawPile()
end

local function discardInit(room, player)
  local cardIds = player:getCardIds(Player.Hand)
  player:removeCards(Player.Hand, cardIds)

  local move_to_notify = { ---@type MoveCardsDataSpec
    moveInfo = {},
    from = player,
    toArea = Card.DrawPile,
    moveReason = fk.ReasonJustMove
  }
  local move_to_void_notify = { ---@type MoveCardsDataSpec
    moveInfo = {},
    from = player,
    toArea = Card.Void,
    moveReason = fk.ReasonJustMove
  }
  for _, id in ipairs(cardIds) do
    if id > 0 then
      table.insert(move_to_notify.moveInfo,
      { cardId = id, fromArea = Card.PlayerHand })
      table.insert(room.draw_pile, id)
    else
      table.insert(move_to_void_notify.moveInfo,
      { cardId = id, fromArea = Card.PlayerHand })
      table.insert(room.void, id)
    end
  end

  for _, id in ipairs(cardIds) do
    Fk:filterCard(id, nil)
  end

  local moves = {}
  if #move_to_notify.moveInfo > 0 then
    table.insert(moves, move_to_notify)
  end
  if #move_to_void_notify.moveInfo > 0 then
    table.insert(moves, move_to_void_notify)
  end
  room:notifyMoveCards(nil, moves)

  for _, id in ipairs(cardIds) do
    room:setCardArea(id, table.contains(room.draw_pile, id) and Card.DrawPile or Card.Void, nil)
  end
  room:syncDrawPile()
end

---@class GameEvent.DrawInitial : GameEvent
local DrawInitial = GameEvent:subclass("GameEvent.DrawInitial")

function DrawInitial:__tostring()
  return string.format("<DrawInitial : #%d>",
    self.id)
end

function DrawInitial:main()
  local room = self.room

  local luck_data = {
    drawInit = drawInit,
    discardInit = discardInit,
    playerList = table.map(room.alive_players, Util.IdMapper),
  }

  for _, player in ipairs(room.alive_players) do
    local draw_data = DrawInitialData:new{ num = 4 }
    room.logic:trigger(fk.DrawInitialCards, player, draw_data)
    luck_data[player.id] = draw_data
    luck_data[player.id].luckTime = room:getSettings('luckTime')
    if player.id < 0 then -- Robot
      luck_data[player.id].luckTime = 0
    end
    if draw_data.num > 0 then
      drawInit(room, player, draw_data.num, luck_data[player.id].fix_ids)
    end
  end

  if room:getSettings('luckTime') <= 0 then
    table.shuffle(room.draw_pile)
    for _, id in ipairs(room.draw_pile) do
      room:setCardArea(id, Card.DrawPile, nil)
    end
    room:syncDrawPile()
    for _, player in ipairs(room.alive_players) do
      local draw_data = luck_data[player.id]
      draw_data.luckTime = nil
      room.logic:trigger(fk.AfterDrawInitialCards, player, draw_data)
    end
    return
  end

  local request = Request:new(room.alive_players, "AskForSkillInvoke")
  for _, p in ipairs(room.alive_players) do
    request:setData(p, { "AskForLuckCard", "#AskForLuckCard:::" .. room:getSettings('luckTime') })
  end
  request.focus_text = "AskForLuckCard"
  request.luck_data = luck_data
  request.accept_cancel = true
  request:ask()

  table.shuffle(room.draw_pile)
  for _, id in ipairs(room.draw_pile) do
    room:setCardArea(id, Card.DrawPile, nil)
  end
  room:syncDrawPile()
  for _, player in ipairs(room.alive_players) do
    local draw_data = luck_data[player.id]
    draw_data.luckTime = nil
    room.logic:trigger(fk.AfterDrawInitialCards, player, draw_data)
  end
end

---@class GameEvent.Round : GameEvent
---@field public data RoundData
local Round = GameEvent:subclass("GameEvent.Round")

function Round:__tostring()
  return string.format("<Round : %d #%d>",
    Fk:currentRoom():getBanner("RoundCount"), self.id)
end

function Round:action()
  local room = self.room
  local data = self.data
  if data == nil then
    data = {}
  end

  while true do
    data.turn_table = data.turn_table or {}
    if #data.turn_table == 0 then
      data.turn_table = table.simpleClone(room.players)
    end

    data.to = data.turn_table[1]
    room.logic:trigger(fk.EventTurnChanging, data.to, data, true)
    room:setCurrent(data.to)

    if data.skipped then
      data.skipped = false
    else
      GameEvent.Turn:create(TurnData:new(room.current, "game_rule")):exec()
    end

    room:actExtraTurn()
    table.remove(data.turn_table, 1)
    data.from = data.to

    if #data.turn_table == 0 or room.game_finished then break end
  end
end

function Round:main()
  local room = self.room
  local logic = room.logic
  local data = self.data

  local roundCount = room:getBanner("RoundCount") or 0
  roundCount = roundCount + 1
  room:setBanner("RoundCount", roundCount)
  room:doBroadcastNotify("UpdateRoundNum", roundCount)
  -- 强行平局 防止can_trigger报错导致瞬间几十万轮卡炸服务器
  if roundCount >= 999 then
    room:sendLog{
      type = "#TimeOutDraw",
      toast = true,
    }
    room:gameOver("")
  end

  if roundCount == 1 then
    logic:trigger(fk.GameStart, room.current, data)
    room:actExtraTurn()
  end

  room:sendLog{ type = "$RoundStart", arg = roundCount }

  logic:trigger(fk.RoundStart, room.current, data)
  room:actExtraTurn()
  self:action()
  logic:trigger(fk.RoundEnd, room.current, data)
  room:actExtraTurn()
end

function Round:clear()
  local room = self.room

  room:clearHistory(Player.HistoryRound)
end

---@class GameEvent.Turn : GameEvent
---@field public data TurnData
local Turn = GameEvent:subclass("GameEvent.Turn")

function Turn:__tostring()
  local data = self.data
  return string.format("<Turn : %s by %s #%d>",
    data.who, data.reason, self.id)
end

function Turn:prepare()
  local room = self.room
  local logic = room.logic
  local data = self.data
  local player = data.who

  if player.rest > 0 and player.rest < 999 then
    room:setPlayerRest(player, player.rest - 1)
    if player.rest == 0 and player.dead then
      room:revivePlayer(player, true, "rest")
    else
      room:delay(50)
    end
  end

  if player.dead then return true end

  --room:sendLog{ type = "$AppendSeparator" }

  room:clearHistory(Player.HistoryTurn)

  logic:trigger(fk.PreTurnStart, player, data)
  if data.turn_end then return true end

  if not player.faceup then
    player:turnOver()
    return true
  end

  logic:trigger(fk.BeforeTurnStart, player, data)
  return data.turn_end
end

function Turn:main()
  local room = self.room
  local data = self.data
  local player = data.who
  local logic = room.logic

  if data.reason == "game_rule" then
    room:sendLog{ type = "$TurnStart", from = player.id }
  else
    room:sendLog{ type = "$ExtraTurnStart", from = player.id, arg = data.reason }
  end

  --标志正式进入回合，第一步先把phase设置为PhaseNone，以便于可用NotActive正确判定回合内外
  player.phase = Player.PhaseNone
  room:broadcastProperty(player, "phase")

  logic:trigger(fk.TurnStart, player, data)

  while #data.phase_table > data.phase_index do
    if player.dead or data.turn_end then return end
    data.phase_index = data.phase_index + 1
    local phase_data = data.phase_table[data.phase_index]

    GameEvent.Phase:create(phase_data):exec()
  end
end

function Turn:clear()
  local room = self.room
  local data = self.data
  local current = data.who

  local logic = room.logic

  current.phase = Player.PhaseNone
  room:broadcastProperty(current, "phase")

  logic:trigger(fk.TurnEnd, current, data, self.interrupted)

  current.phase = Player.NotActive
  room:broadcastProperty(current, "phase")

  if data.reason == "game_rule" then
    room:sendLog{ type = "$TurnEnd", from = current.id }
  else
    room:sendLog{ type = "$ExtraTurnEnd", from = current.id, arg = data.reason }
  end

  room:clearHistory(Player.HistoryTurn)
end

---@class GameEvent.Phase : GameEvent
---@field public data PhaseData
local Phase = GameEvent:subclass("GameEvent.Phase")

function Phase:__tostring()
  local data = self.data
  return string.format("<Phase %s: %s by %s #%d>",
    Util.PhaseStrMapper(data.phase), data.who, data.reason, self.id)
end

function Phase:prepare()
  local room = self.room
  local logic = room.logic
  local data = self.data
  local player = data.who

  if data.reason ~= "game_rule" then
    room:sendLog{
      type = "#GainAnExtraPhase",
      from = player.id,
      arg = Util.PhaseStrMapper(data.phase),
    }
  end

  if not data.skipped then
    logic:trigger(fk.EventPhaseChanging, player, data)
  end

  if data.skipped then
    logic:trigger(fk.EventPhaseSkipping, player, data)
  end

  if data.skipped then
    room:sendLog{
      type = "#PhaseSkipped",
      from = player.id,
      arg = Util.PhaseStrMapper(data.phase),
    }
    logic:trigger(fk.EventPhaseSkipped, player, data)
    return true
  end
end

function Phase:main()
  local room = self.room
  local logic = room.logic
  local data = self.data
  local player = data.who

  player.phase = data.phase
  room:broadcastProperty(player, "phase")

  logic:trigger(fk.EventPhaseStart, player, data)
  if data.phase_end then return end

  logic:trigger(fk.EventPhaseProceeding, player, data)
  if data.phase_end then return end

  switch(player.phase, {
    [Player.PhaseNone] = function()
      error("You should never proceed PhaseNone")
    end,
    [Player.NotActive] = function()
      error("You should never proceed NotActive")
    end,
    [Player.RoundStart] = function()

    end,
    [Player.Start] = function()

    end,
    [Player.Judge] = function()
      local cards = player:getCardIds(Player.Judge)
      while #cards > 0 do
        if data.phase_end then break end
        local cid = table.remove(cards)
        if not cid then return end
        local card = player:getVirtualEquip(cid)
        if not card then
          card = Fk:getCardById(cid)
        end
        if table.contains(player:getCardIds(Player.Judge), cid) and card.skill and card.skill.name ~= "default_card_skill" then
          room:moveCardTo(card, Card.Processing, nil, fk.ReasonPut, "phase_judge")
          if card:isVirtual() then
            room:sendCardVirtName({cid}, card.name)
          end

          local effect_data = CardEffectData:new {
            card = card,
            to = player,
            tos = { player },
          }
          room:doCardEffect(effect_data)
          if effect_data.isCancellOut then
            card.skill:onNullified(room, effect_data)
          end
        end
      end
    end,
    [Player.Draw] = function()
      data.n = 2 -- FIXME: 等待阶段拆分
      room.logic:trigger(fk.DrawNCards, player, data)
      if data.n > 0 then
        room:drawCards(player, data.n, "phase_draw")
      end
      room.logic:trigger(fk.AfterDrawNCards, player, data)
    end,
    [Player.Play] = function()
      room:doBroadcastNotify("UpdateSkill", "", {player})
      while not player.dead do
        if data.phase_end then break end

        logic:trigger(fk.BeforePlayCard, player, data)
        if data.phase_end then break end

        local dat = { timeout = room:getBanner("Timeout") and room:getBanner("Timeout")[tostring(player.id)] or room.timeout }
        logic:trigger(fk.StartPlayCard, player, dat, true)

        local req = Request:new(player, "PlayCard")
        req.timeout = dat.timeout
        local result = req:getResult(player)
        if result == "" then break end

        local useResult = room:handleUseCardReply(player, result)
        if type(useResult) == "table" then
          room:useCard(useResult)
        end
      end
    end,
    [Player.Discard] = function()
      local discardNum = #table.filter(
        player:getCardIds(Player.Hand), function(id)
          local card = Fk:getCardById(id)
          return table.every(room.status_skills[MaxCardsSkill] or Util.DummyTable, function(skill)
            return not skill:excludeFrom(player, card)
          end)
        end
      ) - player:getMaxCards()
      room:broadcastProperty(player, "MaxCards")
      if discardNum > 0 then
        room:askToDiscard(player, {min_num = discardNum, max_num = discardNum, include_equip = false, skill_name = "phase_discard", cancelable = false})
      end
    end,
    [Player.Finish] = function()

    end,
  })


end

function Phase:clear()
  local room = self.room
  local logic = room.logic
  local data = self.data
  local player = data.who

  logic:trigger(fk.EventPhaseEnd, player, data, self.interrupted)

  player.phase = (room.current == player and Player.PhaseNone or Player.NotActive)
  room:broadcastProperty(player, "phase")

  room:clearHistory(Player.HistoryPhase)
end

return { DrawInitial, Round, Turn, Phase }
