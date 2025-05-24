local fanSkill = fk.CreateSkill {
  name = "#fan_skill",
  attached_equip = "fan",
}

fanSkill:addEffect(fk.AfterCardUseDeclared, {
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(fanSkill.name) and data.card.name == "slash"
  end,
  on_use = function(self, event, target, player, data)
    data:changeCard("fire__slash", data.card.suit, data.card.number, fanSkill.name)
  end,
})

fanSkill:addTest(function (room, me)
  local card = room:printCard("fan")
  local comp2 = room.players[2]
  local vine = room:printCard("vine")
  FkTest.runInRoom(function ()
    room:useCard{
      from = me,
      tos = {me},
      card = card,
    }
    room:useCard{
      from = comp2,
      tos = {comp2},
      card = vine,
    }
    room:useVirtualCard("slash", nil, me, comp2)
  end)
  lu.assertEquals(comp2.hp, 4)

  FkTest.setNextReplies(me, {"1"})
  FkTest.runInRoom(function ()
    room:useVirtualCard("slash", nil, me, comp2)
  end)
  lu.assertEquals(comp2.hp, 2)

  FkTest.setNextReplies(me, {"1"})
  FkTest.runInRoom(function ()
    room:useVirtualCard("thunder__slash", nil, me, comp2)
  end)
  lu.assertEquals(comp2.hp, 1)
end)

return fanSkill
