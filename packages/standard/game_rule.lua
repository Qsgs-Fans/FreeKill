-- SPDX-License-Identifier: GPL-3.0-or-later

---@param victim ServerPlayer
local function getWinner(victim)
  local room = victim.room
  local winner = ""
  local alive = room.alive_players

  if victim.role == "lord" then
    if #alive == 1 and alive[1].role == "renegade" then
      winner = "renegade"
    else
      winner = "rebel"
    end
  elseif victim.role ~= "loyalist" then
    local lord_win = true
    for _, p in ipairs(alive) do
      if p.role == "rebel" or p.role == "renegade" then
        lord_win = false
        break
      end
    end
    if lord_win then
      winner = "lord+loyalist"
    end
  end

  return winner
end

---@param killer ServerPlayer
local function rewardAndPunish(killer, victim)
  if killer.dead then return end
  if victim.role == "rebel" then
    killer:drawCards(3, "kill")
  elseif victim.role == "loyalist" and killer.role == "lord" then
    killer:throwAllCards("he")
  end
end

GameRule = fk.CreateTriggerSkill{
  name = "game_rule",
  events = {
    fk.GameStart, fk.DrawInitialCards, fk.TurnStart,
    fk.EventPhaseProceeding, fk.EventPhaseEnd, fk.EventPhaseChanging,
    fk.RoundStart,
    fk.AskForPeaches, fk.AskForPeachesDone,
    fk.GameOverJudge, fk.BuryVictim,
  },
  priority = 0,

  can_trigger = function(self, event, target, player, data)
    return (target == player) or (target == nil)
  end,

  on_trigger = function(self, event, target, player, data)
    local room = player.room
    if room:getTag("SkipGameRule") then
      room:setTag("SkipGameRule", false)
      return false
    end

    if event == fk.GameStart then
      room:setTag("FirstRound", true)
      room:setTag("RoundCount", 0)
      return false
    end

    switch(event, {
    [fk.DrawInitialCards] = function()
      if data.num > 0 then
        -- TODO: need a new function to call the UI
        local cardIds = room:getNCards(data.num)
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
    end,
    [fk.RoundStart] = function()
      if room:getTag("FirstRound") then
        room:setTag("FirstRound", false)
      end

      room:setTag("RoundCount", room:getTag("RoundCount") + 1)
      room:doBroadcastNotify("UpdateRoundNum", room:getTag("RoundCount"))

      for _, p in ipairs(room.players) do
        p:setCardUseHistory("", 0, Player.HistoryRound)
        p:setSkillUseHistory("", 0, Player.HistoryRound)
        for name, _ in pairs(p.mark) do
          if name:endsWith("-round") then
            room:setPlayerMark(p, name, 0)
          end
        end
      end

      room:sendLog{ type = "$AppendSeparator" }
    end,
    [fk.TurnStart] = function()
      if not player.faceup then
        player:turnOver()
      elseif not player.dead then
        player:play()
      end
    end,
    [fk.EventPhaseProceeding] = function()
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
    end,
    [fk.EventPhaseEnd] = function()
      if player.phase == Player.Play then
        for _, p in ipairs(room.players) do
          p:setCardUseHistory("", 0, Player.HistoryPhase)
          p:setSkillUseHistory("", 0, Player.HistoryPhase)
          for name, _ in pairs(p.mark) do
            if name:endsWith("-phase") then
              room:setPlayerMark(p, name, 0)
            end
          end
        end
      end
    end,
    [fk.EventPhaseChanging] = function()
      -- TODO: copy but dont copy all
      if data.to == Player.NotActive then
        for _, p in ipairs(room.players) do
          p:setCardUseHistory("", 0, Player.HistoryTurn)
          p:setSkillUseHistory("", 0, Player.HistoryTurn)
          for name, _ in pairs(p.mark) do
            if name:endsWith("-turn") then
              room:setPlayerMark(p, name, 0)
            end
          end
        end
      end
    end,
    [fk.AskForPeaches] = function()
      local dyingPlayer = room:getPlayerById(data.who)
      while dyingPlayer.hp < 1 do
        local pattern = "peach"
        if player == dyingPlayer then
          pattern = pattern .. ",analeptic"
        end

        local peach_use = room:askForUseCard(player, "peach", pattern)
        if not peach_use then break end
        peach_use.tos = { {dyingPlayer.id} }
        if peach_use.card.trueName == "analeptic" then
          peach_use.extra_data = peach_use.extra_data or {}
          peach_use.extra_data.analepticRecover = true
        end
        room:useCard(peach_use)
      end
    end,
    [fk.AskForPeachesDone] = function()
      if player.hp < 1 and not data.ignoreDeath then
        ---@type DeathStruct
        local deathData = {
          who = player.id,
          damage = data.damage,
        }
        room:killPlayer(deathData)
      end
    end,
    [fk.GameOverJudge] = function()
      local winner = getWinner(player)
      if winner ~= "" then
        room:gameOver(winner)
        return true
      end
    end,
    [fk.BuryVictim] = function()
      player:bury()
      if room.tag["SkipNormalDeathProcess"] then
        return false
      end
      local damage = data.damage
      if damage and damage.from then
        local killer = damage.from
        rewardAndPunish(killer, player);
      end
    end,
    default = function()
      print("game_rule: Event=" .. event)
      room:askForSkillInvoke(player, "rule")
    end,
    })
    return false
  end,

}
