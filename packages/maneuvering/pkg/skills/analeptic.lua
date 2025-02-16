local skill = fk.CreateSkill {
  name = "analeptic_skill",
}

skill:addEffect("active", {
  prompt = "#analeptic_skill",
  max_turn_use_time = 1,
  mod_target_filter = Util.TrueFunc,
  can_use = function(self, player, card, extra_data)
    return not player:isProhibited(player, card) and
      ((extra_data and (extra_data.bypass_times or extra_data.analepticRecover)) or
      self:withinTimesLimit(player, Player.HistoryTurn, card, "analeptic", player))
  end,
  on_use = function(self, room, use)
    if #use.tos == 0 then
      use:addTarget(use.from)
    end

    if use.extra_data and use.extra_data.analepticRecover then
      use.extraUse = true
    end
  end,
  on_effect = function(self, room, effect)
    local to = effect.to
    if effect.extra_data and effect.extra_data.analepticRecover then
      if to:isWounded() and not to.dead then
        room:recover({
          who = to,
          num = 1,
          recoverBy = effect.from,
          card = effect.card,
        })
      end
    else
      to.drank = to.drank + 1 + ((effect.extra_data or {}).additionalDrank or 0)
      room:broadcastProperty(to, "drank")
    end
  end,
})
skill:addEffect(fk.PreCardUse, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    return target == player and data.card.trueName == "slash"
  end,
  on_trigger = function(self, event, target, player, data)
    local room = player.room
    data.additionalDamage = (data.additionalDamage or 0) + player.drank
    data.extra_data = data.extra_data or {}
    data.extra_data.drankBuff = player.drank
    player.drank = 0
    room:broadcastProperty(player, "drank")
  end,
})
skill:addEffect(fk.AfterTurnEnd, {
  global = true,
  can_trigger = Util.TrueFunc,
  on_trigger = function(self, event, target, player, data)
    local room = player.room
    for _, p in ipairs(room:getAlivePlayers(true)) do
      if p.drank > 0 then
        p.drank = 0
        room:broadcastProperty(p, "drank")
      end
    end
  end,
})

return skill
