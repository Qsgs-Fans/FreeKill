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

skill:addAI(nil, "__card_skill")
skill:addAI(nil, "default_card_skill")

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
