local yiji = fk.CreateSkill {
  name = "yiji",
}

yiji:addEffect(fk.Damaged, {
  trigger_times = function(self, event, target, player, data)
    return data.damage
  end,
  on_cost = function(self, event, target, player, data)
    if player.room:askToSkillInvoke(player, { skill_name = yiji.name }) then
      return true
    end
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local ids = room:getNCards(2)
    while not player.dead do
      local tos, cards = room:askToChooseCardsAndPlayers(player, {
        min_num = 1,
        max_num = 1,
        min_card_num = 1,
        max_card_num = #ids,
        targets = room.alive_players,
        pattern = tostring(Exppattern{ id = ids }),
        skill_name = yiji.name,
        prompt = "#yiji-give",
        cancelable = true,
        expand_pile = ids,
      })
      if #tos > 0 and #cards > 0 then
        for _, id in ipairs(cards) do
          table.removeOne(ids, id)
        end
        room:moveCardTo(cards, Card.PlayerHand, tos[1], fk.ReasonGive, yiji.name, nil, false, player)
        if #ids == 0 then break end
      else
        room:moveCardTo(ids, Card.PlayerHand, player, fk.ReasonGive, yiji.name, nil, false, player)
        return
      end
    end
  end,
})

return yiji
