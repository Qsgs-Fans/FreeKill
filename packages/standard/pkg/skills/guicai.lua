local guicai = fk.CreateSkill {
  name = "guicai",
}

guicai:addEffect(fk.AskForRetrial, {
  guicai = "control",
  can_trigger = function(self, event, target, player, data)
    return player:hasSkill(guicai.name) and #player:getHandlyIds() > 0
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    local ids = table.filter(player:getHandlyIds(), function (id)
      return not player:prohibitResponse(Fk:getCardById(id))
    end)
    local cards = room:askToCards(player, {
      min_num = 1,
      max_num = 1,
      skill_name = guicai.name,
      pattern = tostring(Exppattern{ id = ids}),
      prompt = "#guicai-ask::"..target.id,
      cancelable = true,
    })
    if #cards > 0 then
      event:setCostData(self, {cards = cards})
      return true
    end
  end,
  on_use = function(self, event, target, player, data)
    player.room:changeJudge{
      card = Fk:getCardById(event:getCostData(self).cards[1]),
      player = player,
      data = data,
      skillName = guicai.name,
      response = true,
    }
  end,
})

guicai:addAI({
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

return guicai
