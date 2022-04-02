GameRule = fk.CreateTriggerSkill{
    name = "game_rule",
    events = {
        fk.GameStart, fk.TurnStart,
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
        [fk.TurnStart] = function()
            player = room.current
            if room.tag["FirstRound"] == true then
                room.tag["FirstRound"] = false
                player:setFlag("Global_FirstRound")
            end

            -- TODO: send log
            
            player:addMark("Global_TurnCount")
            player:setMark("damage_point_round", 0)
            if not player.faceup then
                player:setFlag("-Global_FirstRound")
                player:turnOver()
            elseif not player.dead then
                --player:play()
                room:askForSkillInvoke(player, "rule")
            end
        end,
        })
        return false
    end,

}
