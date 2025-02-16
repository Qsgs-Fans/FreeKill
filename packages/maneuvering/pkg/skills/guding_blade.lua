local skill = fk.CreateSkill {
  name = "#guding_blade_skill",
  attached_equip = "guding_blade",
  frequency = Skill.Compulsory,
}

skill:addEffect(fk.DamageCaused, {
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name) and
      data.to:isKongcheng() and data.card and data.card.trueName == "slash" and data.by_user
  end,
  on_use = function(self, event, target, player, data)
    data.damage = data.damage + 1
  end,
})

return skill
