local skill = fk.CreateSkill {
  name = "duel_skill",
}

skill:addEffect("active", {
  prompt = "#duel_skill",
  can_use = Util.CanUse,
  mod_target_filter = function(self, player, to_select, selected, card)
    return to_select ~= player
  end,
  target_filter = Util.CardTargetFilter,
  target_num = 1,
  on_effect = function(self, room, effect)
    local to = effect.to
    local from = effect.from
    local responsers = { to, from }
    local currentTurn = 1
    local currentResponser = to

    while currentResponser:isAlive() do
      local loopTimes = 1
      if effect.fixedResponseTimes then
        local canFix = currentResponser == to
        if effect.fixedAddTimesResponsors then
          canFix = table.contains(effect.fixedAddTimesResponsors, currentResponser.id)
        end

        if canFix then
          if type(effect.fixedResponseTimes) == 'table' then
            loopTimes = effect.fixedResponseTimes["slash"] or 1
          elseif type(effect.fixedResponseTimes) == 'number' then
            loopTimes = effect.fixedResponseTimes
          end
        end
      end

      local cardResponded
      for i = 1, loopTimes do
        cardResponded = room:askForResponse(currentResponser, 'slash', nil, nil, true, nil, effect)
        if cardResponded then
          room:responseCard({
            from = currentResponser.id,
            card = cardResponded,
            responseToEvent = effect,
          })
        else
          break
        end
      end

      if not cardResponded then
        break
      end

      currentTurn = currentTurn % 2 + 1
      currentResponser = responsers[currentTurn]
    end

    if currentResponser:isAlive() then
      room:damage({
        from = responsers[currentTurn % 2 + 1],
        to = currentResponser,
        card = effect.card,
        damage = 1,
        damageType = fk.NormalDamage,
        skillName = skill.name,
      })
    end
  end,
})

return skill
