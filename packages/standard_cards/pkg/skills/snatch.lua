local skill = fk.CreateSkill {
  name = "snatch_skill",
}

skill:addEffect("cardskill", {
  prompt = "#snatch_skill",
  distance_limit = 1,
  mod_target_filter = function(self, player, to_select, selected, card, extra_data)
    return to_select ~= player and
      not (to_select:isAllNude() or
        (not (extra_data and extra_data.bypass_distances) and not self:withinDistanceLimit(player, false, card, to_select)))
  end,
  target_filter = Util.CardTargetFilter,
  target_num = 1,
  on_effect = function(self, room, effect)
    if effect.from.dead or effect.to.dead or effect.to:isAllNude() then return end
    local cid = room:askToChooseCard(effect.from, { target = effect.to, flag = "hej", skill_name = skill.name })
    room:obtainCard(effect.from, cid, false, fk.ReasonPrey, effect.from, skill.name)
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
        to_place = Card.PlayerHand,
        target = ai.player,
        reason = fk.ReasonPrey,
        proposer = ai.player,
      },
    })
    return ret[1], benefit
  end,
}, "__card_skill")

skill:addTest(function(room, me)
  local snatch = Fk:cloneCard("snatch")
  FkTest.runInRoom(function()
    room.players[3]:drawCards(1)
  end)
  lu.assertIsTrue(table.every(room:getOtherPlayers(me, false), function (other)
    return not me:canUseTo(snatch, other)
  end))
  lu.assertIsTrue(me:canUseTo(snatch, room.players[3], {bypass_distances = true}))

  local comp2 = room.players[2]
  FkTest.setNextReplies(me, { 1 })
  FkTest.runInRoom(function()
    room:obtainCard(comp2, 1)
    room:useCard {
      from = me,
      tos = { comp2 },
      card = snatch,
    }
  end)
  lu.assertEquals(me.player_cards[Player.Hand], { 1 })
end)

return skill
