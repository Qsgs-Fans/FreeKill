local skill = fk.CreateSkill {
  name = "#dayuan_skill",
  tags = { Skill.Compulsory },
  attached_equip = "dayuan",
}

skill:addEffect("distance", {
  correct_func = function(self, from, to)
    if from:hasSkill(skill.name) then
      return -1
    end
  end,
})

return skill
