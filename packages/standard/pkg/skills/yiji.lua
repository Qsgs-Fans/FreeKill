local yiji = fk.CreateSkill {
  name = "yiji",
}

yiji:addEffect(fk.Damaged, {
  on_trigger = function(self, event, target, player, data)
    self.cancel_cost = false
    for _ = 1, data.damage do
      if self.cancel_cost or not player:hasSkill(self) then break end
      self:doCost(event, target, player, data)
    end
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    if room:askForSkillInvoke(player, yiji.name, data) then
      return true
    end
    self.cancel_cost = true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local ids = room:getNCards(2)
    while not player.dead do
      room:setPlayerMark(player, "yiji_cards", ids)
      local _, ret = room:askForUseActiveSkill(player, "yiji_active", "#yiji-give", true, nil, true)
      room:setPlayerMark(player, "yiji_cards", 0)
      if ret then
        for _, id in ipairs(ret.cards) do
          table.removeOne(ids, id)
        end
        room:moveCardTo(ret.cards, Card.PlayerHand, room:getPlayerById(ret.targets[1]), fk.ReasonGive,
        yiji.name, nil, false, player.id, nil, player.id)
        if #ids == 0 then break end
        if player.dead then
          room:moveCards({
            ids = ids,
            toArea = Card.DiscardPile,
            moveReason = fk.ReasonJustMove,
            skillName = yiji.name,
          })
          break
        end
      else
        room:moveCardTo(ids, Player.Hand, player, fk.ReasonGive, yiji.name, nil, false, player.id)
        break
      end
    end
  end,
})

local yiji_active = fk.CreateSkill {
  name = "yiji_active",
}
yiji_active:addEffect("active", {
  expand_pile = function(self, player)
    return player:getTableMark("yiji_cards")
  end,
  min_card_num = 1,
  target_num = 1,
  card_filter = function(self, player, to_select, selected)
      return table.contains(player:getTableMark("yiji_cards"), to_select)
  end,
  target_filter = function(self, player, to_select, selected)
    return #selected == 0 and to_select ~= player
  end,
})

return yiji, yiji_active
