local skill = fk.CreateSkill {
  name = "supply_shortage_skill",
}

skill:addEffect("cardskill", {
  prompt = "#supply_shortage_skill",
  distance_limit = 1,
  mod_target_filter = function(self, player, to_select, selected, card, extra_data)
    return to_select ~= player and not (not (extra_data and extra_data.bypass_distances) and
      not self:withinDistanceLimit(player, false, card, to_select))
  end,
  target_filter = Util.CardTargetFilter,
  target_num = 1,
  on_effect = function(self, room, effect)
    local to = effect.to
    local judge = {
      who = to,
      reason = "supply_shortage",
      pattern = ".|.|^club",
    }
    room:judge(judge)
    if judge:matchPattern() then
      to:skip(Player.Draw)
    end
    self:onNullified(room, effect)
  end,
  on_nullified = function(self, room, effect)
    room:moveCards{
      ids = room:getSubcardsByRule(effect.card, { Card.Processing }),
      toArea = Card.DiscardPile,
      moveReason = fk.ReasonUse,
    }
  end,
})

skill:addAI(nil, "__card_skill")

return skill
