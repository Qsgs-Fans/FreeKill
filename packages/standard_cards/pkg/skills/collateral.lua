local skill = fk.CreateSkill {
  name = "collateral_skill",
}

skill:addEffect("active", {
  prompt = "#collateral_skill",
  can_use = Util.CanUse,
  mod_target_filter = function(self, player, to_select, selected, card, distance_limited)
    return to_select ~= player and #to_select:getEquipments(Card.SubtypeWeapon) > 0
  end,
  target_filter = function(self, player, to_select, selected, _, card, extra_data)
    if #selected >= 2 then
      return false
    elseif #selected == 0 then
      return Util.CardTargetFilter(self, player, to_select, selected, _, card, extra_data)
    else
      return selected[1]:inMyAttackRange(to_select)
    end
  end,
  target_num = 2,
  on_use = function(self, room, cardUseEvent)
    local tos = table.simpleClone(cardUseEvent.tos)
    cardUseEvent:removeAllTargets()
    for i = 1, #tos, 2 do
      cardUseEvent:addTarget(tos[i], { tos[i + 1] })
    end
  end,
  on_effect = function(self, room, effect)
    local to = effect.to
    if to.dead then return end
    local prompt = "#collateral-slash:"..effect.from..":"..effect.subTargets[1]
    if #effect.subTargets > 1 then
      prompt = nil
    end
    local extra_data = {
      must_targets = effect.subTargets,
      bypass_times = true,
    }
    local use = room:askForUseCard(to, "slash", nil, prompt, nil, extra_data, effect)
    if use then
      use.extraUse = true
      room:useCard(use)
    else
      local from = effect.from
      if from.dead then return end
      local weapons = to:getEquipments(Card.SubtypeWeapon)
      if #weapons > 0 then
        room:moveCardTo(weapons, Card.PlayerHand, from, fk.ReasonGive, skill.name, nil, true, to.id)
      end
    end
  end,
})

return skill
