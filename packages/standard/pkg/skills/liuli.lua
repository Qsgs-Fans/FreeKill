local liuli = fk.CreateSkill{
  name = "liuli",
}

liuli:addEffect(fk.TargetConfirming, {
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(liuli.name) and not data.cancelled and data.card.trueName == "slash" and
      table.find(player.room.alive_players, function (p)
        return player:inMyAttackRange(p) and p ~= data.from and not data.from:isProhibited(p, data.card)
      end) and
      not player:isNude()
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    local targets = table.filter(room.alive_players, function (p)
      return player:inMyAttackRange(p) and p ~= data.from and not data.from:isProhibited(p, data.card)
    end)
    local tos, cards = room:askToChooseCardsAndPlayers(player, {
      min_num = 1,
      max_num = 1,
      min_card_num = 1,
      max_card_num = 1,
      targets = targets,
      pattern = ".",
      skill_name = liuli.name,
      prompt = "#liuli-target",
      cancelable = true,
      will_throw = true,
    })
    if #tos > 0 and #cards > 0 then
      event:setCostData(self, {tos = tos, cards = cards})
      return true
    end
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local to = event:getCostData(self).tos[1]
    room:throwCard(event:getCostData(self).cards, liuli.name, player, player)
    if data:cancelCurrentTarget() then
      data:addTarget(to)
    end
  end,
})

return liuli
