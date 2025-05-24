local yingzi = fk.CreateSkill {
  name = "yingzi",
}

yingzi:addEffect(fk.DrawNCards, {
  on_use = function(self, event, target, player, data)
    data.n = data.n + 1
  end,
})

yingzi:addAI({
  think_skill_invoke = Util.TrueFunc,
})

yingzi:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, "yingzi")
  end)

  FkTest.setNextReplies(me, { "1" })
  FkTest.runInRoom(function()
    GameEvent.Turn:create(TurnData:new(me, "game_rule", { Player.Draw })):exec()
  end)

  lu.assertEquals(#me:getCardIds("h"), 3)
end)

return yingzi
