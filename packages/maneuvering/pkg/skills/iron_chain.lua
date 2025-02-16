local skill = fk.CreateSkill {
  name = "iron_chain_skill",
}

skill:addEffect("active", {
  prompt = "#iron_chain_skill",
  can_use = Util.CanUse,
  min_target_num = 1,
  max_target_num = 2,
  mod_target_filter = Util.TrueFunc,
  target_filter = Util.CardTargetFilter,
  on_effect = function(self, room, effect)
    effect.to:setChainState(not effect.to.chained)
  end,
})

return skill
