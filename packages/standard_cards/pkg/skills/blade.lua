local skill = fk.CreateSkill {
  name = "#blade_skill",
  attached_equip = "blade",
}

skill:addEffect(fk.CardEffectCancelledOut, {
  can_trigger = function(self, event, target, player, data)
    return player:hasSkill(skill.name) and data.from == player and data.card.trueName == "slash" and not data.to.dead
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    local use = room:askForUseCard(player, "slash", nil, "#blade_slash:" .. data.to, true, {
      must_targets = {data.to},
      exclusive_targets = {data.to},
      bypass_distances = true,
      bypass_times = true,
    })
    if use then
      use.extraUse = true
      self.cost_data = use
      return true
    end
  end,
  on_use = function(self, event, target, player, data)
    player.room:useCard(self.cost_data)
  end,
})

return skill
