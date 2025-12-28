local skill = fk.CreateSkill {
  name = "dismantlement_skill",
}

skill:addEffect("cardskill", {
  prompt = "#dismantlement_skill",
  target_num = 1,
  mod_target_filter = function(self, player, to_select, selected, card)
    return to_select ~= player and not to_select:isAllNude()
  end,
  target_filter = Util.CardTargetFilter,
  on_effect = function(self, room, effect)
    if effect.from.dead or effect.to.dead or effect.to:isAllNude() then return end
    local cid = room:askToChooseCard(effect.from, { target = effect.to, flag = "hej", skill_name = skill.name })
    room:throwCard({cid}, skill.name, effect.to, effect.from)
  end,
})

skill:addAI(Fk.Ltk.AI.newCardSkillStrategy {
  keep_value = 3.44,
  use_value = 5.6,
  use_priority = 4.4,

  on_effect = function(self, logic, effect)
    local ret, benefit = effect.from.ai:askToChooseCards({
      cards = effect.to:getCardIds("hej"),
      skill_name = skill.name,
      data = {
        to_place = Card.DiscardPile,
        reason = fk.ReasonDiscard,
        proposer = effect.from,
      },
    })
    logic:throwCard(ret[1], skill.name, effect.to, effect.from)
  end,
  }
)

return skill
