local skill = fk.CreateSkill {
  name = "#nioh_shield_skill",
  tags = { Skill.Compulsory },
  attached_equip = "nioh_shield",
}

skill:addEffect(fk.PreCardEffect, {
  can_trigger = function(self, event, target, player, data)
    return data.to == player and player:hasSkill(skill.name) and
    data.card.trueName == "slash" and data.card.color == Card.Black
  end,
  on_use = function(_, _, _, _, data)
    data.nullified = true
  end
})

skill:addAI({
  correct_func = function(self, logic, event, target, player, data)
    return self.skill:triggerable(event, target, player, data)
  end,
}, nil, nil, true)

skill:addTest(function(room, me)
  local nioh_shield = room:printCard("nioh_shield")
  local comp2 = room.players[2]

  FkTest.runInRoom(function()
    room:useCard {
      from = me,
      tos = { me },
      card = nioh_shield,
    }
    room:useCard {
      from = comp2,
      tos = { me },
      card = Fk:cloneCard("slash", Card.Spade),
    }
    lu.assertEquals(me.hp, 4)
    room:useCard {
      from = comp2,
      tos = { me },
      card = Fk:cloneCard("slash", Card.Heart),
    }
    lu.assertEquals(me.hp, 3)
  end)
end)

return skill
