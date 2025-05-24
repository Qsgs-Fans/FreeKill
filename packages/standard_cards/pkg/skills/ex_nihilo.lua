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

skill:addAI({
  on_use = function(self, logic, effect)
    self.skill:onUse(logic, effect)
  end,
  on_effect = function(self, logic, effect)
    local target = effect.to
    logic:drawCards(target, 2, "ex_nihilo")
  end,
}, "__card_skill")

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
