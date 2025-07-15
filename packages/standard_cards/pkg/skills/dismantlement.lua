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

skill:addAI({
  on_effect = function(self, logic, effect)
    local from = effect.from
    local to = effect.to
    if from.dead or to.dead or to:isAllNude() then return end
    local _, val = self:thinkForCardChosen(from.ai, to, "hej")
    logic.benefit = logic.benefit + val
  end,

  think_card_chosen = function(self, ai, target, flag, prompt)
    local ret, benefit = ai:askToChooseCards({
      cards = target:getCardIds("hej"),
      skill_name = self.skill.name,
      min = 1,
      max = 1,
      data = {
        to_place = Card.DiscardPile,
        reason = fk.ReasonDiscard,
        proposer = ai.player,
      },
    })
    return ret[1], benefit
  end,
}, "__card_skill")

return skill
