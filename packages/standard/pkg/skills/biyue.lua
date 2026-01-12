local biyue = fk.CreateSkill{
  name = "biyue",
}

biyue:addEffect(fk.EventPhaseStart, {
  anim_type = "drawcard",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(biyue.name) and player.phase == Player.Finish
  end,
  on_use = function(self, event, target, player, data)
    player:drawCards(1, biyue.name)
  end,
})

biyue:addAI(Fk.Ltk.AI.newInvokeStrategy{
  think = function(self, ai)
    return ai:getBenefitOfEvents(function(logic)
      logic:drawCards(ai.player, 1, self.skill_name)
    end) > 0
  end,
})

biyue:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, "biyue")
  end)

  FkTest.setNextReplies(me, { "1" })
  FkTest.runInRoom(function()
    GameEvent.Turn:create(TurnData:new(me, "game_rule", { Player.Finish })):exec()
  end)

  lu.assertEquals(#me:getCardIds("h"), 1)
end)

return biyue
