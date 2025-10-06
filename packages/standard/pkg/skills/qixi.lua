local qixi = fk.CreateSkill {
  name = "qixi",
}

qixi:addEffect("viewas", {
  anim_type = "control",
  pattern = "dismantlement",
  prompt = "#qixi",
  -- mute_card = true,
  handly_pile = true,
  filter_pattern = {
    min_num = 1,
    max_num = 1,
    pattern = ".|.|black",
  },
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
