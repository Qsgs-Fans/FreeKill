-- SPDX-License-Identifier: GPL-3.0-or-later

GameEvent.functions[GameEvent.DrawInitial] = function(self)
  local room = self.room
  for _, player in ipairs(room.alive_players) do
    local draw_data = { num = 4 }
    room.logic:trigger(fk.DrawInitialCards, player, draw_data)
    if draw_data.num > 0 then
      -- TODO: need a new function to call the UI
      local cardIds = room:getNCards(draw_data.num)
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

      room.logic:trigger(fk.AfterDrawInitialCards, player, data)
    end
  end
end

GameEvent.functions[GameEvent.Round] = function(self)
  local room = self.room
  local logic = room.logic
  local p

  if room:getTag("FirstRound") then
    room:setTag("FirstRound", false)
  end
  room:setTag("RoundCount", room:getTag("RoundCount") + 1)
  room:doBroadcastNotify("UpdateRoundNum", room:getTag("RoundCount"))

  logic:trigger(fk.RoundStart, room.current)

  repeat
    p = room.current
    GameEvent(GameEvent.Turn):exec()
    if room.game_finished then break end
    room.current = room.current:getNextAlive()
  until p.seat > p:getNextAlive().seat

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
end

GameEvent.functions[GameEvent.Turn] = function(self)
  local room = self.room
  room.logic:trigger(fk.TurnStart, room.current)

  room:sendLog{ type = "$AppendSeparator" }

  local player = room.current
  if not player.faceup then
    player:turnOver()
  elseif not player.dead then
    player:play()
  end

  room.logic:trigger(fk.TurnEnd, room.current)
end

GameEvent.cleaners[GameEvent.Turn] = function(self)
  local room = self.room

  for _, p in ipairs(room.players) do
    p:setCardUseHistory("", 0, Player.HistoryTurn)
    p:setSkillUseHistory("", 0, Player.HistoryTurn)
    for name, _ in pairs(p.mark) do
      if name:endsWith("-turn") then
        room:setPlayerMark(p, name, 0)
      end
    end
  end

  if self.interrupted then
    room.current.phase = Player.Finish
    room.logic:trigger(fk.EventPhaseStart, room.current, nil, true)
    room.logic:trigger(fk.EventPhaseEnd, room.current, nil, true)

    room.current.phase = Player.NotActive
    room:notifyProperty(room.current, room.current, "phase")
    room.logic:trigger(fk.EventPhaseStart, room.current, nil, true)

    room.current.skipped_phases = {}

    room.logic:trigger(fk.TurnEnd, room.current, nil, true)
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
        while not player.dead do
          room:notifyMoveFocus(player, "PlayCard")
          local result = room:doRequest(player, "PlayCard", player.id)
          if result == "" then break end

          local use = room:handleUseCardReply(player, result)
          if use then
            room:useCard(use)
          end
        end
      end,
      [Player.Discard] = function()
        local discardNum = #player:getCardIds(Player.Hand) - player:getMaxCards()
        if discardNum > 0 then
          room:askForDiscard(player, discardNum, discardNum, false, self.name)
        end
      end,
      [Player.Finish] = function()

      end,
      [Player.NotActive] = function()

      end,
      })
    end
  end

  if self.phase ~= Player.NotActive then
    logic:trigger(fk.EventPhaseEnd, self)
  else
    self.skipped_phases = {}
  end
end

GameEvent.cleaners[GameEvent.Phase] = function(self)
  local room = self.room
  local player = self.data[1]

  for _, p in ipairs(room.players) do
    p:setCardUseHistory("", 0, Player.HistoryPhase)
    p:setSkillUseHistory("", 0, Player.HistoryPhase)
    for name, _ in pairs(p.mark) do
      if name:endsWith("-phase") then
        room:setPlayerMark(p, name, 0)
      end
    end
  end

  if self.interrupted then
    room.logic:trigger(fk.EventPhaseEnd, player, nil, true)
  end
end
