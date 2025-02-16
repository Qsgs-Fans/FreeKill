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
  on_trigger = function(self, event, target, player, data)
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
    self.cancel_cost = false
    for _ = 1, i do
      if self.cancel_cost or not player:hasSkill(self) then break end
      self:doCost(event, target, player, data)
    end
  end,
  on_cost = function(self, event, target, player, data)
    if player.room:askForSkillInvoke(player, xiaoji.name) then
      return true
    end
    self.cancel_cost = true
  end,
  on_use = function(self, event, target, player, data)
    player:drawCards(2, xiaoji.name)
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
