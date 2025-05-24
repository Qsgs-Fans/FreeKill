local zhiheng = fk.CreateSkill {
  name = "zhiheng",
}

zhiheng:addEffect("active", {
  anim_type = "drawcard",
  prompt = "#zhiheng-active",
  max_phase_use_time = 1,
  target_num = 0,
  min_card_num = 1,
  card_filter = function(self, player, to_select)
    return not player:prohibitDiscard(to_select)
  end,
  on_use = function(self, room, effect)
    local from = effect.from
    room:throwCard(effect.cards, zhiheng.name, from, from)
    if from:isAlive() then
      from:drawCards(#effect.cards, zhiheng.name)
    end
  end,
})

zhiheng:addAI({
  think = function(self, ai)
    local player = ai.player
    local cards = ai:getEnabledCards(".|.|.|hand|.|.|.")

    cards = ai:getChoiceCardsByKeepValue(cards, #cards, function(value) return value < 45 end)

    return { cards = cards }, ai:getBenefitOfEvents(function(logic)
      logic:throwCard(cards, self.skill.name, player, player)
      logic:drawCards(player, #cards, self.skill.name)
    end)
  end,
})

return zhiheng
