local tieqi = fk.CreateSkill {
  name = "tieqi",
}

tieqi:addEffect(fk.TargetSpecified, {
  anim_type = "offensive",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(tieqi.name) and data.card.trueName == "slash"
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local judge = {
      who = player,
      reason = tieqi.name,
      pattern = ".|.|red",
    }
    room:judge(judge)
    if judge:matchPattern() then
      data.disresponsive = true
    end
  end,
})

tieqi:addAI(Fk.Ltk.AI.newInvokeStrategy{
  think = function(self, ai)
    ---@type UseCardData
    local data = ai.room.logic:getCurrentEvent().data
    local player = ai.player
    if ai:isEnemy(data.tos[1]) then
      return ai:getBenefitOfEvents(function(logic)
        logic:judge({
          who = player,
          reason = tieqi.name,
          pattern = ".|.|red",
        })
      end) >= -200
    end
  end,
})

return tieqi
