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
    if #cards < self.min_c_num then return end
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

return exChooseSkill
