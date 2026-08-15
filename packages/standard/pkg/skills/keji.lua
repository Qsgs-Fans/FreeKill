local keji = fk.CreateSkill{
  name = "keji",
}

keji:addEffect(fk.EventPhaseChanging, {
  anim_type = "defensive",
  can_trigger = function(self, event, target, player, data)
    if target == player and player:hasSkill(keji.name) and data.phase == Player.Discard and not data.skipped then
      local room = player.room
      local logic = room.logic
      local play_ids = logic:getEventsOfScope(GameEvent.Phase, 1, function (e)
        if e.data.phase == Player.Play and e.end_id then
          -- table.insert(play_ids, {e.id, e.end_id})
          return true
        end
        return false
      end, Player.HistoryTurn)
      if #play_ids == 0 then return true end
      ---@param e GameEvent.UseCard | GameEvent.RespondCard
      local function playCheck (e)
        local in_play = false
        for _, phase_event in ipairs(play_ids) do
          if e.id > phase_event.id and e.id < phase_event.end_id then
            in_play = true
            break
          end
        end
        return in_play and e.data.from == player and e.data.card.trueName == "slash"
      end
      return #logic:getEventsOfScope(GameEvent.UseCard, 1, playCheck, Player.HistoryTurn) == 0
      and #logic:getEventsOfScope(GameEvent.RespondCard, 1, playCheck, Player.HistoryTurn) == 0
    end
  end,
  on_use = function(self, event, target, player, data)
    data.skipped = true
  end,
})

keji:addAI(Fk.Ltk.AI.newInvokeStrategy{
  think = Util.TrueFunc
})

return keji
