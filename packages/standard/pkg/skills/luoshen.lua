local luoshen = fk.CreateSkill{
  name = "luoshen",
}

luoshen:addEffect(fk.EventPhaseStart, {
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(luoshen.name) and player.phase == Player.Start
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    while true do
      local judge = {
        who = player,
        reason = luoshen.name,
        pattern = ".|.|spade,club",
      }
      room:judge(judge)
      if judge.card.color ~= Card.Black or player.dead or not room:askForSkillInvoke(player, luoshen.name) then
        break
      end
    end
  end,
})
luoshen:addEffect(fk.FinishJudge, {
  can_trigger = function(self, event, target, player, data)
    return target == player and not player.dead and data.reason == luoshen.name and data.card.color == Card.Black and
      player.room:getCardArea(data.card) == Card.Processing
  end,
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player, data)
    player.room:obtainCard(player.id, data.card, false, fk.ReasonJustMove, nil, luoshen.name)
  end,
})

luoshen:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, "luoshen")
  end)
  local red = table.find(room.draw_pile, function(cid)
    return Fk:getCardById(cid).color == Card.Red
  end)
  local blacks = table.filter(room.draw_pile, function(cid)
    return Fk:getCardById(cid).color == Card.Black
  end)
  local rnd = 5
  FkTest.setNextReplies(me, { "1", "1", "1", "1", "1", "1" }) -- 除了第一个1以外后面全是潜在的“重复流程”
  -- 每次往红牌顶上塞若干个黑牌
  FkTest.runInRoom(function()
    room:throwCard(me:getCardIds("h"), nil, me, me)
    -- 控顶
    room:moveCardTo(red, Card.DrawPile)
    if rnd > 0 then room:moveCardTo(table.slice(blacks, 1, rnd + 1), Card.DrawPile) end

    local data = { ---@type TurnDataSpec
      who = me,
      reason = "game_rule",
      phase_table = { Player.Start }
    }
    GameEvent.Turn:create(TurnData:new(data)):exec()
  end)
  lu.assertEquals(#me:getCardIds("h"), rnd)
end)

return luoshen
