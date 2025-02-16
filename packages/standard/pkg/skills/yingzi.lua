local yingzi = fk.CreateSkill {
  name = "yingzi",
}

yingzi:addEffect(fk.DrawNCards, {
  on_use = function(self, event, target, player, data)
    data.n = data.n + 1
  end,
})

yingzi:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, "yingzi")
  end)

  FkTest.setNextReplies(me, { "1" })
  FkTest.runInRoom(function()
    local data = { ---@type TurnDataSpec
      who = me,
      reason = "game_rule",
      phase_table = { Player.Draw }
    }
    GameEvent.Turn:create(TurnData:new(data)):exec()
  end)

  lu.assertEquals(#me:getCardIds("h"), 3)
end)

return yingzi
