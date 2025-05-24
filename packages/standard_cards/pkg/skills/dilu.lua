local skill = fk.CreateSkill {
  name = "#dilu_skill",
  tags = { Skill.Compulsory },
  attached_equip = "dilu",
}

skill:addEffect("distance", {
  correct_func = function(self, from, to)
    if to:hasSkill(skill.name) then
      return 1
    end
  end,
})

return skill
