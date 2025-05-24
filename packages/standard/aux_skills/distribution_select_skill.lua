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


return distributionSelectSkill
