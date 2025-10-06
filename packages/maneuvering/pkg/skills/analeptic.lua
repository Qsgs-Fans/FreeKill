local analepticSkill = fk.CreateSkill {
  name = "analeptic_skill",
}

analepticSkill:addEffect("cardskill", {
  prompt = function(self, _, _, _, extra_data)
    return extra_data.analepticRecover and "#peach_skill" or "#analeptic_skill"
  end,
  max_turn_use_time = 1,
  mod_target_filter = Util.TrueFunc,
  can_use = function(self, player, card, extra_data)
    return Util.CanUseToSelf(self, player, card, extra_data) and
      ((extra_data and (extra_data.bypass_times or extra_data.analepticRecover)) or
      self:withinTimesLimit(player, Player.HistoryTurn, card, "analeptic", player))
  end,
  on_use = function(self, room, use)
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

analepticSkill:addEffect(fk.PreCardUse, {
  global = true,
  can_refresh = function(self, event, target, player, data)
    return target == player and data.card.trueName == "slash" and player.drank > 0
  end,
  on_refresh = function(self, event, target, player, data)
    local room = player.room
    data.additionalDamage = (data.additionalDamage or 0) + player.drank
    data.extra_data = data.extra_data or {}
    data.extra_data.drankBuff = player.drank
    player.drank = 0
    room:broadcastProperty(player, "drank")
  end,
})

analepticSkill:addEffect(fk.TurnEnd, {
  global = true,
  late_refresh = true,
  can_refresh = function(self, event, target, player, data)
    return player.drank > 0
  end,
  on_refresh = function(self, event, target, player, data)
    player.drank = 0
    player.room:broadcastProperty(player, "drank")
  end,
})

analepticSkill:addAI(nil, "__card_skill")
analepticSkill:addAI(nil, "default_card_skill")

analepticSkill:addTest(function(room, me)
  local analeptic = room:printCard("analeptic")
  local comp2 = room.players[2]

  -- test1: 喝酒后等到回合结束，酒状态解除
  FkTest.runInRoom(function()
    room:useCard {
      from = me,
      card = analeptic,
      tos = {},
    }
  end)
  lu.assertEquals(me.drank, 1)
  FkTest.runInRoom(function()
    GameEvent.Turn:create(TurnData:new(me, "game_rule", { Player.Finish })):exec()
  end)
  lu.assertEquals(me.drank, 0)

  -- test2: 喝酒加伤害
  FkTest.runInRoom(function()
    room:useCard {
      from = me,
      card = analeptic,
      tos = {},
    }
    room:useCard {
      from = me,
      tos = { comp2 },
      card = Fk:cloneCard("slash")
    }
  end)
  lu.assertEquals(me.drank, 0)
  lu.assertEquals(comp2.hp, 2)

  -- test3: 濒死时喝酒，改为回血
  FkTest.setNextReplies(me, { {
    card = analeptic.id,
  } })
  FkTest.runInRoom(function()
    room:obtainCard(me, analeptic)
    room:loseHp(me, 4)
  end)
  lu.assertEquals(me.hp, 1)
end)

return analepticSkill
