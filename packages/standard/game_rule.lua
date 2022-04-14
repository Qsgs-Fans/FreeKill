GameRule = fk.CreateTriggerSkill{
    name = "game_rule",
    events = {
        fk.GameStart, fk.DrawInitialCards, fk.TurnStart,
        fk.EventPhaseProceeding, fk.EventPhaseEnd, fk.EventPhaseChanging,
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
                print("Game started")
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
                move_to_notify.to = player:getId()
                move_to_notify.moveInfo = {}
                for _, id in ipairs(cardIds) do
                    table.insert(move_to_notify.moveInfo, 
                    { cardId = id, fromArea = Card.DrawPile })
                end
                room:notifyMoveCards(room.players, {move_to_notify})

                for _, id in ipairs(cardIds) do
                    room:setCardArea(id, Card.PlayerHand)
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

            -- TODO: send log
            
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
                room:askForSkillInvoke(player, "rule")
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
        default = function()
            print("game_rule: Event=" .. event)
            room:askForSkillInvoke(player, "rule")
        end,
        })
        return false
    end,

}
