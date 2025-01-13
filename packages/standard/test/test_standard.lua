TestStandard = { setup = InitRoom, tearDown = ClearRoom }

function TestStandard:testJianxiong()
  local room = LRoom
  local me, comp2 = room.players[1], room.players[2] ---@type ServerPlayer, ServerPlayer
  RunInRoom(function() room:handleAddLoseSkills(me, "jianxiong") end)

  local slash = Fk:getCardById(1)
  SetNextReplies(me, { "__cancel", "1" })
  RunInRoom(function()
    room:useCard{
      from = comp2.id,
      tos = { { me.id } },
      card = slash,
    }
  end)
  -- p(me:toJsonObject())
  lu.assertEquals(me:getCardIds("h")[1], 1)
end

function TestStandard:testFanKui()
  local room = LRoom
  local me, comp2 = room.players[1], room.players[2] ---@type ServerPlayer, ServerPlayer
  RunInRoom(function() room:handleAddLoseSkills(me, "fankui") end)

  -- 空牌的情况
  local slash = Fk:getCardById(1)
  SetNextReplies(me, { "__cancel" })
  RunInRoom(function()
    room:useCard{
      from = comp2.id,
      tos = { { me.id } },
      card = slash,
    }
  end)
  lu.assertEquals(#me:getCardIds("h"), 0)

  -- 有牌的情况
  SetNextReplies(me, { "__cancel", "1", "3" })
  RunInRoom(function()
    room:obtainCard(comp2, { 3 })
    room:useCard{
      from = comp2.id,
      tos = { { me.id } },
      card = slash,
    }
  end)
  lu.assertEquals(me:getCardIds("h")[1], 3)
end

function TestStandard:testGangLie()
  local room = LRoom ---@type Room
  local me, comp2 = room.players[1], room.players[2] ---@type ServerPlayer, ServerPlayer
  RunInRoom(function()
    room:handleAddLoseSkills(me, "ganglie")
  end)

  -- 第一段：测试我发动刚烈，AI点取消
  local slash = Fk:getCardById(1)
  SetNextReplies(me, { "__cancel", "1" })
  SetNextReplies(comp2, { "__cancel" })
  local origin_hp = comp2.hp
  RunInRoom(function()
    room:obtainCard(comp2, { 3, 4 })

    room:moveCardTo(2, Card.DrawPile) -- 控顶
    room:useCard{
      from = comp2.id,
      tos = { { me.id } },
      card = slash,
    }
  end)
  lu.assertEquals(comp2.hp, origin_hp - 1)
  lu.assertEquals(#comp2:getCardIds("h"), 2)

  -- 第二段：测试我发动刚烈，AI丢二
  origin_hp = comp2.hp
  SetNextReplies(me, { "__cancel", "1" })
  SetNextReplies(comp2, { json.encode {
    card = { skill = "discard_skill", subcards = { 3, 4 } },
    targets = {}
  } })
  RunInRoom(function()
    room:moveCardTo(2, Card.DrawPile) -- 再控顶
    room:useCard{
      from = comp2.id,
      tos = { { me.id } },
      card = slash,
    }
  end)
  lu.assertEquals(comp2.hp, origin_hp)
  lu.assertEquals(#comp2:getCardIds("h"), 0)

  -- 第三段：测试我发动刚烈，判定判红桃
  origin_hp = comp2.hp
  SetNextReplies(me, { "__cancel", "1" })
  SetNextReplies(comp2, { "__cancel" })
  RunInRoom(function()
    room:obtainCard(comp2, { 3, 4 })

    room:moveCardTo(24, Card.DrawPile) -- 控顶
    room:useCard{
      from = comp2.id,
      tos = { { me.id } },
      card = slash,
    }
  end)
  lu.assertEquals(comp2.hp, origin_hp)
  lu.assertEquals(#comp2:getCardIds("h"), 2)
end

function TestStandard:testLuoYi()
  local room = LRoom ---@type Room
  local me, comp2 = room.players[1], room.players[2] ---@type ServerPlayer, ServerPlayer
  RunInRoom(function()
    room:handleAddLoseSkills(me, "luoyi")
  end)
  local slash = Fk:getCardById(1)
  SetNextReplies(me, { "1", json.encode {
    card = 1,
    targets = { comp2.id }
  } })
  SetNextReplies(comp2, { "__cancel" })

  local origin_hp = comp2.hp
  RunInRoom(function()
    room:obtainCard(me, 1)
    GameEvent.Turn:create(me):exec()
  end)
  -- p(me:getCardIds("h"))
  lu.assertEquals(#me:getCardIds("h"), 1)
  lu.assertEquals(comp2.hp, origin_hp - 2)

  -- 测标记持续时间
  origin_hp = comp2.hp
  RunInRoom(function()
    room:useCard{
      from = me.id,
      tos = { { comp2.id } },
      card = slash,
    }
  end)
  lu.assertEquals(comp2.hp, origin_hp - 1)
end

function TestStandard:testMashu()
  local room = LRoom ---@type Room
  local me = room.players[1] ---@type ServerPlayer

  local origin = table.map(room:getOtherPlayers(me), function(other) return me:distanceTo(other) end)

  RunInRoom(function()
    room:handleAddLoseSkills(me, "mashu")
  end)

  for i, other in ipairs(room:getOtherPlayers(me)) do
    lu.assertEquals(me:distanceTo(other), math.max(origin[i] - 1, 1))
  end
end
