local skill = fk.CreateSkill {
  name = "#ice_sword_skill",
  attached_equip = "ice_sword",
}

skill:addEffect(fk.DamageCaused, {
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name) and (not data.chain) and
      data.card and data.card.trueName == "slash" and not data.to:isNude()
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local to = data.to
    for i = 1, 2 do
      if player.dead or to.dead or to:isNude() then break end
      local card = room:askForCardChosen(player, to, "he", skill.name)
      room:throwCard(card, skill.name, to, player)
    end
    return true
  end,
})

return skill
