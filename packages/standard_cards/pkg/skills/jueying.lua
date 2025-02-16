local skill = fk.CreateSkill {
  name = "#jueying_skill",
  attached_equip = "jueying",
  frequency = Skill.Compulsory,
}

skill:addEffect("distance", {
  correct_func = function(self, from, to)
    if to:hasSkill(skill.name) then
      return 1
    end
  end,
})

return skill
