local kurou = fk.CreateSkill {
  name = "kurou",
}

kurou:addEffect("active", {
  anim_type = "drawcard",
  prompt = "#kurou-active",
  card_filter = Util.FalseFunc,
  on_use = function(self, room, effect)
    local from = effect.from
    room:loseHp(from, 1, kurou.name)
    if from:isAlive() then
      from:drawCards(2, kurou.name)
    end
  end
})

kurou:addTest(function(room, me)
  for i = 1, 3, 1 do
    FkTest.setNextReplies(me, {
      json.encode {
        card = { skill = "kurou", subcards = {} },
      },
      "",
    })
    FkTest.runInRoom(function()
      room:handleAddLoseSkills(me, "kurou")
      local data = { ---@type TurnDataSpec
        who = me,
        reason = "game_rule",
        phase_table = { Player.Play }
      }
      GameEvent.Turn:create(TurnData:new(data)):exec()
    end)
    lu.assertEquals(#me:getCardIds("h"), 2 * i)
    lu.assertEquals(me.hp, 4 - i)
  end
  FkTest.setNextReplies(me, {
    json.encode {
      card = { skill = "kurou", subcards = {} },
    },
    "",
  })
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, "kurou")
    local data = { ---@type TurnDataSpec
      who = me,
      reason = "game_rule",
      phase_table = { Player.Play }
    }
    GameEvent.Turn:create(TurnData:new(data)):exec()
  end)
  lu.assertEquals(me.hp, 0)
  lu.assertEquals(#me:getCardIds("h"), 6)
end)

return kurou
