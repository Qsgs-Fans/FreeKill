local skill = fk.CreateSkill {
  name = "jink_skill",
}

skill:addEffect("cardskill", {
  can_use = Util.FalseFunc,
  on_effect = function(self, room, effect)
    if effect.responseToEvent then
      effect.responseToEvent.isCancellOut = true
    end
  end,
})

skill:addTest(function (room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function ()
    room:useVirtualCard("slash", nil, comp2, me)
  end)
  lu.assertEquals(me.hp, 3)

  local card = room:printCard("jink")
  FkTest.setNextReplies(me, { {
    card = card.id,
  } })
  FkTest.runInRoom(function ()
    room:obtainCard(me, card)
    room:useVirtualCard("slash", nil, comp2, me)
  end)
  lu.assertEquals(me.hp, 3)
  lu.assertIsTrue(me:isKongcheng())
end)

return skill
