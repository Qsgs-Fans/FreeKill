local skill = fk.CreateSkill {
  name = "#guding_blade_skill",
  tags = { Skill.Compulsory },
  attached_equip = "guding_blade",
}

skill:addEffect(fk.DamageCaused, {
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name) and
      data.to:isKongcheng() and data.card and data.card.trueName == "slash" and data.by_user
  end,
  on_use = function(self, event, target, player, data)
    data:changeDamage(1)
  end,
})

return skill
