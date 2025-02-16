if UsingNewCore then
  require "standard.ai.aux_skills"
else
  require "packages.standard.ai.aux_skills"
end

SmartAI:setSkillAI("jianxiong", {
  think_skill_invoke = function(self, ai, skill_name, prompt)
    ---@type DamageData
    local dmg = ai.room.logic:getCurrentEvent().data
    local player = ai.player
    local card = dmg.card
    if not card or player.room:getCardArea(card) ~= Card.Processing then return false end
    local val = ai:getBenefitOfEvents(function(logic)
      logic:obtainCard(player, card, true, fk.ReasonJustMove)
    end)
    if val > 0 then
      return true
    end
    return false
  end,
})

SmartAI:setSkillAI("ganglie", {
  think = function(self, ai)
    local cards = ai:getEnabledCards()
    if #cards < 2 then return "" end

    local to_discard = ai:getChoiceCardsByKeepValue(cards, 2)
    local cancel_val = ai:getBenefitOfEvents(function(logic)
      logic:damage{
        from = ai.room.logic:getCurrentEvent().data[2],
        to = ai.player,
        damage = 1,
        skillName = self.skill.name,
      }
    end)
    local discard_val = ai:getBenefitOfEvents(function(logic)
      logic:throwCard(to_discard, self.skill.name, ai.player, ai.player)
    end)

    if discard_val > cancel_val then
      return { cards = to_discard }
    else
      return ""
    end
  end,

  think_skill_invoke = function(self, ai, skill_name, prompt)
    ---@type DamageData
    local dmg = ai.room.logic:getCurrentEvent().data
    local from = dmg.from
    if not from then return false end
    local dmg_val = ai:getBenefitOfEvents(function(logic)
      logic:damage{
        from = ai.player,
        to = from,
        damage = 1,
        skillName = self.skill.name,
      }
    end)
    local discard_val = ai:getBenefitOfEvents(function(logic)
      local cards = from:getCardIds("h")
      if #cards < 2 then
        logic.benefit = -1
        return
      end
      logic:throwCard(table.random(cards, 2), self.skill.name, from, from)
    end)
    if dmg_val > 0 or discard_val > 0 then
      return true
    end
    return false
  end,
})

SmartAI:setSkillAI("fankui", {
  think_skill_invoke = function(self, ai, skill_name, prompt)
    ---@type DamageData
    local dmg = ai.room.logic:getCurrentEvent().data
    local player = ai.player
    local from = dmg.from
    if not from then return false end
    local val = ai:getBenefitOfEvents(function(logic)
      local flag = from == player and "e" or "he"
      local cards = from:getCardIds(flag)
      if #cards < 1 then
        logic.benefit = -1
        return
      end
      logic:obtainCard(player, cards[1], false, fk.ReasonPrey)
    end)
    if val > 0 then
      return true
    end
    return false
  end,
})

SmartAI:setSkillAI("guicai", {
  think = function(self, ai)
    ---@type JudgeData
    local judge = ai.room.logic:getCurrentEvent().data
    local target = judge.who
    local isFriend = ai:isFriend(target)

    local function handleCardSelection(ai, cardPattern)
      local cards = ai:getEnabledCards(cardPattern)
      if #cards == 0 then
        return {}, -1000
      elseif #cards == 1 then
        return { cards = cards }, 100
      else
        cards = ai:getChoiceCardsByKeepValue(cards, 1)
        return { cards = cards }, 100
      end
    end

    local function getResponseForReason(ai, reason, jdgCard, isFriend)
      local patterns = {
        indulgence = { matchPattern = ".|.|heart", friendPattern = ".|.|heart", enemyPattern = ".|.|^heart" },
        supply_shortage = { matchPattern = ".|.|club", friendPattern = ".|.|club", enemyPattern = ".|.|^club" },
        lightning = { matchPattern = ".|2~9|spade", friendPattern = "^(.|2~9|spade)", enemyPattern = ".|2~9|spade" },
        leiji = {matchPattern = ".|.|spade", friendPattern = ".|.|^spade", enemyPattern = ".|.|spade" },
      }

      local patternInfo = patterns[reason]
      if not patternInfo then return {}, -1000 end

      local matchFunction = isFriend and patternInfo.friendPattern or patternInfo.enemyPattern
      local matchResult = Exppattern:Parse(matchFunction):match(jdgCard)

      if (isFriend and not matchResult) or (not isFriend and matchResult) then
        --- 如果目标是友方且不匹配友方结果，或者目标是敌方且匹配敌方结果（需要改判）
        return handleCardSelection(ai, matchFunction)
      else
        --- 其他情况（目标是友方且匹配友方结果，或者目标是敌方且不匹配敌方结果）
        return {}, -1000
      end
    end

    local jdgCard = judge.card
    local response, value = getResponseForReason(ai, judge.reason, jdgCard, isFriend)

    return response, value
  end,
})

