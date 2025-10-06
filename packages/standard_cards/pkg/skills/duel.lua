local skill = fk.CreateSkill {
  name = "duel_skill",
}

skill:addEffect("cardskill", {
  prompt = "#duel_skill",
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
      local loopTimes = effect:getResponseTimes(currentResponser)

      local respond
      for i = 1, loopTimes do
        local params = { ---@type AskToUseCardParams
          skill_name = 'slash',
          pattern = 'slash',
          cancelable = true,
          event_data = effect
        }
        if loopTimes > 1 then
          params.prompt = "#AskForResponseMultiCard:::slash:"..i..":"..loopTimes
        end
        respond = room:askToResponse(currentResponser, params)
        if respond then
          room:responseCard(respond)
        else
          break
        end
      end

      if not respond then
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

skill:addAI({
  on_effect = function(self, logic, effect)
    local from, to = effect.from, effect.to
    if #table.filter(from:getHandlyIds(), function (id)
      return Fk:getCardById(id).trueName == "slash" and not from:prohibitResponse(Fk:getCardById(id))
    end) < #table.filter(to:getHandlyIds(), function (id)
      return Fk:getCardById(id).trueName == "slash" and not to:prohibitResponse(Fk:getCardById(id))
    end) then
      from, to = to, from
    end
    logic:damage({
      from = from,
      to = to,
      card = effect.card,
      damage = 1,
      damageType = fk.NormalDamage,
      skillName = skill.name
    })
  end,
}, "__card_skill")

return skill
