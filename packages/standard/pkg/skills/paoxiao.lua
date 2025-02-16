local paoxiao = fk.CreateSkill{
  name = "paoxiao",
  frequency = Skill.Compulsory,
}

paoxiao:addEffect("targetmod", {
  bypass_times = function(self, player, skill, scope, card)
    if player:hasSkill(paoxiao.name) and card and card.trueName == "slash_skill" and scope == Player.HistoryPhase then
      return true
    end
  end,
})

paoxiao:addEffect(fk.CardUsing, {
  can_refresh = function(self, event, target, player, data)
    return target == player and player:hasSkill(paoxiao.name) and
      data.card.trueName == "slash" and
      player:usedCardTimes("slash", Player.HistoryPhase) > 1
  end,
  on_refresh = function(self, event, target, player, data)
    player:broadcastSkillInvoke("paoxiao")
    player.room:doAnimate("InvokeSkill", {
      name = "paoxiao",
      player = player.id,
      skill_type = paoxiao.name,
    })
  end,
})

return paoxiao
