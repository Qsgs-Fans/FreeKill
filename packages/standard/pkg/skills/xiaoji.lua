local xiaoji = fk.CreateSkill {
  name = "xiaoji",
}

xiaoji:addEffect(fk.AfterCardsMove, {
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(xiaoji.name) then return end
    for _, move in ipairs(data) do
      if move.from == player then
        for _, info in ipairs(move.moveInfo) do
          if info.fromArea == Card.PlayerEquip then
            return true
          end
        end
      end
    end
  end,
  trigger_times = function(self, event, target, player, data)
    local i = 0
    for _, move in ipairs(data) do
      if move.from == player then
        for _, info in ipairs(move.moveInfo) do
          if info.fromArea == Card.PlayerEquip then
            i = i + 1
          end
        end
      end
    end
    return i
  end,
  on_cost = function(self, event, target, player, data)
    if player.room:askToSkillInvoke(player, { skill_name = xiaoji.name }) then
      return true
    end
  end,
  on_use = function(self, event, target, player, data)
    player:drawCards(2, xiaoji.name)
  end,
})

xiaoji:addAI({
  think_skill_invoke = function(self, ai, skill_name, prompt)
    return ai:getBenefitOfEvents(function(logic)
      logic:drawCards(ai.player, 2, self.skill.name)
    end) > 0
  end,
})

xiaoji:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, xiaoji.name)
  end)
  FkTest.setNextReplies(me, { "1", "1", "1", "1", "1", "1", "1", "1" })

  local nioh = room:printCard("nioh_shield")

  local spear = room:printCard("spear")

  FkTest.runInRoom(function()
    room:useCard{
      from = me,
      tos = {me},
      card = nioh,
    }
    room:useCard{
      from = me,
      tos = {me},
      card = spear,
    }
    room:throwCard(me:getCardIds("he"), nil, me, me)
  end)
  lu.assertEquals(#me:getCardIds("h"), 4)
end)

return xiaoji
