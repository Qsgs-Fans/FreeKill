local jianxiong = fk.CreateSkill{
  name = "jianxiong",
}

jianxiong:addEffect(fk.Damaged, {
  anim_type = "masochism",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(jianxiong.name) and
      data.card and player.room:getCardArea(data.card) == Card.Processing
  end,
  on_use = function(self, event, target, player, data)
    player.room:obtainCard(player.id, data.card, true, fk.ReasonJustMove)
  end,
})

jianxiong:addTest(function(room, me)
  local comp2 = room.players[2] ---@type ServerPlayer, ServerPlayer
  FkTest.runInRoom(function() room:handleAddLoseSkills(me, jianxiong.name) end)

  local slash = Fk:getCardById(1)
  FkTest.setNextReplies(me, { "__cancel", "1" })
  FkTest.runInRoom(function()
    room:useCard{
      from = comp2,
      tos = { me },
      card = slash,
    }
  end)
  -- p(me:toJsonObject())
  lu.assertEquals(me:getCardIds("h")[1], 1)
end)

return jianxiong
