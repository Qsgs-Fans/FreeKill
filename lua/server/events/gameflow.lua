-- SPDX-License-Identifier: GPL-3.0-or-later

local function drawInit(room, player, n)
  -- TODO: need a new function to call the UI
  local cardIds = room:getNCards(n)
  player:addCards(Player.Hand, cardIds)
  for _, id in ipairs(cardIds) do
    Fk:filterCard(id, player)
  end
  local move_to_notify = {}   ---@type CardsMoveStruct
  move_to_notify.toArea = Card.PlayerHand
  move_to_notify.to = player.id
  move_to_notify.moveInfo = {}
  move_to_notify.moveReason = fk.ReasonDraw
  for _, id in ipairs(cardIds) do
    table.insert(move_to_notify.moveInfo,
    { cardId = id, fromArea = Card.DrawPile })
  end
  room:notifyMoveCards(nil, {move_to_notify})

  for _, id in ipairs(cardIds) do
    room:setCardArea(id, Card.PlayerHand, player.id)
  end
end

local function discardInit(room, player)
  local cardIds = player:getCardIds(Player.Hand)
  player:removeCards(Player.Hand, cardIds)
  table.insertTable(room.draw_pile, cardIds)
  for _, id in ipairs(cardIds) do
    Fk:filterCard(id, nil)
  end

  local move_to_notify = {}   ---@type CardsMoveStruct
  move_to_notify.from = player.id
  move_to_notify.toArea = Card.DrawPile
  move_to_notify.moveInfo = {}
  move_to_notify.moveReason = fk.ReasonJustMove
  for _, id in ipairs(cardIds) do
    table.insert(move_to_notify.moveInfo,
    { cardId = id, fromArea = Card.PlayerHand })
  end
  room:notifyMoveCards(nil, {move_to_notify})

  for _, id in ipairs(cardIds) do
    room:setCardArea(id, Card.DrawPile, nil)
  end
end

GameEvent.functions[GameEvent.DrawInitial] = function(self)
  local room = self.room

  local luck_data = {
    drawInit = drawInit,
    discardInit = discardInit,
    playerList = table.map(room.alive_players, Util.IdMapper),
  }

  for _, player in ipairs(room.alive_players) do
    local draw_data = { num = 4 }
    room.logic:trigger(fk.DrawInitialCards, player, draw_data)
    luck_data[player.id] = draw_data
    luck_data[player.id].luckTime = room.settings.luckTime
    if player.id < 0 then -- Robot
      luck_data[player.id].luckTime = 0
    end
    if draw_data.num > 0 then
      drawInit(room, player, draw_data.num)
    end
  end

  if room.settings.luckTime <= 0 then
    for _, player in ipairs(room.alive_players) do
      local draw_data = luck_data[player.id]
      draw_data.luckTime = nil
      room.logic:trigger(fk.AfterDrawInitialCards, player, draw_data)
    end
    return
  end

  room:setTag("LuckCardData", luck_data)
  room:notifyMoveFocus(room.alive_players, "AskForLuckCard")
  room:doBroadcastNotify("AskForLuckCard", room.settings.luckTime or 4)

  local remainTime = room.timeout + 1
  local currentTime = os.time()
  local elapsed = 0

  for _, id in ipairs(luck_data.playerList) do
    local pl = room:getPlayerById(id)
    if luck_data[id].luckTime > 0 then
      pl.serverplayer:setThinking(true)
    end
  end

  while true do
    elapsed = os.time() - currentTime
    if remainTime - elapsed <= 0 then
      break
    end

    -- local ldata = room:getTag("LuckCardData")
    local ldata = luck_data

    if table.every(ldata.playerList, function(id)
      return ldata[id].luckTime == 0
    end) then
      break
    end

    for _, id in ipairs(ldata.playerList) do
      local pl = room:getPlayerById(id)
      if pl._splayer:getState() ~= fk.Player_Online then
        ldata[id].luckTime = 0
        pl.serverplayer:setThinking(false)
      end
    end

    -- room:setTag("LuckCardData", ldata)

    room:checkNoHuman()

    coroutine.yield("__handleRequest", (remainTime - elapsed) * 1000)
  end

  for _, player in ipairs(room.alive_players) do
    local draw_data = luck_data[player.id]
    draw_data.luckTime = nil
    room.logic:trigger(fk.AfterDrawInitialCards, player, draw_data)
  end

  room:removeTag("LuckCardData")
end

GameEvent.functions[GameEvent.Round] = function(self)
  local room = self.room
  local logic = room.logic
  local p

  local isFirstRound = room:getTag("FirstRound")
  if isFirstRound then
    room:setTag("FirstRound", false)
  end
  room:setTag("RoundCount", room:getTag("RoundCount") + 1)
  room:doBroadcastNotify("UpdateRoundNum", room:getTag("RoundCount"))

  if isFirstRound then
    logic:trigger(fk.GameStart, room.current)
  end

  logic:trigger(fk.RoundStart, room.current)

  repeat
    p = room.current
    GameEvent(GameEvent.Turn, p):exec()
    if room.game_finished then break end
    room.current = room.current:getNextAlive(true)
  until p.seat >= p:getNextAlive(true).seat

  logic:trigger(fk.RoundEnd, p)
end

