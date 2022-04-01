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
        if player == nil then return false end
        return TriggerSkill.trigger(self, event, target, player, data)
    end,

}
