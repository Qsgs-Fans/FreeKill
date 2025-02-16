local luoyi = fk.CreateSkill {
  name = "luoyi",
}

luoyi:addEffect(fk.DrawNCards, {
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(luoyi.name) and data.n > 0
  end,
  on_use = function(self, event, target, player, data)
    data.n = data.n - 1
  end,
})

luoyi:addEffect(fk.DamageCaused, {
  can_trigger = function(self, event, target, player, data)
    return player:usedSkillTimes(luoyi.name, Player.HistoryTurn) > 0 and
      data.card and (data.card.trueName == "slash" or data.card.name == "duel") and data.by_user
  end,
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player, data)
    local room = player.room
    player:broadcastSkillInvoke("luoyi")
    room:notifySkillInvoked(player, "luoyi")
    data.damage = data.damage + 1
  end,
})

luoyi:addTest(function(room, me)
  local comp2 = room.players[2] ---@type ServerPlayer, ServerPlayer
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, luoyi.name)
  end)
  local slash = Fk:getCardById(1)
  FkTest.setNextReplies(me, { "1", json.encode {
    card = 1,
    targets = { comp2.id }
  } })
  FkTest.setNextReplies(comp2, { "__cancel" })

  local origin_hp = comp2.hp
  FkTest.runInRoom(function()
    room:obtainCard(me, 1)
    local data = { ---@type TurnDataSpec
      who = me,
      reason = "game_rule",
    }
    GameEvent.Turn:create(TurnData:new(data)):exec()
  end)
  -- p(me:getCardIds("h"))
  lu.assertEquals(#me:getCardIds("h"), 1)
  lu.assertEquals(comp2.hp, origin_hp - 2)

  -- 测标记持续时间
  origin_hp = comp2.hp
  FkTest.runInRoom(function()
    room:useCard{
      from = me,
      tos = { comp2 },
      card = slash,
    }
  end)
  lu.assertEquals(comp2.hp, origin_hp - 1)
end)

return luoyi
