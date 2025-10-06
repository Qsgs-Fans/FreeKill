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
    player.room:obtainCard(player, data.card, true, fk.ReasonJustMove, player, jianxiong.name)
  end,
})

jianxiong:addAI({
  think_skill_invoke = function(self, ai, skill_name, prompt)
    ---@type DamageData
    local dmg = ai.room.logic:getCurrentEvent().data
    local player = ai.player
    local card = dmg.card
    if not card or player.room:getCardArea(card) ~= Card.Processing then return false end
    local val = ai:getBenefitOfEvents(function(logic)
      logic:obtainCard(player, card, true, fk.ReasonJustMove, player, jianxiong.name)
    end)
    if val > 0 then
      return true
    end
    return false
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
  lu.assertEquals(me:getCardIds("h")[1], 1)
end)

return jianxiong
