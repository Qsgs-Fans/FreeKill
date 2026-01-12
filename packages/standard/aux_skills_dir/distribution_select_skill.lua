local distributionSelectSkill = fk.CreateSkill{
  name = "distribution_select_skill",
}

distributionSelectSkill:addEffect("active", {
  mute = true,
  min_card_num = 1,
  card_filter = function(self, player, to_select, selected)
    local maxNum = 0
    for _, v in pairs(self.residued_list) do
      maxNum = math.max(maxNum, v)
    end
    return #selected < self.max_num and #selected < maxNum and table.contains(self.cards, to_select)
  end,
  target_num = 1,
  target_filter = function(self, player, to_select, selected, selected_cards)
    return #selected == 0 and #selected_cards > 0 and table.contains(self.targets, to_select.id)
    and #selected_cards <= (self.residued_list[string.format("%d", to_select.id)] or 0)
  end,
})

distributionSelectSkill:addAI(Fk.Ltk.AI.newActiveStrategy {
  think = function(self, ai)
    local data = ai.data[4]
    local orig = Fk.skills[data.skillName] or distributionSelectSkill
    local strategy = ai:findStrategyOfSkill(Fk.Ltk.AI.YijiStrategy, orig.name)
    if not strategy then
      strategy = ai:findStrategyOfSkill(Fk.Ltk.AI.YijiStrategy, distributionSelectSkill.name)
      ---@cast strategy -nil
    end

    local cards, card_benefit = strategy:chooseCards(ai)
    for _, cid in ipairs(cards or {}) do
      ai:selectCard(cid, true)
    end
    local players, player_benefit = strategy:choosePlayers(ai)
    if cards then
      return { cards, players }, (card_benefit * player_benefit) or 0
    end
  end,
})

distributionSelectSkill:addAI(Fk.Ltk.AI.newYijiStrategy {
  choose_cards = function (self, ai)
    local data = ai.data[4] -- extra_data
    local available_cards = ai:getEnabledCards()

    if ai.data[3] --[[ cancelable ]] or data.pattern == "" then return {}, 0 end

    return table.random(available_cards, data.max_num), 0
  end,
  choose_players = function(self, ai)
    local data = ai.data[4] -- extra_data
    local available_players = ai:getEnabledTargets()

    if ai.data[3] --[[ cancelable ]] then return {}, 0 end

    return table.random(available_players, 1), 0
  end
})


return distributionSelectSkill
