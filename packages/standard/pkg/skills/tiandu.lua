local tiandu = fk.CreateSkill {
  name = "tiandu",
}

tiandu:addEffect(fk.FinishJudge, {
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(tiandu.name) and
      data.card and player.room:getCardArea(data.card) == Card.Processing
  end,
  on_use = function(self, event, target, player, data)
    player.room:obtainCard(player.id, data.card, true, fk.ReasonJustMove, tiandu.name)
  end,
})

tiandu:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, "tiandu")
  end)
  FkTest.setNextReplies(me, { "1", "1", "1", "1", "1", "1", "1", "1" }) -- 试图领取所有人的判定牌
  FkTest.runInRoom(function()
    for _, p in ipairs(room.players) do
      room:judge{
        who = p,
        pattern = ".",
        reason = "test"
      }
    end
  end)
  lu.assertEquals(#me:getCardIds("h"), 1)
end)

return tiandu
