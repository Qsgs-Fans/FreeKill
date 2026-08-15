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

xiaoji:addAI(Fk.Ltk.AI.newInvokeStrategy{
  think = function(self, ai)
    return ai:getBenefitOfEvents(function(logic)
      logic:drawCards(ai.player, 2, self.skill_name)
    end) > 0
  end,
})

return xiaoji
