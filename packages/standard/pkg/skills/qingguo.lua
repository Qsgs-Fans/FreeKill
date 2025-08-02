local qingguo = fk.CreateSkill {
  name = "qingguo",
}

qingguo:addEffect("viewas", {
  anim_type = "defensive",
  pattern = "jink|.|spade,club",
  prompt = "#qingguo",
  handly_pile = true,
  card_filter = function(self, player, to_select, selected)
    return #selected == 0 and Fk:getCardById(to_select).color == Card.Black and
      table.contains(player:getHandlyIds(), to_select)
  end,
  view_as = function(self, player, cards)
    if #cards ~= 1 then return end
    local c = Fk:cloneCard("jink")
    c.skillName = qingguo.name
    c:addSubcard(cards[1])
    return c
  end,
})

qingguo:addAI(nil, "vs_skill")

return qingguo