GameEvent.cleaners[GameEvent.Round] = function(self)
  local room = self.room

  for _, p in ipairs(room.players) do
    p:setCardUseHistory("", 0, Player.HistoryRound)
    p:setSkillUseHistory("", 0, Player.HistoryRound)
    for name, _ in pairs(p.mark) do
      if name:endsWith("-round") then
        room:setPlayerMark(p, name, 0)
      end
    end
  end

  for cid, cmark in pairs(room.card_marks) do
    for name, _ in pairs(cmark) do
      if name:endsWith("-round") then
        room:setCardMark(Fk:getCardById(cid), name, 0)
      end
    end
  end
end

GameEvent.prepare_funcs[GameEvent.Turn] = function(self)
  local room = self.room
  local logic = room.logic
  local player = room.current

  if player.dead then return true end

  room:sendLog{ type = "$AppendSeparator" }

  if not player.faceup then
    player:turnOver()
    return true
  end

  return logic:trigger(fk.BeforeTurnStart, player)
end

GameEvent.functions[GameEvent.Turn] = function(self)
  local room = self.room
  local logic = room.logic

  logic:trigger(fk.TurnStart, room.current)
  room.current:play()
end

GameEvent.cleaners[GameEvent.Turn] = function(self)
  local room = self.room

  local current = room.current
  local logic = room.logic
  if self.interrupted then
    if current.phase ~= Player.NotActive then
      local current_phase = current.phase
      current.phase = Player.PhaseNone
      logic:trigger(fk.EventPhaseChanging, current,
        { from = current_phase, to = Player.NotActive }, true)
      current.phase = Player.NotActive
      room:broadcastProperty(current, "phase")
      logic:trigger(fk.EventPhaseStart, current, nil, true)
    end

    current.skipped_phases = {}
  end

  logic:trigger(fk.TurnEnd, current, nil, self.interrupted)
  logic:trigger(fk.AfterTurnEnd, current, nil, self.interrupted)

  for _, p in ipairs(room.players) do
    p:setCardUseHistory("", 0, Player.HistoryTurn)
    p:setSkillUseHistory("", 0, Player.HistoryTurn)
    for name, _ in pairs(p.mark) do
      if name:endsWith("-turn") then
        room:setPlayerMark(p, name, 0)
      end
    end
  end

  for cid, cmark in pairs(room.card_marks) do
    for name, _ in pairs(cmark) do
      if name:endsWith("-turn") then
        room:setCardMark(Fk:getCardById(cid), name, 0)
      end
    end
  end
end

GameEvent.functions[GameEvent.Phase] = function(self)
  local room = self.room
  local logic = room.logic

  local player = self.data[1]
  if not logic:trigger(fk.EventPhaseStart, player) then
    if player.phase ~= Player.NotActive then
      logic:trigger(fk.EventPhaseProceeding, player)

      switch(player.phase, {
      [Player.PhaseNone] = function()
        error("You should never proceed PhaseNone")
      end,
      [Player.RoundStart] = function()

      end,
      [Player.Start] = function()

      end,
      [Player.Judge] = function()
        local cards = player:getCardIds(Player.Judge)
        for i = #cards, 1, -1 do
          local card
          card = player:removeVirtualEquip(cards[i])
          if not card then
            card = Fk:getCardById(cards[i])
          end
          room:moveCardTo(card, Card.Processing, nil, fk.ReasonPut, self.name)

          ---@type CardEffectEvent
          local effect_data = {
            card = card,
            to = player.id,
            tos = { {player.id} },
          }
          room:doCardEffect(effect_data)
          if effect_data.isCancellOut and card.skill then
            card.skill:onNullified(room, effect_data)
          end
        end
      end,
      [Player.Draw] = function()
        local data = {
          n = 2
        }
        room.logic:trigger(fk.DrawNCards, player, data)
        room:drawCards(player, data.n, self.name)
        room.logic:trigger(fk.AfterDrawNCards, player, data)
      end,
      [Player.Play] = function()
        player._play_phase_end = false
        while not player.dead do
          room:notifyMoveFocus(player, "PlayCard")
          local result = room:doRequest(player, "PlayCard", player.id)
          if result == "" then break end

          local use = room:handleUseCardReply(player, result)
          if use then
            room:useCard(use)
          end

          if player._play_phase_end then
            player._play_phase_end = false
            break
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
        if discardNum > 0 then
          room:askForDiscard(player, discardNum, discardNum, false, "game_rule", false)
        end
      end,
      [Player.Finish] = function()

      end,
      })
    end
  end
end

GameEvent.cleaners[GameEvent.Phase] = function(self)
  local room = self.room
  local player = self.data[1]
  local logic = room.logic

  if player.phase ~= Player.NotActive then
    logic:trigger(fk.EventPhaseEnd, player, nil, self.interrupted)
    logic:trigger(fk.AfterPhaseEnd, player, nil, self.interrupted)
  else
    player.skipped_phases = {}
  end

  for _, p in ipairs(room.players) do
    p:setCardUseHistory("", 0, Player.HistoryPhase)
    p:setSkillUseHistory("", 0, Player.HistoryPhase)
    for name, _ in pairs(p.mark) do
      if name:endsWith("-phase") then
        room:setPlayerMark(p, name, 0)
      end
    end
  end

  for cid, cmark in pairs(room.card_marks) do
    for name, _ in pairs(cmark) do
      if name:endsWith("-phase") then
        room:setCardMark(Fk:getCardById(cid), name, 0)
      end
    end
  end
end
