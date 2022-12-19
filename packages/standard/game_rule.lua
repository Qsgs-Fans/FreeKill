---@param victim ServerPlayer
local function getWinner(victim)
  local room = victim.room
  local winner = ""
  local alive = room.alive_players

  if victim.role == "lord" then
    if #alive == 1 and alive[1].role == "renegade" then
      winner = "renegede"
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
    fk.GameOverJudge, fk.BuryVictim,
  },
  priority = 0,

  can_trigger = function(self, event, target, player, data)
    return (target == player) or (target == nil)
  end,

  on_trigger = function(self, event, target, player, data)
    if RoomInstance.tag["SkipGameRule"] then
      RoomInstance.tag["SkipGameRule"] = false
      return false
    end

    if target == nil then
      if event == fk.GameStart then
        fk.qInfo("Game started")
        RoomInstance.tag["FirstRound"] = true
      end
      return false
    end

    local room = player.room
    switch(event, {
    [fk.DrawInitialCards] = function()
      if data.num > 0 then
        -- TODO: need a new function to call the UI
        local cardIds = room:getNCards(data.num)
        player:addCards(Player.Hand, cardIds)
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
    [fk.TurnStart] = function()
      player = room.current
      if room.tag["FirstRound"] == true then
        room.tag["FirstRound"] = false
        player:setFlag("Global_FirstRound")
      end

      room:sendLog{ type = "$AppendSeparator" }
      
      player:addMark("Global_TurnCount")
      if not player.faceup then
        player:setFlag("-Global_FirstRound")
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
        
      end,
      [Player.Draw] = function()
        room:drawCards(player, 2, self.name)
      end,
      [Player.Play] = function()
        while not player.dead do
          room:notifyMoveFocus(player, "PlayCard")
          local result = room:doRequest(player, "PlayCard", player.id)
          if result == "" then break end

          local data = json.decode(result)
          local card = data.card
          local targets = data.targets
          if type(card) == "string" then
            local card_data = json.decode(card)
            local skill = Fk.skills[card_data.skill]
            local selected_cards = card_data.subcards
            skill:onEffect(room, {
              from = player.id,
              cards = selected_cards,
              tos = targets,
            })
          else
            local use = {}    ---@type CardUseStruct
            use.from = player.id
            use.tos = {}
            for _, target in ipairs(targets) do
              table.insert(use.tos, { target })
            end
            use.cardId = card
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
        -- TODO: clear history
      end
    end,
    [fk.EventPhaseChanging] = function()
      -- TODO: copy but dont copy all
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
        local killer = room:getPlayerById(damage.from)
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
