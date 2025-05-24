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

qingnang:addAI({
  think = function(self, ai)
    local player = ai.player
    local cards = ai:getEnabledCards(".|.|.|hand|.|.|.")
    local players = ai:getEnabledTargets()

    --- 对所有目标计算回血的收益
    local benefits = table.map(players, function(p)
      return { p, ai:getBenefitOfEvents(function(logic)
        --- @type RecoverData
        logic:recover{
          who = p,
          num = 1,
          recoverBy = player
        }
      end)}
    end)

    table.sort(benefits, function(a, b) return a[2] > b[2] end)

    if #benefits == 0 then return {}, -1000 end

    --- 尽量选择权重占比小的牌
    cards = ai:getChoiceCardsByKeepValue(cards, 1)

    --- 计算弃牌收益
    local throw = ai:getBenefitOfEvents(function(logic)
      logic:throwCard(cards, self.skill.name, player, player)
    end)

    return { targets = { benefits[1][1] }, cards = cards }, benefits[1][2] + throw
  end,
})

return qingnang
