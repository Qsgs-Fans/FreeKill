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
    local from = effect.from
    local target = effect.tos[1]
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


jieyin:addAI({
  think = function(self, ai)
    local cards = ai:getEnabledCards(".|.|.|hand|.|.|.")
    local players = table.filter(ai.room.alive_players,function (p)
      return p:isWounded() and p~=ai.player
    end)
    if #cards <= 1 then return {}, -1000 end

    --- 获取手牌中权重偏小的牌
    local get_cards = ai:getChoiceCardsByKeepValue(cards, 2, function(value) return value <= 45 end)
    local throw_cards = { get_cards[1], get_cards[2] }
    local benefits = {}

    --- 遍历所有玩家，计算收益
    for _, target in ipairs(players) do
      local throw_cards_benefit, recover_benefit = 0, 0
      --- 计算弃置手牌的收益
      throw_cards_benefit = ai:getBenefitOfEvents(function(logic)
        logic:throwCard(throw_cards, jieyin.name, ai.player, ai.player)
      end)
      --- 计算回复血量的收益
      recover_benefit = ai:getBenefitOfEvents(function(logic)
        logic:recover {
          who = target,
          num = 1,
          recoverBy = ai.player,
          skillName = jieyin.name,
        }
        if ai.player:isWounded() then
          logic:recover {
            who = ai.player,
            num = 1,
            recoverBy = ai.player,
            skillName = jieyin.name,
          }
        end
      end)
      benefits[#benefits + 1] = { target, throw_cards_benefit + recover_benefit }
    end

    table.sort(benefits, function(a, b) return a[2] > b[2] end)
    if #benefits == 0 then return {}, -1000 end

    return { targets = { benefits[1][1] }, cards = throw_cards }, benefits[1][2]
  end,
})

return jieyin
