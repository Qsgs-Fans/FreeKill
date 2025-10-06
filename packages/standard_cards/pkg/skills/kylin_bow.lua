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
    local id = room:askToChooseCard(player, { target = to,
    flag = {
      card_data = {
        { "equip_horse", ride_tab }
      }
    }, skill_name = self.name })
    room:throwCard({id}, skill.name, to, player)
  end,
})

return skill
