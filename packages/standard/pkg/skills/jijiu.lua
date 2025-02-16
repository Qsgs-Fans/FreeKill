local jijiu = fk.CreateSkill {
  name = "jijiu",
}

jijiu:addEffect("viewas", {
  anim_type = "support",
  pattern = "peach",
  prompt = "#jijiu",
  handly_pile = true,
  card_filter = function(self, player, to_select, selected)
    return #selected == 0 and Fk:getCardById(to_select).color == Card.Red
  end,
  view_as = function(self, player, cards)
    if #cards ~= 1 then return end
    local c = Fk:cloneCard("peach")
    c.skillName = skill.name
    c:addSubcard(jijiu[1])
    return c
  end,
  enabled_at_play = Util.FalseFunc,
  enabled_at_response = function(self, player, response)
    return not response and Fk:currentRoom().current ~= player
  end,
})

return jijiu
