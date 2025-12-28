local choosePlayersSkill = fk.CreateSkill{
  name = "choose_players_skill",
}

choosePlayersSkill:addEffect('active', {
  card_filter = function(self, player, to_select, selected)
    return self.pattern ~= "" and Exppattern:Parse(self.pattern):match(Fk:getCardById(to_select)) and #selected == 0
  end,
  target_filter = function(self, player, to_select, selected, cards)
    if self.pattern ~= "" and #cards == 0 then return end
    if #selected < self.num then
      return table.contains(self.targets, to_select.id)
    end
  end,
  target_tip = function(self, player, to_select, selected, selected_cards, card, selectable, extra_data)
    if self.targetTipName then
      local targetTip = Fk.target_tips[self.targetTipName]
      assert(targetTip)
      return targetTip.target_tip(self, player, to_select, selected, selected_cards, card, selectable, extra_data)
    end
  end,
  card_num = function(self) return self.pattern ~= "" and 1 or 0 end,
  min_target_num = function(self) return self.min_num end,
  max_target_num = function(self) return self.num end,
})

choosePlayersSkill:addAI(Fk.Ltk.AI.newActiveStrategy {
  think = function(self, ai)
    local data = ai.data[4]
    local orig = Fk.skills[data.skillName] or choosePlayersSkill
    local strategy = ai:findStrategyOfSkill(Fk.Ltk.AI.ChoosePlayersStrategy, orig.name)
    if not strategy then
      strategy = ai:findStrategyOfSkill(Fk.Ltk.AI.ChoosePlayersStrategy, choosePlayersSkill.name)
      ---@cast strategy -nil
    end

    local cards, card_benefit = strategy:chooseCards(ai)
    local players, player_benefit = strategy:choosePlayers(ai)
    if cards then
      return { cards, players }, ((card_benefit == 0 and 1 or card_benefit) * player_benefit) or 0
    end
  end,
})

choosePlayersSkill:addAI(Fk.Ltk.AI.newChoosePlayersStrategy {
  choose_cards = function (self, ai)
    local data = ai.data[4] -- extra_data
    local available_cards = ai:getEnabledCards()

    if ai.data[3] --[[ cancelable ]] or data.pattern == "" then return {}, 0 end

    return table.random(available_cards, 1), 0
  end,
  choose_players = function(self, ai)
    local data = ai.data[4] -- extra_data
    local available_players = ai:getEnabledTargets()

    if ai.data[3] --[[ cancelable ]] then return {}, 0 end

    return table.random(available_players, data.min_num), 0
  end
})

return choosePlayersSkill
