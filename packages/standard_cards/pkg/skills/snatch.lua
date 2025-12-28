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

skill:addAI(Fk.Ltk.AI.newCardSkillStrategy {
  keep_value = 3.46,
  use_value = 9,
  use_priority = 4.3,

  on_effect = function(self, logic, effect)
    local ret, benefit = effect.from.ai:askToChooseCards({
      cards = effect.to:getCardIds("hej"),
      skill_name = skill.name,
      data = {
        to_place = Card.PlayerHand,
        target = effect.from,
        reason = fk.ReasonPrey,
        proposer = effect.from,
      },
    })
    logic:obtainCard(effect.from, ret[1], false, fk.ReasonPrey, effect.from, skill.name)
  end,
  }
)

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
