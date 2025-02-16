local skill = fk.CreateSkill {
  name = "ex_nihilo_skill",
}

skill:addEffect("active", {
  prompt = "#ex_nihilo_skill",
  mod_target_filter = Util.TrueFunc,
  can_use = function(self, player, card)
    return not player:isProhibited(player, card)
  end,
  on_use = function(self, room, cardUseEvent)
    ---@cast cardUseEvent -SkillUseData
    if #cardUseEvent.tos == 0 then
      cardUseEvent:addTarget(cardUseEvent.from)
    end
  end,
  on_effect = function(self, room, effect)
    if effect.to.dead then return end
    effect.to:drawCards(2, skill.name)
  end,
})

skill:addTest(function(room, me)
  local ex_nihilo = room:printCard("ex_nihilo")
  -- 服务端on_effect测试：能正常回血
  FkTest.runInRoom(function()
    room:useCard{
      from = me,
      tos = { me },
      card = ex_nihilo,
    }
  end)
  lu.assertEquals(#me:getCardIds("h"), 2)
end)

return skill
