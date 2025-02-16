local ganglie = fk.CreateSkill({
  name = "ganglie",
})

ganglie:addEffect(fk.Damaged, {
  anim_type = "masochism",
  on_use = function(self, event, target, player, data)
    local room = player.room
    local from = data.from
    if from and not from.dead then room:doIndicate(player.id, {from.id}) end
    local judge = {
      who = player,
      reason = ganglie.name,
      pattern = ".|.|^heart",
    }
    room:judge(judge)
    if judge.card.suit ~= Card.Heart and from and not from.dead then
      local discards = room:askForDiscard(from, 2, 2, false, ganglie.name, true)
      if #discards == 0 then
        room:damage{
          from = player,
          to = from,
          damage = 1,
          skillName = ganglie.name,
        }
      end
    end
  end,
})

ganglie:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, "ganglie")
  end)

  -- 第一段：测试我发动刚烈，AI点取消
  local slash = Fk:getCardById(1)
  FkTest.setNextReplies(me, { "__cancel", "1" })
  FkTest.setNextReplies(comp2, { "__cancel" })
  local origin_hp = comp2.hp
  FkTest.runInRoom(function()
    room:obtainCard(comp2, { 3, 4 })

    room:moveCardTo(2, Card.DrawPile) -- 控顶
    room:useCard{
      from = comp2,
      tos = { me },
      card = slash,
    }
  end)
  lu.assertEquals(comp2.hp, origin_hp - 1)
  lu.assertEquals(#comp2:getCardIds("h"), 2)

  -- 第二段：测试我发动刚烈，AI丢二
  origin_hp = comp2.hp
  FkTest.setNextReplies(me, { "__cancel", "1" })
  FkTest.setNextReplies(comp2, { json.encode {
    card = { skill = "discard_skill", subcards = { 3, 4 } },
    targets = {}
  } })
  FkTest.runInRoom(function()
    room:moveCardTo(2, Card.DrawPile) -- 再控顶
    room:useCard{
      from = comp2,
      tos = { me },
      card = slash,
    }
  end)
  lu.assertEquals(comp2.hp, origin_hp)
  lu.assertEquals(#comp2:getCardIds("h"), 0)

  -- 第三段：测试我发动刚烈，判定判红桃
  origin_hp = comp2.hp
  FkTest.setNextReplies(me, { "__cancel", "1" })
  FkTest.setNextReplies(comp2, { "__cancel" })
  FkTest.runInRoom(function()
    room:obtainCard(comp2, { 3, 4 })

    room:moveCardTo(24, Card.DrawPile) -- 控顶
    room:useCard{
      from = comp2,
      tos = { me },
      card = slash,
    }
  end)
  lu.assertEquals(comp2.hp, origin_hp)
  lu.assertEquals(#comp2:getCardIds("h"), 2)
end)

return ganglie
