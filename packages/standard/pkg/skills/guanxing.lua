local guanxing = fk.CreateSkill({
  name = "guanxing",
})

guanxing:addEffect(fk.EventPhaseStart, {
  anim_type = "control",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(guanxing.name) and player.phase == Player.Start
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    room:askForGuanxing(player, room:getNCards(math.min(5, #room.alive_players)))
  end,
})

return guanxing
