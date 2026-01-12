local skill = fk.CreateSkill {
  name = "#kylin_bow_skill",
  attached_equip = "kylin_bow",
}

skill:addEffect(fk.DamageCaused, {
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name) and
      data.card and data.card.trueName == "slash" and data.by_user and
      table.find(data.to:getEquipCards(), function(card)
        return card.sub_type == Card.SubtypeDefensiveRide or card.sub_type == Card.SubtypeOffensiveRide
      end)
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local to = data.to
    local ride_tab = {}
    for _, card in ipairs(to:getEquipCards()) do
      if card.sub_type == Card.SubtypeDefensiveRide or card.sub_type == Card.SubtypeOffensiveRide then
        table.insert(ride_tab, card:getEffectiveId())
      end
    end
    if #ride_tab == 0 then return end
    local id = room:askToChooseCard(player, {
      target = to,
      flag = { card_data = { { "equip_horse", ride_tab } } },
      skill_name = self.name,
    })
    room:throwCard(id, skill.name, to, player)
  end,
})

skill:addAI(Fk.Ltk.AI.newInvokeStrategy{
  think = function(self, ai)
    ---@type DamageData
    local data = ai.room.logic:getCurrentEvent().data
    local player = ai.player
    local ride_tab = {}
    for _, card in ipairs(data.to:getEquipCards()) do
      if card.sub_type == Card.SubtypeDefensiveRide or card.sub_type == Card.SubtypeOffensiveRide then
        table.insert(ride_tab, card:getEffectiveId())
      end
    end
    local ret, benefit = player.ai:askToChooseCards({
      cards = ride_tab,
      skill_name = skill.name,
      data = {
        to_place = Card.DiscardPile,
        reason = fk.ReasonDiscard,
        proposer = player,
      },
    })
    return ai:getBenefitOfEvents(function(logic)
      logic:throwCard(ret, skill.name, data.to, player)
    end) >= 0
  end,
})

return skill
