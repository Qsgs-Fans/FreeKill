local guose = fk.CreateSkill {
  name = "guose",
}

guose:addEffect("viewas", {
  anim_type = "control",
  pattern = "indulgence",
  prompt = "#guose",
  handly_pile = true,
  card_filter = function(self, player, to_select, selected)
    return #selected == 0 and Fk:getCardById(to_select).suit == Card.Diamond
  end,
  view_as = function(self, player, cards)
    if #cards ~= 1 then return end
    local c = Fk:cloneCard("indulgence")
    c.skillName = guose.name
    c:addSubcard(cards[1])
    return c
  end,
  enabled_at_response = function (self, player, response)
    return not response
  end,
})

return guose
