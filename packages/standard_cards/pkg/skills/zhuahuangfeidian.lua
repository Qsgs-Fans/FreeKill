local skill = fk.CreateSkill {
  name = "#zhuahuangfeidian_skill",
  attached_equip = "zhuahuangfeidian",
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
