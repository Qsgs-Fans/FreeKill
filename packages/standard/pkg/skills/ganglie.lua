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
    if judge:matchPattern() and from and not from.dead then
      local discards = room:askToDiscard(from, {
        min_num = 2,
        max_num = 2,
        include_equip = false,
        skill_name = ganglie.name,
        cancelable = true,
      })
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

ganglie:addAI({
  think = function(self, ai)
    local cards = ai:getEnabledCards()
    if #cards < 2 then return "" end

    local cancel_val = ai:getBenefitOfEvents(function(logic)
      logic:damage{
        from = ai.room.logic:getCurrentEvent().data[2],
        to = ai.player,
        damage = 1,
        skillName = self.skill.name,
      }
    end)
    local to_discard, discard_val = ai:askToDiscard({
      min_num = 2,
      max_num = 2,
      skill_name = self.skill.name,
      cancelable = false,
    })

    if discard_val > cancel_val then
      return { cards = to_discard }
    else
      return ""
    end
  end,

  think_skill_invoke = function(self, ai, skill_name, prompt)
    ---@type DamageData
    local dmg = ai.room.logic:getCurrentEvent().data
    local from = dmg.from
    if not from or ai:isFriend(dmg.from) then return false end
    local dmg_val = ai:getBenefitOfEvents(function(logic)
      logic:damage{
        from = ai.player,
        to = from,
        damage = 1,
        skillName = self.skill.name,
      }
    end)
    local discard_val = ai:getBenefitOfEvents(function(logic)
      local cards = from:getCardIds("h")
      if #cards < 2 then
        logic.benefit = -1
        return
      end
      logic:throwCard(table.random(cards, 2), self.skill.name, from, from)
    end)
    if dmg_val > 0 or discard_val > 0 then
      return true
    end
    return false
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
  FkTest.setNextReplies(comp2, { {
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
