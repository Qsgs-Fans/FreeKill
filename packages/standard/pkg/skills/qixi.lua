local qixi = fk.CreateSkill {
  name = "qixi",
}

qixi:addEffect("viewas", {
  anim_type = "control",
  pattern = "dismantlement|.|spade,club",
  prompt = "#qixi",
  -- mute_card = true,
  handly_pile = true,
  card_filter = function(self, player, to_select, selected)
    return #selected == 0 and Fk:getCardById(to_select).color == Card.Black
  end,
  view_as = function(self, player, cards)
    if #cards ~= 1 then return end
    local c = Fk:cloneCard("dismantlement")
    c.skillName = qixi.name
    c:addSubcard(cards[1])
    return c
  end,
  enabled_at_response = function (self, player, response)
    return not response
  end
})

qixi:addAI(nil, "vs_skill")

return qixi
