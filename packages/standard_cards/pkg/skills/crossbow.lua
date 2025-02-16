local sk = fk.CreateSkill {
  name = "#crossbow_skill",
  attached_equip = "crossbow",
}

sk:addEffect(fk.CardUsing, {
  refresh_events = {fk.CardUsing},
  can_refresh = function(self, event, target, player, data)
    return target == player and player:hasSkill(self) and player.phase == Player.Play and
      data.card.trueName == "slash" and player:usedCardTimes("slash", Player.HistoryPhase) > 1
  end,
  on_refresh = function(self, event, target, player, data)
    local room = player.room
    room:broadcastPlaySound("./packages/standard_cards/audio/card/crossbow")
    room:setEmotion(player, "./packages/standard_cards/image/anim/crossbow")
    room:sendLog{
      type = "#InvokeSkill",
      from = player.id,
      arg = "crossbow",
    }
  end,
})
sk:addEffect("targetmod", {
  bypass_times = function(self, player, skill, scope, card)
    if player:hasSkill(skill.name) and card.trueName == "slash_skill" and scope == Player.HistoryPhase then
      --FIXME: 无法检测到非转化的cost选牌的情况，如活墨等
      local cardIds = Card:getIdList(card)
      local crossbows = table.filter(player:getEquipments(Card.SubtypeWeapon), function(id)
        return Fk:getCardById(id).equip_skill == self
      end)
      return #crossbows == 0 or not table.every(crossbows, function(id)
        return table.contains(cardIds, id)
      end)
    end
  end,
})

return sk
