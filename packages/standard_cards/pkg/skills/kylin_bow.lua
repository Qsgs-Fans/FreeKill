local skill = fk.CreateSkill {
  name = "#kylin_bow_skill",
  attached_equip = "kylin_bow",
}

skill:addEffect(fk.DamageCaused, {
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name) and
      data.card and data.card.trueName == "slash" and not data.chain and
      table.find(data.to:getCardIds("e"), function (id)
        local card = Fk:getCardById(id)
        return card.sub_type == Card.SubtypeDefensiveRide or card.sub_type == Card.SubtypeOffensiveRide
      end)
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local to = data.to
    local ride_tab = table.filter(to:getCardIds("e"), function (id)
      local card = Fk:getCardById(id)
      return card.sub_type == Card.SubtypeDefensiveRide or card.sub_type == Card.SubtypeOffensiveRide
    end)
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
