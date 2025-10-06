local guose = fk.CreateSkill {
  name = "guose",
}

guose:addEffect("viewas", {
  anim_type = "control",
  pattern = "indulgence",
  prompt = "#guose",
  handly_pile = true,
  filter_pattern = {
    min_num = 1,
    max_num = 1,
    pattern = ".|.|diamond",
  },
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

guose:addAI(nil, "vs_skill")

return guose
