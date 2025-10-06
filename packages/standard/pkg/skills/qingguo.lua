local qingguo = fk.CreateSkill {
  name = "qingguo",
}

qingguo:addEffect("viewas", {
  anim_type = "defensive",
  pattern = "jink",
  prompt = "#qingguo",
  handly_pile = true,
  filter_pattern = {
    min_num = 1,
    max_num = 1,
    pattern = ".|.|black|^equip",
  },
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
