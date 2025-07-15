local useRealCardSkill = fk.CreateSkill{
  name = "userealcard_skill",
}

useRealCardSkill:addEffect("viewas", {
  card_filter = function (self, player, to_select, selected)
    return #selected == 0 and table.contains(self.cardIds or {}, to_select)
  end,
  view_as = function(self, player, cards)
    if #cards == 1 then
      return Fk:getCardById(cards[1])
    end
    return nil
  end,
})

useRealCardSkill:addAI(nil, "vs_skill")

return useRealCardSkill
