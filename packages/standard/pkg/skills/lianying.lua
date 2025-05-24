local lianying = fk.CreateSkill({
  name = "lianying",
})

lianying:addEffect(fk.AfterCardsMove, {
  anim_type = "drawcard",
  can_trigger = function(self, event, target, player, data)
    if not (player:hasSkill(lianying.name) and player:isKongcheng()) then return end
    for _, move in ipairs(data) do
      if move.from == player then
        for _, info in ipairs(move.moveInfo) do
          if info.fromArea == Card.PlayerHand then
            return true
          end
        end
      end
    end
  end,
  on_use = function(self, event, target, player, data)
    player:drawCards(1, lianying.name)
  end,
})

lianying:addAI(nil, "jizhi")
lianying:addAI({
  correct_func = function(self, logic, event, target, player, data)
    if self.skill:triggerable(event, target, player, data) then
      logic:drawCards(logic.player, 1, self.skill.name)
    end
  end,
}, nil, nil, true)

lianying:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, lianying.name)
  end)
  FkTest.setNextReplies(me, { "1", "1", "1", "1", "1", "1", "1", "1" })
  FkTest.runInRoom(function()
    me:drawCards(3)
    room:throwCard(me:getCardIds("h"), nil, me, me)
  end)
  lu.assertEquals(#me:getCardIds("h"), 1)
end)

return lianying
