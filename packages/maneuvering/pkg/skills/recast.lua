local skill = fk.CreateSkill {
  name = "recast",
}

skill:addEffect("active", {
  prompt = "#recast",
  target_num = 0,
  on_use = function(self, room, effect)
    room:recastCard(effect.cards, effect.from)
  end,
})

return skill
