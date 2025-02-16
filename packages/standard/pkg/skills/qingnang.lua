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

return qingnang
