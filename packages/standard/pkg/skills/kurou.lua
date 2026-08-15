local kurou = fk.CreateSkill {
  name = "kurou",
}

kurou:addEffect("active", {
  anim_type = "drawcard",
  prompt = "#kurou-active",
  card_filter = Util.FalseFunc,
  on_use = function(self, room, effect)
    local from = effect.from
    room:loseHp(from, 1, kurou.name)
    if from:isAlive() then
      from:drawCards(2, kurou.name)
    end
  end
})

kurou:addAI(Fk.Ltk.AI.newActiveStrategy {
  think = function(self, ai)
    local player = ai.player

    return { }, ai:getBenefitOfEvents(function(logic)
      logic:loseHp(player, 1, kurou.name)
      logic:drawCards(player, 2, kurou.name)
    end)
  end,
})

return kurou
