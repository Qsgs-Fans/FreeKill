local qingnang = fk.CreateSkill {
  name = "qingnang",
}

qingnang:addEffect("active", {
  anim_type = "support",
  prompt = "#qingnang-active",
  max_phase_use_time = 1,
  card_filter = function(self, player, to_select, selected)
    return #selected == 0 and table.contains(player:getCardIds("h"), to_select) and not player:prohibitDiscard(to_select)
  end,
  target_filter = function(self, player, to_select, selected)
    return #selected == 0 and to_select:isWounded()
  end,
  target_num = 1,
  card_num = 1,
  on_use = function(self, room, effect)
    local from = effect.from
    local to = effect.tos[1]
    room:throwCard(effect.cards, qingnang.name, from, from)
    if to:isAlive() and to:isWounded() then
      room:recover({
        who = to,
        num = 1,
        recoverBy = from,
        skillName = qingnang.name,
      })
    end
  end,
})

qingnang:addAI(Fk.Ltk.AI.newActiveStrategy {
  think = function(self, ai)
    local player = ai.player
    local cards = ai:getEnabledCards()
    local targets = ai:getEnabledTargets()
    if #cards < 1 or #targets == 0 then return {}, -1000 end

    cards = table.filter(cards, function(id)
      return ai:getCardValue(id, "use_value") < 45 and ai:getCardValue(id, "keep_value") < 45
    end)
    local throw_cards = { cards[1] }

    local benefits = {}
    for _, target in ipairs(targets) do
      local throw_cards_benefit, recover_benefit = 0, 0
      throw_cards_benefit = ai:getBenefitOfEvents(function(logic)
        logic:throwCard(throw_cards, qingnang.name, player, player)
      end)
      recover_benefit = ai:getBenefitOfEvents(function(logic)
        logic:recover {
          who = target,
          num = 1,
          recoverBy = player,
          skillName = qingnang.name,
        }
      end)
      benefits[#benefits + 1] = { target, throw_cards_benefit + recover_benefit }
    end

    table.sort(benefits, function(a, b) return a[2] > b[2] end)
    if #benefits == 0 then return {}, -1000 end

    return { throw_cards, { benefits[1][1] } }, benefits[1][2]
  end,
})

return qingnang
