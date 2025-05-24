local skill = fk.CreateSkill {
  name = "#jueying_skill",
  tags = { Skill.Compulsory },
  attached_equip = "jueying",
}

skill:addEffect("distance", {
  correct_func = function(self, from, to)
    if to:hasSkill(skill.name) then
      return 1
    end
  end,
})

return skill
