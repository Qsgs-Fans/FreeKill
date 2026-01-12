local exChooseSkill = fk.CreateSkill{
  name = "ex__choose_skill",
}

exChooseSkill:addEffect('active', {
  card_filter = function(self, player, to_select, selected)
    if #selected >= self.max_c_num then return false end

    if not table.contains(player:getCardIds("he"), to_select) then
      local pile = self:getPile(player)
      if not table.contains(pile, to_select) then return false end
    end

    local checkpoint = true
    local card = Fk:getCardById(to_select)

    if self.will_throw and player:prohibitDiscard(card) then
      return false
    end


    if self.pattern and self.pattern ~= "" then
      checkpoint = checkpoint and (Exppattern:Parse(self.pattern):match(card))
    end
    return checkpoint
  end,
  target_filter = function(self, player, to_select, selected, cards)
    -- 这有啥好判的
    -- if #cards < self.min_c_num then return end
    if #selected < self.max_t_num then
      return table.contains(self.targets, to_select.id)
    end
  end,
  feasible = function (self, player, selected, selected_cards, card)
    if #selected_cards >= self.min_c_num and #selected_cards <= self.max_c_num and
      #selected >= self.min_t_num and #selected <= self.max_t_num then
      if self.equal then
        return #selected_cards == #selected
      else
        return true
      end
    end
  end,
  target_tip = function(self, player, to_select, selected, selected_cards, card, selectable, extra_data)
    if self.targetTipName then
      local targetTip = Fk.target_tips[self.targetTipName]
      assert(targetTip)
      return targetTip.target_tip(self, player, to_select, selected, selected_cards, card, selectable, extra_data)
    end
  end,
  min_target_num = function(self) return self.min_t_num end,
  max_target_num = function(self) return self.max_t_num end,
  min_card_num = function(self) return self.min_c_num end,
  max_card_num = function(self) return self.max_c_num end,
})

exChooseSkill:addAI(Fk.Ltk.AI.newActiveStrategy {
  think = function(self, ai)
    local data = ai.data[4]
    local orig = Fk.skills[data.skillName] or exChooseSkill
    local strategy = ai:findStrategyOfSkill(Fk.Ltk.AI.ChooseCardsAndPlayersStrategy, orig.name)
    if not strategy then
      strategy = ai:findStrategyOfSkill(Fk.Ltk.AI.ChooseCardsAndPlayersStrategy, exChooseSkill.name)
      ---@cast strategy -nil
    end

    local cards, card_benefit = strategy:chooseCards(ai)
    local players, player_benefit = strategy:choosePlayers(ai)
    if cards then
      return { cards, players }, (card_benefit * player_benefit) or 0
    end
  end,
})

exChooseSkill:addAI(Fk.Ltk.AI.newChooseCardsAndPlayersStrategy {
  choose_cards = function (self, ai)
    local data = ai.data[4] -- extra_data
    local available_cards = ai:getEnabledCards()

    if ai.data[3] --[[ cancelable ]] or data.min_c_num == 0 then return {}, 0 end

    return table.random(available_cards, data.min_c_num), 0
  end,
  choose_players = function(self, ai)
    local data = ai.data[4] -- extra_data
    local available_players = ai:getEnabledTargets()

    if ai.data[3] --[[ cancelable ]] or data.min_t_num == 0 then return {}, 0 end

    return table.random(available_players, data.min_t_num), 0
  end
})

return exChooseSkill
