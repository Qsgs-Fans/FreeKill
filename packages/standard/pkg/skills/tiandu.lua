local tiandu = fk.CreateSkill {
  name = "tiandu",
}

tiandu:addEffect(fk.FinishJudge, {
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(tiandu.name) and
      data.card and player.room:getCardArea(data.card) == Card.Processing
  end,
  on_use = function(self, event, target, player, data)
    player.room:obtainCard(player, data.card, true, fk.ReasonJustMove, player, tiandu.name)
  end,
})

tiandu:addAI(Fk.Ltk.AI.newInvokeStrategy{
  think = function(self, ai)
    local data = ai.room.logic:getCurrentEvent().data
    return ai:getBenefitOfEvents(function(logic)
      logic:obtainCard(data.who, data.card, true, fk.ReasonJustMove, data.who, tiandu.name)
    end) > 0
  end,
})

return tiandu
