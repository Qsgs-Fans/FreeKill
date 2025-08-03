local spin_skill = fk.CreateSkill({
  name = "spin_skill",
})

spin_skill:addEffect("active", {
  card_num = 0,
  target_num = 0,
  interaction = function(self, player)
    return UI.Spin { from = self.min, to = self.max }
  end,
})

return spin_skill
