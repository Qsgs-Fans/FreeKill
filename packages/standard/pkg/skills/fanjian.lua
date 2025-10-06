local fanjian = fk.CreateSkill {
  name = "fanjian",
}

fanjian:addEffect("active", {
  anim_type = "offensive",
  prompt = "#fanjian-active",
  max_phase_use_time = 1,
  card_filter = Util.FalseFunc,
  target_filter = function(self, player, to_select, selected)
    return #selected == 0 and to_select ~= player
  end,
  target_num = 1,
  on_use = function(self, room, effect)
    local player = effect.from
    local target = effect.tos[1]
    local choice = room:askToChoice(target, {
      choices = { "log_spade", "log_heart", "log_club", "log_diamond" },
      skill_name = fanjian.name,
    })
    local card = room:askToChooseCard(target, {
      target = player,
      flag = "h",
      skill_name = fanjian.name,
    })
    room:obtainCard(target, card, true, fk.ReasonPrey, target, fanjian.name)
    if Fk:getCardById(card):getSuitString(true) ~= choice and target:isAlive() then
      room:damage {
        from = player,
        to = target,
        damage = 1,
        skillName = fanjian.name,
      }
    end
  end,
})

fanjian:addAI({
  think = function(self, ai)
    local cards = ai.player:getCardIds("h")
    local players = ai:getEnabledTargets()
    if #cards == 0 then return {}, -1000 end

    --- 获取手牌中权重偏大的牌
    local good_cards = ai:getChoiceCardsByKeepValue(cards, #cards, function(value) return value >= 45 end)
    if (#good_cards / #cards) >= 0.8 then return {}, -1000 end

    local benefits = {}

    --- 遍历所有玩家，计算收益
    for _, target in ipairs(players) do
      --- 计算获得手牌的收益
      local card_benefit, all_benefits=-1,0
      local benefits_all = table.map(cards, function(cid)
        local card_benefit_local = ai:getBenefitOfEvents(function(logic)
          logic:obtainCard(target, cid, true, fk.ReasonGive)
        end)
        all_benefits = all_benefits + card_benefit_local
        return card_benefit_local
      end)
      card_benefit = all_benefits / #benefits_all
      --- 计算造成伤害的收益
      local damage_benefit = ai:getBenefitOfEvents(function(logic)
        logic:damage {
          from = ai.player,
          to = target,
          damage = 1,
          skillName = self.skill.name,
        }
      end)

      benefits[#benefits + 1] = { target, card_benefit + damage_benefit }
    end

    table.sort(benefits, function(a, b) return a[2] > b[2] end)

    if #benefits == 0 then return {}, -1000 end

    return { targets = { benefits[1][1] } }, benefits[1][2]
  end,
})

return fanjian
