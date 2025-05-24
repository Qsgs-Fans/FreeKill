local skill = fk.CreateSkill {
  name = "#zhuahuangfeidian_skill",
  tags = { Skill.Compulsory },
  attached_equip = "zhuahuangfeidian",
}

skill:addEffect("distance", {
  correct_func = function(self, from, to)
    if to:hasSkill(skill.name) then
      return 1
    end
  end,
})

return skill
