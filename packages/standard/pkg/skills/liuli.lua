local liuli = fk.CreateSkill{
  name = "liuli",
}

liuli:addEffect(fk.TargetConfirming, {
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(liuli.name) and data.card.trueName == "slash" and
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
    local plist, cid = room:askForChooseCardAndPlayers(player, targets, 1, 1, nil, "#liuli-target", liuli.name, true)
    if #plist > 0 then
      self.cost_data = {tos = plist, cards = {cid}}
      return true
    end
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local to = self.cost_data.tos[1]
    room:throwCard(self.cost_data.cards, liuli.name, player, player)
    AimGroup:cancelTarget(data, player.id)
    AimGroup:addTargets(room, data, to)
  end,
})

return liuli
