local virtual_viewas = fk.CreateSkill{
  name = "virtual_viewas",
}

virtual_viewas:addEffect("viewas", {
  expand_pile = function (self, player)
    if #self.subcards > 0 then
      return {}
    elseif self.card_filter.n[1] > 0 then
      return table.filter(self.card_filter.cards, function (id)
        return not table.contains(player:getCardIds("he"), id)
      end)
    end
    return {}
  end,
  card_filter = function (self, player, to_select, selected)
    if #self.subcards > 0 then
      return false
    else
      return #selected < self.card_filter.n[2] and table.contains(self.card_filter.cards, to_select) and
        Fk:getCardById(to_select):matchPattern(self.card_filter.pattern)
    end
  end,
  interaction = function(self)
    if #self.all_choices == 1 and not self.namebox then return end
    return UI.CardNameBox { choices = self.choices, all_choices = self.all_choices }
  end,
  view_as = function(self, player, cards)
    local name = (#self.all_choices == 1 and self.all_choices[1]) or self.interaction.data
    if Fk.all_card_types[name] == nil then return nil end
    local card = Fk:cloneCard(name)
    if self.skillName then
      card.skillName = self.skillName
    end
    if #self.subcards > 0 then
      card:addSubcards(self.subcards)
    else
      if #cards < self.card_filter.n[1] or #cards > self.card_filter.n[2] then return end
      if #cards > 0 then
        if self.card_filter.fake_subcards then
          card:addFakeSubcards(cards)
        else
          card:addSubcards(cards)
        end
      end
    end
    if player:prohibitUse(card) then return nil end -- FIXME: 修复合法性判断后删除此段

    return card
  end,
})

virtual_viewas:addAI(nil, "vs_skill")

return virtual_viewas
