local skill = fk.CreateSkill {
  name = "dismantlement_skill",
}

skill:addEffect("active", {
  prompt = "#dismantlement_skill",
  can_use = Util.CanUse,
  target_num = 1,
  mod_target_filter = function(self, player, to_select, selected, card)
    return to_select ~= player and not to_select:isAllNude()
  end,
  target_filter = Util.CardTargetFilter,
  on_effect = function(self, room, effect)
    if effect.from.dead or effect.to.dead or effect.to:isAllNude() then return end
    local cid = room:askForCardChosen(effect.from, effect.to, "hej", skill.name)
    room:throwCard({cid}, skill.name, effect.to, effect.from)
  end,
})

return skill
