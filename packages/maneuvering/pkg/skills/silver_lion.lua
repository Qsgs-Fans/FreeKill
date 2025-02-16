local skill = fk.CreateSkill {
  name = "#silver_lion_skill",
  attached_equip = "silver_lion",
  frequency = Skill.Compulsory,
}

skill:addEffect(fk.DamageInflicted, {
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name) and data.damage > 1
  end,
  on_use = function(self, event, target, player, data)
    data.damage = 1
  end,
})
skill:addEffect(fk.AfterCardsMove, {
  can_trigger = function(self, event, target, player, data)
    if player.dead or not player:isWounded() then return end
    for _, move in ipairs(data) do
      if move.from == player then
        for _, info in ipairs(move.moveInfo) do
          if info.fromArea == Card.PlayerEquip and Fk:getCardById(info.cardId).name == self.attached_equip then
            return self:isEffectable(player)
          end
        end
      end
    end
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    room:recover{
      who = player,
      num = 1,
      recoverBy = player,
      skillName = skill.name,
    }
  end,
})

return skill
