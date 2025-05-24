local skill = fk.CreateSkill {
  name = "#zixing_skill",
  tags = { Skill.Compulsory },
  attached_equip = "zixing",
}

skill:addEffect("distance", {
  correct_func = function(self, from, to)
    if from:hasSkill(skill.name) then
      return -1
    end
  end,
})

return skill
