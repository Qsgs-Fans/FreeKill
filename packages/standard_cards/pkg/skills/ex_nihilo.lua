local skill = fk.CreateSkill {
  name = "ex_nihilo_skill",
}

skill:addEffect("cardskill", {
  prompt = "#ex_nihilo_skill",
  mod_target_filter = Util.TrueFunc,
  can_use = Util.CanUseToSelf,
  on_effect = function(self, room, effect)
    if effect.to.dead then return end
    effect.to:drawCards(2, skill.name)
  end,
})

skill:addAI(Fk.Ltk.AI.newCardSkillStrategy {
  keep_value = 3.9,
  use_value = 10,
  use_priority = 9.3,

  on_effect = function(self, logic, effect)
    logic:drawCards(effect.to, 2, skill.name)
  end,
})

skill:addTest(function(room, me)
  local ex_nihilo = room:printCard("ex_nihilo")
  -- 服务端on_effect测试：能正常摸牌
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
