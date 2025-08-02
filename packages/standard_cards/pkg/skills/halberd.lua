local sk = fk.CreateSkill {
  name = "#halberd_skill",
  attached_equip = "halberd",
}

sk:addEffect("targetmod", {
  extra_target_func = function(self, player, skill, card)
    if player:hasSkill(sk.name) and card and card.trueName == "slash" and
      not player:isKongcheng() then
      local cards = card:isVirtual() and card.subcards or {card.id}
      if #cards > 0 and table.every(player:getCardIds("h"), function(id)
        return table.contains(cards, id)
        end) then
        return 2
      end
    end
  end,
})
sk:addEffect(fk.CardUsing, {
  can_refresh = function(self, event, target, player, data)
    return target == player and player:hasSkill(sk.name) and data.card.trueName == "slash" and #data.tos > 1
  end,
  on_refresh = function(self, event, target, player, data)
    local room = player.room
    room:broadcastPlaySound("./packages/standard_cards/audio/card/halberd")
    room:setEmotion(player, "./packages/standard_cards/image/anim/halberd")
  end,
})

return sk