SmartAI:setSkillAI("tuxi", {
  think = function(self, ai)
    local player = ai.player
    -- 选出界面上所有可选的目标
    local players = ai:getEnabledTargets()
    -- 对所有目标计算他们被拿走一张手牌后对自己的收益
    local benefits = table.map(players, function(p)
      return { p, ai:getBenefitOfEvents(function(logic)
        local c = p:getCardIds("h")[1]
        logic:obtainCard(player.id, c, false, fk.ReasonPrey)
      end)}
    end)
    -- 选择收益最高且大于0的两位 判断偷两位的收益加上放弃摸牌的负收益是否可以补偿
    local total_benefit = -ai:getBenefitOfEvents(function(logic)
      logic:drawCards(player, 2, self.skill.name)
    end)
    local targets = {}
    table.sort(benefits, function(a, b) return a[2] > b[2] end)
    for i, benefit in ipairs(benefits) do
      local p, val = table.unpack(benefit)
      if val < 0 then break end
      table.insert(targets, p)
      total_benefit = total_benefit + val
      if i == 2 then break end
    end
    if #targets == 0 or total_benefit <= 0 then return "" end
    return { targets = targets }, total_benefit
  end,
})

SmartAI:setTriggerSkillAI("#kongchengAudio", {
  correct_func = function(self, logic, event, target, player, data)
    if self.skill:canRefresh(event, target, player, data) then
      logic.benefit = logic.benefit + 350
    end
  end,
})

SmartAI:setSkillAI("jizhi", {
  think_skill_invoke = function(self, ai, skill_name, prompt)
    return ai:getBenefitOfEvents(function(logic)
      logic:drawCards(ai.player, 1, self.skill.name)
    end) > 0
  end,
})

SmartAI:setSkillAI("zhiheng", {
  think = function(self, ai)
    local player = ai.player
    local cards = ai:getEnabledCards(".|.|.|hand|.|.|.")

    cards = ai:getChoiceCardsByKeepValue(cards, #cards, function(value) return value < 45 end)

    return { cards = cards }, ai:getBenefitOfEvents(function(logic)
      logic:throwCard(cards, self.skill.name, player, player)
      logic:drawCards(player, #cards, self.skill.name)
    end)
  end,
})

SmartAI:setTriggerSkillAI("jiuyuan", {
  correct_func = function(self, logic, event, target, player, data)
    if self.skill:triggerable(event, target, player, data) then
      data.num = data.num + 1
    end
  end,
})

SmartAI:setSkillAI("keji", {
  think_skill_invoke = Util.TrueFunc,
})

SmartAI:setSkillAI("lianying", nil, "jizhi")
SmartAI:setTriggerSkillAI("lianying", {
  correct_func = function(self, logic, event, target, player, data)
    if self.skill:triggerable(event, target, player, data) then
      logic:drawCards(logic.player, 1, self.skill.name)
    end
  end,
})

SmartAI:setSkillAI("yingzi", {
  think_skill_invoke = Util.TrueFunc,
})

SmartAI:setSkillAI("fanjian", {
  think = function(self, ai)
    local cards = ai:getEnabledCards()
    local players = ai:getEnabledTargets()
    if #cards == 0 then return {}, -1000 end

    --- 获取手牌中权重偏大的牌
    local good_cards = ai:getChoiceCardsByKeepValue(cards, #cards, function(value) return value >= 45 end)
    if (#good_cards / #cards) <= 0.8 then return {}, -1000 end

    local benefits = {}

    --- 遍历所有玩家，计算收益
    for _, target in ipairs(players) do
      --- 计算获得手牌的收益
      local card_benefit = ai:getBenefitOfEvents(function(logic)
        local c = ai.player:getCardIds("h")[1] --- 假设总是取第一张手牌，这里可能需要更复杂的逻辑
        logic:obtainCard(target, c, true, fk.ReasonGive)
      end)

      --- 计算造成伤害的收益
      local damage_benefit = ai:getBenefitOfEvents(function(logic)
        logic:damage{
          from = ai.player,
          to = target,
          damage = 1,
          skillName = self.skill.name,
        }
      end)

      benefits[#benefits + 1] = { target, card_benefit + damage_benefit }
    end

    table.sort(benefits, function(a, b) return a[2] < b[2] end)

    if #benefits == 0 then return {}, -1000 end

    return { targets = { benefits[1][1] } }, benefits[1][2]
  end,

  --- 似乎反间不需要这个
  --- think_card_chosen = function (self, ai, target, flag, prompt)

  --- end,
})

SmartAI:setSkillAI("xiaoji", {
  think_skill_invoke = function(self, ai, skill_name, prompt)
    return ai:getBenefitOfEvents(function(logic)
      logic:drawCards(ai.player, 2, self.skill.name)
    end) > 0
  end,
})

SmartAI:setSkillAI("tieqi", {
  think_skill_invoke = function(self, ai, skill_name, prompt)
    ---@type CardUseStruct
    local dmg = ai.room.logic:getCurrentEvent().data
    local targets = dmg.tos
    if not targets then return false end

    --- TODO 能跑，但是返回是0
    --- TODO 需要注意targets的问题 例如：方天多个目标
    -- local use_val = ai:getBenefitOfEvents(function(logic)
    --   logic:useCard{
    --     from = ai.player.id,
    --     to = targets[1],
    --     card = dmg.card
    --   }
    -- end)

    -- if use_val >= 0 then
    --   return true
    -- end

    -- return false

    return ai:isEnemy(targets[1])
  end,
})

SmartAI:setSkillAI("qingnang", {
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

SmartAI:setSkillAI("biyue", nil, "jizhi")

SmartAI:setSkillAI("wusheng", nil, "spear_skill")

SmartAI:setSkillAI("longdan", nil, "spear_skill")

SmartAI:setSkillAI("qixi", nil, "spear_skill")

SmartAI:setSkillAI("guose", nil, "spear_skill")

SmartAI:setSkillAI("jijiu", nil, "spear_skill")
