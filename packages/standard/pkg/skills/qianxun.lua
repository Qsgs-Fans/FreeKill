local qianxun = fk.CreateSkill{
  name = "qianxun",
  frequency = Skill.Compulsory,
}

qianxun:addEffect("prohibit", {
  is_prohibited = function(self, from, to, card)
    if to:hasSkill(qianxun.name) and card then
      return table.contains({"indulgence", "snatch"}, card.trueName)
    end
  end,
})

qianxun:addTest(function(room, me)
  local comp2 = room.players[2]

  local snatch = room:printCard("snatch")
  local indulgence = room:printCard("indulgence")

  FkTest.runInRoom(function()
    -- 让顺手牵羊可以用一下
    me:drawCards(1)
  end)

  lu.assertTrue(comp2:canUseTo(snatch, me))
  lu.assertTrue(comp2:canUseTo(indulgence, me))

  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, "qianxun")
  end)

  lu.assertFalse(comp2:canUseTo(snatch, me))
  lu.assertFalse(comp2:canUseTo(indulgence, me))
end
)

return qianxun
