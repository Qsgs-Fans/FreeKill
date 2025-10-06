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
    if self.skill:triggerable(event, target, player, data) then
      data.nullified = true
    end
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

skill:addTest(function (room, me)
  local exp1 = Exppattern:Parse("slash,jink")
  local exp2 = Exppattern:Parse(".|.|.|.|peach,slash")
  local slash = Fk:cloneCard("slash")
  lu.assertTrue(exp1:match(slash))
  lu.assertTrue(exp2:match(slash))
  local t_slash = Fk:cloneCard("thunder__slash")
  lu.assertTrue(exp1:match(t_slash))
  lu.assertFalse(exp2:match(t_slash))

  lu.assertTrue(exp1:matchExp(exp2))
  lu.assertTrue(exp2:matchExp(exp1))
  local exp3 = Exppattern:Parse(".|.|.|.|thunder__slash")
  lu.assertTrue(exp1:matchExp(exp3))
  lu.assertFalse(exp3:matchExp(exp2))
  lu.assertTrue(exp3:matchExp(exp1))

  local exp4 = Exppattern:Parse(".|.|red")
  local exp5 = Exppattern:Parse(".|.|^club")
  local r_slash = Fk:cloneCard("slash")
  lu.assertFalse(exp4:match(r_slash))
  lu.assertTrue(exp5:match(r_slash))
  r_slash.color = Card.Red
  local club_slash = Fk:cloneCard("slash", Card.Club)
  lu.assertTrue(exp4:matchExp(exp5))
  lu.assertTrue(exp4:match(r_slash))
  lu.assertFalse(exp4:match(club_slash))
  lu.assertTrue(exp5:match(r_slash))
  lu.assertFalse(exp5:match(club_slash))
  local exp6 = Exppattern:Parse(".|.|^club;.|.|red")
  local spade_slash = Fk:cloneCard("slash", Card.Club)
  lu.assertTrue(exp6:match(r_slash))
  lu.assertFalse(exp6:match(club_slash))
  lu.assertFalse(exp6:match(spade_slash))
end)

return skill
