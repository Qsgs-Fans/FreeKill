local luoyi = fk.CreateSkill {
  name = "luoyi",
}

luoyi:addEffect(fk.DrawNCards, {
  anim_type = "offensive",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(luoyi.name) and data.n > 0
  end,
  on_use = function(self, event, target, player, data)
    data.n = data.n - 1
  end,
})

luoyi:addEffect(fk.DamageCaused, {
  anim_type = "offensive",
  is_delay_effect = true,
  can_trigger = function(self, event, target, player, data)
    return player:usedSkillTimes(luoyi.name, Player.HistoryTurn) > 0 and target == player and
      data.card and (data.card.trueName == "slash" or data.card.name == "duel") and data.by_user
  end,
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player, data)
    data:changeDamage(1)
  end,
})

luoyi:addTest(function(room, me)
  local comp2 = room.players[2] ---@type ServerPlayer, ServerPlayer
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, luoyi.name)
  end)
  local slash = Fk:getCardById(1)
  FkTest.setNextReplies(me, { "1", {
    card = 1,
    targets = { comp2.id }
  } })
  FkTest.setNextReplies(comp2, { "__cancel" })

  local origin_hp = comp2.hp
  FkTest.runInRoom(function()
    room:obtainCard(me, 1)
    GameEvent.Turn:create(TurnData:new(me, "game_rule")):exec()
  end)
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
