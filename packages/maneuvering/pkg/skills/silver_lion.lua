local silverLionSkill = fk.CreateSkill {
  name = "#silver_lion_skill",
  tags = { Skill.Compulsory },
  attached_equip = "silver_lion",
}

silverLionSkill:addEffect(fk.DetermineDamageInflicted, {
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(silverLionSkill.name) and data.damage > 1
  end,
  on_use = function(self, event, target, player, data)
    data:changeDamage(1 - data.damage)
  end,
})
silverLionSkill:addEffect(fk.AfterCardsMove, {
  can_trigger = function(self, event, target, player, data)
    if player.dead or not player:isWounded() or not Fk.skills[silverLionSkill.name]:isEffectable(player) then return end
    for _, move in ipairs(data) do
      if move.from == player then
        for _, info in ipairs(move.moveInfo) do
          local card = info.beforeCard
          if info.fromArea == Card.PlayerEquip and card.name == silverLionSkill.attached_equip then
            return true
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
      skillName = silverLionSkill.name,
    }
  end,
})

silverLionSkill:addTest(function (room, me)
  local card = room:printCard("silver_lion")
  FkTest.runInRoom(function ()
    room:useCard{
      from = me,
      tos = {me},
      card = card,
    }
    room:damage{
      to = me,
      damage = 2,
    }
  end)
  lu.assertEquals(me.hp, 3)
  FkTest.runInRoom(function ()
    room:throwCard(card, nil, me)
  end)
  lu.assertEquals(me.hp, 4)
end)

return silverLionSkill
