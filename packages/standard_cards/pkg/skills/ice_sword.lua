local skill = fk.CreateSkill {
  name = "#ice_sword_skill",
  attached_equip = "ice_sword",
}

skill:addEffect(fk.DetermineDamageCaused, {
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name) and data.by_user and
      data.card and data.card.trueName == "slash" and not data.to:isNude()
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    data:preventDamage()
    local to = data.to
    for i = 1, 2 do
      if player.dead or to.dead or to:isNude() then break end
      local card = room:askToChooseCard(player, { target = to, flag = "he", skill_name = skill.name })
      room:throwCard(card, skill.name, to, player)
    end
  end,
})

skill:addAI(Fk.Ltk.AI.newInvokeStrategy{
  think = function(self, ai)
    ---@type DamageData
    local data = ai.room.logic:getCurrentEvent().data
    local player = ai.player
    local ret, benefit = player.ai:askToChooseCards({
      cards = data.to:getCardIds("he"),
      skill_name = skill.name,
      data = {
        min = math.min(#data.to:getCardIds("he"), 2),
        to_place = Card.DiscardPile,
        reason = fk.ReasonDiscard,
        proposer = player,
      },
    })
    local val = ai:getBenefitOfEvents(function(logic)
      logic:throwCard(ret, skill.name, data.to, player)
    end)
    return 1.1 * val > ai:getBenefitOfEvents(function(logic)
      logic:damage({
        from = player,
        to = data.to,
        card = data.card,
        damage = data.damage,
        damageType = data.damageType,
      })
    end)
  end,
})

return skill
