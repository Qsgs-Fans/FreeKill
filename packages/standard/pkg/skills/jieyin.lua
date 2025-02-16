local jieyin = fk.CreateSkill {
  name = "jieyin",
}

jieyin:addEffect("active", {
  anim_type = "support",
  prompt = "#jieyin-active",
  max_phase_use_time = 1,
  card_filter = function(self, player, to_select, selected)
    return #selected < 2 and table.contains(player:getCardIds("h"), to_select) and not player:prohibitDiscard(to_select)
  end,
  target_filter = function(self, player, to_select, selected)
    return #selected == 0 and to_select:isWounded() and to_select:isMale() and to_select ~= player
  end,
  target_num = 1,
  card_num = 2,
  on_use = function(self, room, effect)
    local from = room:getPlayerById(effect.from)
    local target = room:getPlayerById(effect.tos[1])
    room:throwCard(effect.cards, jieyin.name, from, from)
    if target:isAlive() and target:isWounded() then
      room:recover({
        who = target,
        num = 1,
        recoverBy = from,
        skillName = jieyin.name,
      })
    end
    if from:isAlive() and from:isWounded() then
      room:recover({
        who = from,
        num = 1,
        recoverBy = from,
        skillName = jieyin.name,
      })
    end
  end,
})

return jieyin
