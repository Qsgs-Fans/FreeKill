local skill = fk.CreateSkill {
  name = "savage_assault_skill",
}

skill:addEffect("cardskill", {
  prompt = "#savage_assault_skill",
  can_use = Util.AoeCanUse,
  on_use = function (self, room, cardUseEvent)
    ---@cast cardUseEvent -SkillUseData
    return Util.AoeCardOnUse(self, cardUseEvent.from, cardUseEvent, false)
  end,
  mod_target_filter = function(self, player, to_select, selected, card, distance_limited)
    return to_select ~= player
  end,
  on_effect = function(self, room, effect)
    local loopTimes = effect:getResponseTimes()
    local respond
    for i = 1, loopTimes do
      local params = { ---@type AskToUseCardParams
        skill_name = 'slash',
        pattern = 'slash',
        cancelable = true,
        event_data = effect
      }
      if loopTimes > 1 then
        params.prompt = "#AskForResponseMultiCard:::slash:"..i..":"..loopTimes
      end
      respond = room:askToResponse(effect.to, params)
      if respond then
        room:responseCard(respond)
      else
        room:damage({
          from = effect.from,
          to = effect.to,
          card = effect.card,
          damage = 1,
          damageType = fk.NormalDamage,
          skillName = skill.name,
        })
        break
      end
      if effect.to.dead then break end
    end
  end,
})

skill:addAI(nil, "__card_skill")
skill:addAI(nil, "default_card_skill")

skill:addTest(function(room, me)
  local comp2 = room.players[2]
  local card = room:printCard("slash")
  FkTest.setNextReplies(comp2, {json.encode {
    card = card.id,
    targets = { }
  }})
  FkTest.runInRoom(function()
    room:obtainCard(comp2, card, true)
    room:useCard {
      from = me,
      card = Fk:cloneCard("savage_assault"),
      tos = {}
    }
  end)
  lu.assertEquals(me.hp, 4)
  lu.assertEquals(comp2.hp, 4)
  lu.assertEquals(room.players[3].hp, 3)
  lu.assertEquals(room.players[4].hp, 3)
end)

return skill
