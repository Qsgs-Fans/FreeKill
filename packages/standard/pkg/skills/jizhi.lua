local jizhi = fk.CreateSkill{
  name = "jizhi",
}

jizhi:addEffect(fk.CardUsing, {
  anim_type = "drawcard",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(jizhi.name) and
      data.card:isCommonTrick() and not data.card:isVirtual()
  end,
  on_use = function(self, event, target, player, data)
    player:drawCards(1, jizhi.name)
  end,
})

jizhi:addTest(function(room, me)
  local comp2 = room.players[2]

  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, "jizhi")
  end)

  local slash = Fk:getCardById(1)
  local god_salvation = room:printCard("god_salvation")

  FkTest.setNextReplies(me, { "1", "1" })
  FkTest.runInRoom(function()
    room:moveCardTo({2, 3, 4, 5}, Card.DrawPile) -- 都是杀……吧？
    room:useCard{
      from = me,
      tos = { comp2 },
      card = slash,
    }
  end)
  lu.assertEquals(#me:getCardIds("h"), 0)
  FkTest.runInRoom(function()
    room:useCard{
      from = me,
      tos = { comp2 },
      card = god_salvation,
    }
  end)
  lu.assertEquals(#me:getCardIds("h"), 1)
end)

return jizhi
