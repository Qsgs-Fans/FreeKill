local luoshen = fk.CreateSkill{
  name = "luoshen",
}

luoshen:addEffect(fk.EventPhaseStart, {
  anim_type = "drawcard",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(luoshen.name) and player.phase == Player.Start
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    while true do
      local judge = {
        who = player,
        reason = luoshen.name,
        pattern = ".|.|black",
      }
      room:judge(judge)
      if not judge:matchPattern() or player.dead or not room:askToSkillInvoke(player, { skill_name = luoshen.name }) then
        break
      end
    end
  end,
})
luoshen:addEffect(fk.FinishJudge, {
  mute = true,
  is_delay_effect = true,
  can_trigger = function(self, event, target, player, data)
    return target == player and not player.dead and data.reason == luoshen.name and data.card.color == Card.Black and
      player.room:getCardArea(data.card) == Card.Processing
  end,
  on_use = function(self, event, target, player, data)
    player.room:obtainCard(player, data.card, true, fk.ReasonJustMove, nil, luoshen.name)
  end,
})

luoshen:addAI(Fk.Ltk.AI.newInvokeStrategy{
  think = function(self, ai)
    return ai:getBenefitOfEvents(function(logic)
      logic:judge({
        who = ai.player,
        reason = luoshen.name,
        pattern = ".|.|black",
      })
    end) >= -100
  end,
})

return luoshen
