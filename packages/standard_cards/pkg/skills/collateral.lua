local skill = fk.CreateSkill {
  name = "collateral_skill",
}

skill:addEffect("cardskill", {
  prompt = "#collateral_skill",
  mod_target_filter = function(self, player, to_select, selected, card, extra_data)
    if #selected == 0 then
      return to_select ~= player and #to_select:getEquipments(Card.SubtypeWeapon) > 0
    elseif #selected == 1 then
      return selected[1]:inMyAttackRange(to_select)
    end
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
    local from = effect.from
    local to = effect.to
    if to.dead then return end

    local giveWeapon = function ()
      if from.dead then return end
      local weapons = to:getEquipments(Card.SubtypeWeapon)
      if #weapons > 0 then
        room:moveCardTo(weapons, Card.PlayerHand, from, fk.ReasonGive, skill.name, nil, true, to.id)
      end
    end
    if #(effect.subTargets or {}) == 0 then
      giveWeapon()
      return
    end

    local prompt = "#collateral-slash:".. effect.from.id .. ":" .. effect.subTargets[1].id
    if #effect.subTargets > 1 then
      prompt = nil
    end
    local extra_data = {
      must_targets = table.map(effect.subTargets, Util.IdMapper),
      bypass_times = true,
    }
    local use = room:askToUseCard(to, { skill_name = "slash", pattern = "slash", prompt = prompt, cancelable = true, extra_data = extra_data, event_data = effect })
    if use then
      use.extraUse = true
      room:useCard(use)
    else
      giveWeapon()
    end
  end,
})

return skill
