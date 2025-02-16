local skill = fk.CreateSkill {
  name = "#double_swords_skill",
  attached_equip = "double_swords",
}

skill:addEffect(fk.TargetSpecified, {
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name) and
      data.card and data.card.trueName == "slash" and
      player:compareGenderWith(data.to, true)
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local to = data.to
    if to:isKongcheng() then
      player:drawCards(1, skill.name)
    else
      local result = room:askForDiscard(to, 1, 1, false, skill.name, true, nil, "#double_swords-invoke:"..player.id)
      if #result == 0 then
        player:drawCards(1, skill.name)
      end
    end
  end,
})

return skill
