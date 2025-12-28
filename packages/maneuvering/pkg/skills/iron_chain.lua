local skill = fk.CreateSkill {
  name = "iron_chain_skill",
}

skill:addEffect("cardskill", {
  prompt = "#iron_chain_skill",
  min_target_num = 1,
  max_target_num = 2,
  mod_target_filter = Util.TrueFunc,
  target_filter = Util.CardTargetFilter,
  on_effect = function(self, room, effect)
    effect.to:setChainState(not effect.to.chained)
  end,
})

skill:addAI(Fk.Ltk.AI.newCardSkillStrategy {
  keep_value = 3.34,
  use_value = 5.4,
  use_priority = 9.1,

  on_effect = function(self, logic, effect)
    logic:setPlayerProperty(effect.to, "chained", not effect.to.chained)
  end,
})

return skill
