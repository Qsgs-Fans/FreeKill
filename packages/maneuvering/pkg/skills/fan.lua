local skill = fk.CreateSkill {
  name = "#fan_skill",
  attached_equip = "fan",
}

skill:addEffect(fk.AfterCardUseDeclared, {
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name) and data.card.name == "slash"
  end,
  on_use = function(self, event, target, player, data)
    local card = Fk:cloneCard("fire__slash", data.card.suit, data.card.number)
    for k, v in pairs(data.card) do
      if card[k] == nil then
        card[k] = v
      end
    end
    if data.card:isVirtual() then
      card.subcards = data.card.subcards
    else
      card.id = data.card.id
    end
    card.skillNames = data.card.skillNames
    card.skillName = "fan"
    data.card = card
  end,
})

return skill
