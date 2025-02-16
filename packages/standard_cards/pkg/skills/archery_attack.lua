local skill = fk.CreateSkill {
  name = "archery_attack_skill",
}

skill:addEffect("active", {
  prompt = "#archery_attack_skill",
  can_use = Util.AoeCanUse,
  on_use = function (self, room, cardUseEvent)
    return Util.AoeCardOnUse(self, cardUseEvent.from, cardUseEvent, false)
  end,
  mod_target_filter = function(self, player, to_select, selected, card, distance_limited)
    return to_select ~= player
  end,
  on_effect = function(self, room, effect)
    local loopTimes = 1
    if effect.fixedResponseTimes and table.contains(effect.fixedAddTimesResponsors or {}, effect.to.id) then
      if type(effect.fixedResponseTimes) == 'table' then
        loopTimes = effect.fixedResponseTimes["jink"] or 1
      elseif type(effect.fixedResponseTimes) == 'number' then
        loopTimes = effect.fixedResponseTimes
      end
    end
    local cardResponded
    for i = 1, loopTimes do
      cardResponded = room:askForResponse(effect.to, 'jink', nil, nil, true, nil, effect)
      if cardResponded then
        room:responseCard({
          from = effect.to.id,
          card = cardResponded,
          responseToEvent = effect,
        })
      else
        room:damage({
          from = effect.from,
          to = effect.to,
          card = effect.card,
          damage = 1,
          damageType = fk.NormalDamage,
          skillName = skill.name,
        })
      end
      if effect.to.dead then break end
    end
  end,
})

skill:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:useCard {
      from = me,
      card = Fk:cloneCard("archery_attack"),
    }
  end)
  lu.assertEquals(me.hp, 4)
  lu.assertEquals(room.players[2].hp, 3)
  lu.assertEquals(room.players[3].hp, 3)
end)

return skill
