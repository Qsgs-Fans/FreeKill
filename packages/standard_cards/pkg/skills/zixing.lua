local skill = fk.CreateSkill {
  name = "#zixing_skill",
  attached_equip = "zixing",
  frequency = Skill.Compulsory,
}

skill:addEffect("distance", {
  correct_func = function(self, from, to)
    if from:hasSkill(skill.name) then
      return -1
    end
  end,
})

return skill
