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
    local params = { ---@type AskToUseCardParams
      skill_name = "slash",
      pattern = "slash",
      prompt = "#blade_slash:" .. data.to.id,
      cancelable = true,
      extra_data = {
        must_targets = {data.to.id},
        exclusive_targets = {data.to.id},
        bypass_distances = true,
        bypass_times = true,
      }
    }
    local use = room:askToUseCard(player, params)
    if use then
      use.extraUse = true
      event:setCostData(self, {extra_data = use})
      return true
    end
  end,
  on_use = function(self, event, target, player, data)
    player.room:useCard(event:getCostData(self).extra_data)
  end,
})

return skill
